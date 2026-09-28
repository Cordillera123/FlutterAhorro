import 'dart:isolate';

import 'package:intl/intl.dart';

import '../../models/export_config.dart';
import '../../models/export_data.dart';
import '../../models/transaction.dart';
import 'base_exporter.dart';

/// Exportador de reportes en formato CSV (.csv).
///
/// Genera un único archivo de texto plano con separador de coma.
/// La hoja generada depende de [ReportType]:
///   - [ReportType.fullReport] / [ReportType.transactions] → Transacciones
///   - [ReportType.budgets]     → Presupuestos
///   - [ReportType.goals]       → Metas
///
/// La generación corre en un isolate para no bloquear la UI.
class CsvService implements BaseExporter {
  @override
  String get fileExtension => 'csv';

  @override
  String get mimeType => 'text/csv';

  @override
  Future<List<int>> generateBytes(ExportData data) async {
    return await Isolate.run(() => _buildCsv(data));
  }

  // ─── Generación (hilo de isolate) ──────────────────────────────────────

  static List<int> _buildCsv(ExportData data) {
    final buf = StringBuffer();

    _writeMetadata(buf, data);

    switch (data.config.reportType) {
      case ReportType.budgets:
        _writeBudgets(buf, data);
        break;
      case ReportType.goals:
        _writeGoals(buf, data);
        break;
      case ReportType.transactions:
      case ReportType.fullReport:
        _writeTransactions(buf, data);
        break;
    }

    // UTF-8 encoding: convertir cada code unit del string a bytes
    return buf.toString().codeUnits;
  }

  // ─── Metadatos ─────────────────────────────────────────────────────────

  static void _writeMetadata(StringBuffer buf, ExportData data) {
    final genDate = DateFormat('dd/MM/yyyy HH:mm', 'es').format(data.generatedAt);
    buf.writeln(_row(['# Reporte generado por', data.appName]));
    buf.writeln(_row(['# Fecha de generación', genDate]));
    buf.writeln(_row(['# Período', data.config.dateRangeLabel]));
    buf.writeln(_row(['# Filtros', data.config.filterSummary]));
    buf.writeln(); // línea en blanco entre metadatos y datos
  }

  // ─── Transacciones ─────────────────────────────────────────────────────

  static void _writeTransactions(StringBuffer buf, ExportData data) {
    buf.writeln(
      _row(['Fecha', 'Cuenta', 'Tipo', 'Categoría', 'Monto', 'Descripción']),
    );

    final moneyFmt = NumberFormat('#,##0.00', 'es');
    final dateFmt = DateFormat('dd/MM/yyyy', 'es');

    for (final t in data.transactions) {
      String sign;
      String typeLabel;
      switch (t.type) {
        case TransactionType.income:
          sign = '';
          typeLabel = 'Ingreso';
          break;
        case TransactionType.expense:
          sign = '-';
          typeLabel = 'Gasto';
          break;
        case TransactionType.transfer:
          sign = (t.isTransferOut ?? true) ? '-' : '';
          typeLabel = 'Transferencia';
          break;
      }
      buf.writeln(_row([
        dateFmt.format(t.date),
        data.accountNameById(t.accountId),
        typeLabel,
        t.categoryName,
        '$sign${moneyFmt.format(t.amount)}',
        t.description,
      ]));
    }

    // Resumen al final
    final moneyFmtSum = NumberFormat('#,##0.00', 'es');
    buf.writeln();
    buf.writeln(_row(['', '', '', '', '', '']));
    buf.writeln(_row(['Total ingresos', '', '', '', moneyFmtSum.format(data.totalIncome), '']));
    buf.writeln(_row(['Total gastos', '', '', '', moneyFmtSum.format(data.totalExpense), '']));
    buf.writeln(_row(['Balance neto (período)', '', '', '', moneyFmtSum.format(data.netBalance), '']));
    if (data.totalInitialBalance != 0) {
      buf.writeln(_row(['Saldo inicial de cuenta', '', '', '', moneyFmtSum.format(data.totalInitialBalance), '']));
      buf.writeln(_row(['Balance real total', '', '', '', moneyFmtSum.format(data.totalBalance), '']));
    }
  }

  // ─── Presupuestos ──────────────────────────────────────────────────────

  static void _writeBudgets(StringBuffer buf, ExportData data) {
    buf.writeln(
      _row(['Nombre', 'Categoría', 'Monto', 'Período', 'Estado', 'Inicio', 'Fin']),
    );

    final moneyFmt = NumberFormat('#,##0.00', 'es');
    final dateFmt = DateFormat('dd/MM/yyyy', 'es');

    for (final b in data.budgets) {
      buf.writeln(_row([
        b.name,
        '${b.categoryIcon} ${b.categoryName}',
        moneyFmt.format(b.amount),
        b.periodName,
        b.statusText,
        dateFmt.format(b.startDate),
        dateFmt.format(b.endDate),
      ]));
    }
  }

  // ─── Metas ─────────────────────────────────────────────────────────────

  static void _writeGoals(StringBuffer buf, ExportData data) {
    buf.writeln(
      _row(['Nombre', 'Meta', 'Ahorrado', 'Progreso (%)', 'Fecha límite', 'Estado']),
    );

    final moneyFmt = NumberFormat('#,##0.00', 'es');
    final dateFmt = DateFormat('dd/MM/yyyy', 'es');

    for (final g in data.goals) {
      final pct = g.targetAmount > 0
          ? (g.currentAmount / g.targetAmount * 100).clamp(0.0, 100.0)
          : 0.0;
      buf.writeln(_row([
        '${g.emoji} ${g.name}',
        moneyFmt.format(g.targetAmount),
        moneyFmt.format(g.currentAmount),
        '${pct.toStringAsFixed(1)}%',
        dateFmt.format(g.targetDate),
        g.statusName,
      ]));
    }

    // Resumen
    final moneyFmtSum = NumberFormat('#,##0.00', 'es');
    buf.writeln();
    buf.writeln(_row(['Total meta', moneyFmtSum.format(data.totalGoalTarget), '', '', '', '']));
    buf.writeln(_row(['Total ahorrado', moneyFmtSum.format(data.totalGoalSaved), '', '', '', '']));
  }

  // ─── CSV helpers ───────────────────────────────────────────────────────

  /// Convierte una lista de campos a una línea CSV correctamente escapada.
  static String _row(List<String> fields) => fields.map(_escape).join(',');

  /// Escapa un campo: lo envuelve en comillas dobles si contiene coma,
  /// comilla o salto de línea. Las comillas internas se duplican.
  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
