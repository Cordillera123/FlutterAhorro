import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/budget.dart';
import '../models/export_config.dart';
import '../models/export_data.dart';
import '../models/financial_goal.dart';
import '../models/transaction.dart';
import 'account_service.dart';
import 'budget_service.dart';
import 'excel_service.dart';
import 'exporters/base_exporter.dart';
import 'exporters/csv_service.dart';
import 'goal_service.dart';
import 'transaction_service.dart';

/// Servicio orquestador de exportación de reportes.
///
/// Responsabilidades:
/// 1. Obtener datos en memoria de los servicios existentes.
/// 2. Aplicar los filtros definidos en [ExportConfig.filters].
/// 3. Construir [ExportData] (DTO limpio, sin referencias a servicios).
/// 4. Delegar la generación de bytes al [BaseExporter] correspondiente.
/// 5. Guardar el archivo en el directorio temporal del dispositivo.
/// 6. Compartir el archivo vía el diálogo nativo del SO.
///
/// Sigue el patrón Singleton del resto de servicios del proyecto.
/// No modifica ningún dato existente: es 100% de solo lectura.
class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final TransactionService _transactionService = TransactionService();
  final BudgetService _budgetService = BudgetService();
  final GoalService _goalService = GoalService();
  final AccountService _accountService = AccountService();

  bool _isExporting = false;

  /// `true` mientras hay una exportación en curso.
  bool get isExporting => _isExporting;

  // ─── Método principal ────────────────────────────────────────────────

  /// Genera el reporte según [config] y abre el diálogo de compartir nativo.
  ///
  /// Devuelve la ruta del archivo temporal generado, o `null` si ya había
  /// una exportación en curso.
  ///
  /// Lanza excepción si el formato no está implementado, si el rango de
  /// fechas no contiene transacciones, o si falla la escritura en disco.
  /// La UI debe capturar el error y mostrarlo al usuario.
  Future<String?> generateAndShare(ExportConfig config) async {
    if (_isExporting) return null;
    _isExporting = true;

    try {
      // 1. Recopilar y filtrar datos
      final exportData = _buildExportData(config);

      // 2. Validar que hay datos para exportar
      if (exportData.transactions.isEmpty &&
          exportData.budgets.isEmpty &&
          exportData.goals.isEmpty) {
        throw ExportEmptyDataException(
          'No se encontraron datos para el período '
          '${config.filters.dateRangeLabel}.',
        );
      }

      // 3. Seleccionar exportador según formato
      final exporter = _resolveExporter(config.format);

      // 4. Generar bytes (delegado al isolate del exportador)
      final bytes = await exporter.generateBytes(exportData);

      // 5. Guardar en directorio temporal
      final filePath = await _saveToTempDir(
        bytes: bytes,
        config: config,
        exporter: exporter,
      );

      // 6. Compartir vía SO
      await _shareFile(filePath: filePath, config: config, exporter: exporter);

      return filePath;
    } catch (e) {
      debugPrint('❌ ExportService.generateAndShare error: $e');
      rethrow;
    } finally {
      _isExporting = false;
    }
  }

  /// Cuenta cuántas transacciones coincidirían con los filtros dados,
  /// sin generar el archivo. Útil para mostrar el aviso de límite de filas
  /// en la UI antes de exportar.
  int estimateTransactionCount(ExportConfig config) {
    return _filterTransactions(
      _transactionService.allTransactions,
      config,
    ).length;
  }

  // ─── Construcción de ExportData ───────────────────────────────────────

  ExportData _buildExportData(ExportConfig config) {
    final allTransactions = _transactionService.allTransactions;
    final allBudgets = _budgetService.allBudgets;
    final allGoals = _goalService.allGoals;
    final accounts = _accountService.accounts.toList();

    return ExportData(
      transactions: _filterTransactions(allTransactions, config),
      budgets: _filterBudgets(allBudgets, config),
      goals: _filterGoals(allGoals, config),
      accounts: accounts,
      config: config,
      generatedAt: DateTime.now(),
    );
  }

  // ─── Lógica de filtrado ───────────────────────────────────────────────

  List<Transaction> _filterTransactions(
    List<Transaction> source,
    ExportConfig config,
  ) {
    final f = config.filters;
    return source.where((t) {
      // Filtro de fechas (comparación a nivel día, sin horas)
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      final from = DateTime(f.dateFrom.year, f.dateFrom.month, f.dateFrom.day);
      final to = DateTime(f.dateTo.year, f.dateTo.month, f.dateTo.day);
      if (day.isBefore(from) || day.isAfter(to)) return false;

      // Filtro de cuentas
      if (f.hasAccountFilter && !f.accountIds.contains(t.accountId)) {
        return false;
      }

      // Filtro de tipo (ingreso / gasto)
      if (f.hasTypeFilter && !f.transactionTypes.contains(t.type)) {
        return false;
      }

      // Filtro de categoría
      if (f.hasCategoryFilter) {
        if (t.type == TransactionType.expense) {
          final matchesCustom = f.customCategoryIds.isNotEmpty &&
              t.customCategoryId != null &&
              f.customCategoryIds.contains(t.customCategoryId);
          final matchesSystem = f.expenseCategories.isNotEmpty &&
              t.expenseCategory != null &&
              f.expenseCategories.contains(t.expenseCategory);
          if (!matchesCustom && !matchesSystem) return false;
        } else {
          final matchesIncome = f.incomeCategories.isNotEmpty &&
              t.incomeCategory != null &&
              f.incomeCategories.contains(t.incomeCategory);
          if (f.incomeCategories.isNotEmpty && !matchesIncome) return false;
        }
      }

      return true;
    }).toList();
  }

  List<Budget> _filterBudgets(
    List<Budget> source,
    ExportConfig config,
  ) {
    final f = config.filters;
    if (!f.hasAccountFilter) return List.of(source);
    return source.where((b) => f.accountIds.contains(b.accountId)).toList();
  }

  List<FinancialGoal> _filterGoals(
    List<FinancialGoal> source,
    ExportConfig config,
  ) {
    final f = config.filters;
    if (!f.hasAccountFilter) return List.of(source);
    return source.where((g) => f.accountIds.contains(g.accountId)).toList();
  }

  // ─── Selección de exportador ──────────────────────────────────────────

  BaseExporter _resolveExporter(ExportFormat format) {
    switch (format) {
      case ExportFormat.excel:
        return ExcelService();
      case ExportFormat.pdf:
        throw UnimplementedError(
          'Exportación a PDF aún no implementada. '
          'Crea PdfService implementando BaseExporter y regístralo aquí.',
        );
      case ExportFormat.csv:
        return CsvService();
    }
  }

  // ─── Guardado y compartición ──────────────────────────────────────────

  Future<String> _saveToTempDir({
    required List<int> bytes,
    required ExportConfig config,
    required BaseExporter exporter,
  }) async {
    final dir = await getTemporaryDirectory();
    final fileName = _buildFileName(
      prefix: 'AhorroApp_Reporte',
      dateFrom: config.filters.dateFrom,
      dateTo: config.filters.dateTo,
      extension: exporter.fileExtension,
    );
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    debugPrint('✅ Reporte guardado en: ${file.path}');
    return file.path;
  }

  static String _buildFileName({
    required String prefix,
    required DateTime dateFrom,
    required DateTime dateTo,
    required String extension,
  }) {
    final from =
        '${dateFrom.year}'
        '${dateFrom.month.toString().padLeft(2, '0')}'
        '${dateFrom.day.toString().padLeft(2, '0')}';
    final to =
        '${dateTo.year}'
        '${dateTo.month.toString().padLeft(2, '0')}'
        '${dateTo.day.toString().padLeft(2, '0')}';
    return '${prefix}_${from}_$to.$extension';
  }

  Future<void> _shareFile({
    required String filePath,
    required ExportConfig config,
    required BaseExporter exporter,
  }) async {
    await Share.shareXFiles(
      [XFile(filePath, mimeType: exporter.mimeType)],
      subject: 'Reporte Financiero — ${config.dateRangeLabel}',
      text:
          'Reporte financiero generado con AhorroApp\n'
          'Período: ${config.dateRangeLabel}\n'
          'Tipo: ${config.reportTypeLabel}',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Excepciones tipadas del módulo de exportación
// ─────────────────────────────────────────────────────────────────────────────

/// Se lanza cuando el conjunto de datos filtrado está vacío
/// (ningún registro coincide con los filtros seleccionados).
class ExportEmptyDataException implements Exception {
  final String message;
  const ExportEmptyDataException(this.message);

  @override
  String toString() => message;
}
