import 'dart:isolate';

import 'package:excel/excel.dart';

import '../models/export_config.dart';
import '../models/export_data.dart';
import '../models/financial_goal.dart';
import '../models/transaction.dart';
import '../utils/excel_formatter.dart';
import 'exporters/base_exporter.dart';

/// Exportador de reportes en formato Excel (.xlsx).
///
/// Implementa [BaseExporter] y genera un libro con hasta 5 hojas:
/// - **Resumen**: métricas clave, filtros aplicados, metadatos.
/// - **Transacciones**: listado completo con totales al pie.
/// - **Por Categoría**: tabla de gastos e ingresos agrupados.
/// - **Presupuestos**: listado de presupuestos configurados.
/// - **Metas**: listado de metas financieras con progreso.
///
/// La generación de bytes se delega a [Isolate.run] para no bloquear la UI.
/// [ExcelService] no accede a servicios ni a SharedPreferences: recibe todos
/// los datos ya preparados a través de [ExportData].
class ExcelService implements BaseExporter {
  @override
  String get fileExtension => 'xlsx';

  @override
  String get mimeType =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Genera los bytes del archivo .xlsx en un isolate secundario.
  @override
  Future<List<int>> generateBytes(ExportData data) {
    return Isolate.run(() => _buildBytesSync(data));
  }

  // ─── Punto de entrada del isolate ────────────────────────────────────

  static List<int> _buildBytesSync(ExportData data) {
    final workbook = Excel.createExcel();
    workbook.delete('Sheet1');

    final reportType = data.config.reportType;

    if (data.config.includeSummarySheet) {
      _buildSummarySheet(workbook, data);
    }

    if (reportType == ReportType.transactions ||
        reportType == ReportType.fullReport) {
      _buildTransactionsSheet(workbook, data);
      _buildByCategorySheet(workbook, data);
      // Hoja extra solo cuando hay datos de varias cuentas
      if (!data.config.filters.hasAccountFilter && data.accounts.length > 1) {
        _buildByAccountSheet(workbook, data);
      }
    }

    if (reportType == ReportType.budgets ||
        reportType == ReportType.fullReport) {
      _buildBudgetsSheet(workbook, data);
    }

    if (reportType == ReportType.goals ||
        reportType == ReportType.fullReport) {
      _buildGoalsSheet(workbook, data);
    }

    return workbook.save()!;
  }

  // ─── Hoja 1: Resumen ──────────────────────────────────────────────────

  static void _buildSummarySheet(Excel workbook, ExportData data) {
    final sheet = workbook['Resumen'];
    sheet.setColumnWidth(0, 30.0);
    sheet.setColumnWidth(1, 22.0);
    sheet.setColumnWidth(2, 22.0);
    sheet.setColumnWidth(3, 18.0);

    int row = 0;

    // Título principal
    _writeCell(
      sheet, row, 0,
      TextCellValue('${data.appName} — Reporte Financiero'),
      ExcelFormatter.titleStyle,
    );
    _mergeRow(sheet, row, 0, 3);
    row++;

    // Período del reporte
    _writeCell(
      sheet, row, 0,
      TextCellValue('Período: ${data.config.dateRangeLabel}'),
      ExcelFormatter.subHeaderStyle,
    );
    _mergeRow(sheet, row, 0, 3);
    row++;

    // Metadatos
    _writeCell(
      sheet, row, 0,
      TextCellValue(
        'Generado el: ${ExcelFormatter.formatDateTime(data.generatedAt)}',
      ),
      ExcelFormatter.metadataStyle,
    );
    _writeCell(
      sheet, row, 2,
      TextCellValue('Tipo: ${data.config.reportTypeLabel}'),
      ExcelFormatter.metadataStyle,
    );
    row++;
    _writeCell(
      sheet, row, 0,
      TextCellValue('Filtros: ${data.config.filterSummary}'),
      ExcelFormatter.metadataStyle,
    );
    row += 2;

    // ── Resumen financiero ──
    _writeSectionHeader(sheet, row, 'RESUMEN FINANCIERO', 4);
    row++;

    _writeLabelValue(
      sheet, row++, 'Total Ingresos',
      ExcelFormatter.formatMoney(data.totalIncome),
      valueIsIncome: true,
    );
    _writeLabelValue(
      sheet, row++, 'Total Gastos',
      ExcelFormatter.formatMoney(data.totalExpense),
      valueIsExpense: true,
    );
    _writeLabelValue(
      sheet, row++, 'Balance Neto (período)',
      ExcelFormatter.formatMoneyWithSign(data.netBalance),
      valueIsIncome: data.netBalance >= 0,
      valueIsExpense: data.netBalance < 0,
    );
    if (data.totalInitialBalance != 0) {
      _writeLabelValue(
        sheet, row++, 'Saldo Inicial de Cuenta',
        ExcelFormatter.formatMoney(data.totalInitialBalance),
        valueIsIncome: data.totalInitialBalance >= 0,
      );
      _writeLabelValue(
        sheet, row++, 'Balance Total Real',
        ExcelFormatter.formatMoneyWithSign(data.totalBalance),
        valueIsIncome: data.totalBalance >= 0,
        valueIsExpense: data.totalBalance < 0,
      );
    }
    _writeLabelValue(
      sheet, row++, 'Total Transacciones',
      '${data.transactionCount}',
    );
    row++;

    // ── Resumen de presupuestos ──
    if (data.budgets.isNotEmpty) {
      _writeSectionHeader(sheet, row, 'PRESUPUESTOS', 4);
      row++;
      _writeLabelValue(sheet, row++, 'Total registrados', '${data.budgetCount}');
      _writeLabelValue(sheet, row++, 'Activos', '${data.activeBudgetCount}');
      _writeLabelValue(
        sheet, row++, 'Monto total presupuestado',
        ExcelFormatter.formatMoney(data.totalBudgeted),
      );
      row++;
    }

    // ── Resumen de metas ──
    if (data.goals.isNotEmpty) {
      _writeSectionHeader(sheet, row, 'METAS FINANCIERAS', 4);
      row++;
      _writeLabelValue(sheet, row++, 'Total metas', '${data.goalCount}');
      _writeLabelValue(
        sheet, row++, 'Objetivo total',
        ExcelFormatter.formatMoney(data.totalGoalTarget),
      );
      _writeLabelValue(
        sheet, row++, 'Total ahorrado',
        ExcelFormatter.formatMoney(data.totalGoalSaved),
        valueIsIncome: true,
      );
      _writeLabelValue(
        sheet, row++, 'Progreso global',
        ExcelFormatter.formatPercent(data.goalsOverallProgress),
      );
      row++;
    }

    // ── Resumen por cuenta (solo cuando hay más de una) ──
    if (!data.config.filters.hasAccountFilter && data.accounts.length > 1) {
      _writeSectionHeader(sheet, row, 'RESUMEN POR CUENTA', 4);
      row++;

      _writeCell(sheet, row, 0, TextCellValue('Cuenta'), ExcelFormatter.labelStyle);
      _writeCell(sheet, row, 1, TextCellValue('Ingresos'), ExcelFormatter.labelStyle);
      _writeCell(sheet, row, 2, TextCellValue('Gastos'), ExcelFormatter.labelStyle);
      _writeCell(sheet, row, 3, TextCellValue('Balance'), ExcelFormatter.labelStyle);
      row++;

      int idx = 0;
      for (final acc in data.accounts) {
        final accTx = data.transactions.where((t) => t.accountId == acc.id);
        final income = accTx
            .where((t) => t.type == TransactionType.income)
            .fold(0.0, (s, t) => s + t.amount);
        final expense = accTx
            .where((t) => t.type == TransactionType.expense)
            .fold(0.0, (s, t) => s + t.amount);
        final balance = income - expense;
        final isAlt = idx % 2 == 1;
        final style = isAlt ? ExcelFormatter.altRowStyle : ExcelFormatter.valueStyle;

        _writeCell(
          sheet, row, 0,
          TextCellValue('${acc.emoji} ${acc.name}'),
          style,
        );
        _writeCell(
          sheet, row, 1,
          TextCellValue(ExcelFormatter.formatMoney(income)),
          ExcelFormatter.amountStyle(isIncome: true, isAltRow: isAlt),
        );
        _writeCell(
          sheet, row, 2,
          TextCellValue(ExcelFormatter.formatMoney(expense)),
          ExcelFormatter.amountStyle(isIncome: false, isAltRow: isAlt),
        );
        _writeCell(
          sheet, row, 3,
          TextCellValue(ExcelFormatter.formatMoneyWithSign(balance)),
          ExcelFormatter.balanceStyle(isPositive: balance >= 0),
        );
        row++;
        idx++;
      }
      row++;
    }

    // ── Top gastos por categoría ──
    if (data.expensesByCategory.isNotEmpty) {
      _writeSectionHeader(sheet, row, 'TOP GASTOS POR CATEGORÍA', 4);
      row++;

      // Mini-encabezados
      _writeCell(sheet, row, 0, TextCellValue('Categoría'), ExcelFormatter.labelStyle);
      _writeCell(sheet, row, 1, TextCellValue('Monto'), ExcelFormatter.labelStyle);
      _writeCell(sheet, row, 2, TextCellValue('% del total'), ExcelFormatter.labelStyle);
      row++;

      int idx = 0;
      for (final entry in data.expensesByCategory.entries.take(8)) {
        final isAlt = idx % 2 == 1;
        final pct = data.totalExpense > 0
            ? entry.value / data.totalExpense
            : 0.0;
        _writeCell(
          sheet, row, 0, TextCellValue(entry.key),
          isAlt ? ExcelFormatter.altRowStyle : ExcelFormatter.valueStyle,
        );
        _writeCell(
          sheet, row, 1,
          TextCellValue(ExcelFormatter.formatMoney(entry.value)),
          ExcelFormatter.amountStyle(isIncome: false, isAltRow: isAlt),
        );
        _writeCell(
          sheet, row, 2,
          TextCellValue(ExcelFormatter.formatPercent(pct)),
          isAlt ? ExcelFormatter.altRowStyle : ExcelFormatter.valueStyle,
        );
        row++;
        idx++;
      }
    }
  }

  // ─── Hoja 2: Transacciones ────────────────────────────────────────────

  static const int _maxRows = 50000;

  static void _buildTransactionsSheet(Excel workbook, ExportData data) {
    final sheet = workbook['Transacciones'];
    sheet.setColumnWidth(0, 6.0);   // #
    sheet.setColumnWidth(1, 13.0);  // Fecha
    sheet.setColumnWidth(2, 10.0);  // Tipo
    sheet.setColumnWidth(3, 34.0);  // Descripción
    sheet.setColumnWidth(4, 22.0);  // Categoría
    sheet.setColumnWidth(5, 20.0);  // Cuenta
    sheet.setColumnWidth(6, 16.0);  // Monto

    int row = 0;

    _writeCell(
      sheet, row, 0,
      TextCellValue('TRANSACCIONES — ${data.config.dateRangeLabel}'),
      ExcelFormatter.titleStyle,
    );
    _mergeRow(sheet, row, 0, 6);
    row++;

    const headers = ['#', 'Fecha', 'Tipo', 'Descripción', 'Categoría', 'Cuenta', 'Monto'];
    for (int i = 0; i < headers.length; i++) {
      _writeCell(sheet, row, i, TextCellValue(headers[i]), ExcelFormatter.headerStyle);
    }
    row++;

    final transactions = data.transactions.take(_maxRows).toList();
    for (int i = 0; i < transactions.length; i++) {
      final t = transactions[i];
      final isAlt = i % 2 == 1;
      final isIncome = t.type == TransactionType.income;
      final isTransfer = t.type == TransactionType.transfer;
      final typeLabel = isTransfer
          ? 'Transferencia'
          : (isIncome ? 'Ingreso' : 'Gasto');
      final baseStyle =
          isAlt ? ExcelFormatter.altRowStyle : ExcelFormatter.valueStyle;

      _writeCell(sheet, row, 0, IntCellValue(i + 1), baseStyle);
      _writeCell(
        sheet, row, 1,
        TextCellValue(ExcelFormatter.formatDate(t.date)), baseStyle,
      );
      _writeCell(
        sheet, row, 2,
        TextCellValue(typeLabel), baseStyle,
      );
      _writeCell(sheet, row, 3, TextCellValue(t.description), baseStyle);
      _writeCell(sheet, row, 4, TextCellValue(t.categoryName), baseStyle);
      _writeCell(
        sheet, row, 5,
        TextCellValue(data.accountNameById(t.accountId)), baseStyle,
      );
      _writeCell(
        sheet, row, 6,
        TextCellValue(ExcelFormatter.formatMoney(t.amount)),
        ExcelFormatter.amountStyle(
          isIncome: isIncome,
          isAltRow: isAlt,
          isTransfer: isTransfer,
        ),
      );
      row++;
    }

    // Fila de totales
    row++;
    _writeCell(
      sheet, row, 5, TextCellValue('Total Ingresos:'),
      ExcelFormatter.labelStyle,
    );
    _writeCell(
      sheet, row, 6,
      TextCellValue(ExcelFormatter.formatMoney(data.totalIncome)),
      ExcelFormatter.incomeAmountStyle,
    );
    row++;
    _writeCell(
      sheet, row, 5, TextCellValue('Total Gastos:'),
      ExcelFormatter.labelStyle,
    );
    _writeCell(
      sheet, row, 6,
      TextCellValue(ExcelFormatter.formatMoney(data.totalExpense)),
      ExcelFormatter.expenseAmountStyle,
    );
    row++;
    _writeCell(
      sheet, row, 5, TextCellValue('Balance Neto:'),
      ExcelFormatter.labelStyle,
    );
    _writeCell(
      sheet, row, 6,
      TextCellValue(ExcelFormatter.formatMoneyWithSign(data.netBalance)),
      ExcelFormatter.balanceStyle(isPositive: data.netBalance >= 0),
    );
  }

  // ─── Hoja 3: Por Categoría ────────────────────────────────────────────

  static void _buildByCategorySheet(Excel workbook, ExportData data) {
    final sheet = workbook['Por Categoría'];
    // Columnas: Gastos (0-3) | Espaciador (4) | Ingresos (5-8)
    sheet.setColumnWidth(0, 26.0);
    sheet.setColumnWidth(1, 16.0);
    sheet.setColumnWidth(2, 12.0);
    sheet.setColumnWidth(3, 12.0);
    sheet.setColumnWidth(4, 3.0);
    sheet.setColumnWidth(5, 26.0);
    sheet.setColumnWidth(6, 16.0);
    sheet.setColumnWidth(7, 12.0);
    sheet.setColumnWidth(8, 12.0);

    int row = 0;

    _writeCell(
      sheet, row, 0,
      TextCellValue('ANÁLISIS POR CATEGORÍA'),
      ExcelFormatter.titleStyle,
    );
    _mergeRow(sheet, row, 0, 8);
    row += 2;

    // Sub-encabezados de bloque
    _writeCell(
      sheet, row, 0,
      TextCellValue('GASTOS POR CATEGORÍA'),
      ExcelFormatter.subHeaderStyle,
    );
    _mergeRow(sheet, row, 0, 3);
    _writeCell(
      sheet, row, 5,
      TextCellValue('INGRESOS POR CATEGORÍA'),
      ExcelFormatter.subHeaderStyle,
    );
    _mergeRow(sheet, row, 5, 8);
    row++;

    // Encabezados de columna
    for (final startCol in [0, 5]) {
      _writeCell(sheet, row, startCol,     TextCellValue('Categoría'),    ExcelFormatter.headerStyle);
      _writeCell(sheet, row, startCol + 1, TextCellValue('Monto'),        ExcelFormatter.headerStyle);
      _writeCell(sheet, row, startCol + 2, TextCellValue('Movimientos'),  ExcelFormatter.headerStyle);
      _writeCell(sheet, row, startCol + 3, TextCellValue('% del total'),  ExcelFormatter.headerStyle);
    }
    row++;

    final expList = data.expensesByCategory.entries.toList();
    final incList = data.incomeByCategory.entries.toList();
    final maxLen = expList.length > incList.length ? expList.length : incList.length;
    final countMap = data.transactionCountByCategory;

    for (int i = 0; i < maxLen; i++) {
      final isAlt = i % 2 == 1;
      final baseStyle =
          isAlt ? ExcelFormatter.altRowStyle : ExcelFormatter.valueStyle;

      // Lado de gastos
      if (i < expList.length) {
        final entry = expList[i];
        final count = countMap[entry.key] ?? 0;
        final pct = data.totalExpense > 0 ? entry.value / data.totalExpense : 0.0;
        _writeCell(sheet, row, 0, TextCellValue(entry.key), baseStyle);
        _writeCell(
          sheet, row, 1,
          TextCellValue(ExcelFormatter.formatMoney(entry.value)),
          ExcelFormatter.amountStyle(isIncome: false, isAltRow: isAlt),
        );
        _writeCell(sheet, row, 2, IntCellValue(count), baseStyle);
        _writeCell(
          sheet, row, 3,
          TextCellValue(ExcelFormatter.formatPercent(pct)),
          ExcelFormatter.percentageStyle(pct),
        );
      }

      // Lado de ingresos
      if (i < incList.length) {
        final entry = incList[i];
        final count = countMap[entry.key] ?? 0;
        final pct = data.totalIncome > 0 ? entry.value / data.totalIncome : 0.0;
        _writeCell(sheet, row, 5, TextCellValue(entry.key), baseStyle);
        _writeCell(
          sheet, row, 6,
          TextCellValue(ExcelFormatter.formatMoney(entry.value)),
          ExcelFormatter.amountStyle(isIncome: true, isAltRow: isAlt),
        );
        _writeCell(sheet, row, 7, IntCellValue(count), baseStyle);
        _writeCell(
          sheet, row, 8,
          TextCellValue(ExcelFormatter.formatPercent(pct)),
          baseStyle,
        );
      }
      row++;
    }
  }

  // ─── Hoja 4: Presupuestos ─────────────────────────────────────────────

  static void _buildBudgetsSheet(Excel workbook, ExportData data) {
    final sheet = workbook['Presupuestos'];
    sheet.setColumnWidth(0, 26.0);
    sheet.setColumnWidth(1, 24.0);
    sheet.setColumnWidth(2, 16.0);
    sheet.setColumnWidth(3, 12.0);
    sheet.setColumnWidth(4, 14.0);
    sheet.setColumnWidth(5, 13.0);
    sheet.setColumnWidth(6, 13.0);
    sheet.setColumnWidth(7, 20.0);

    int row = 0;

    _writeCell(
      sheet, row, 0,
      TextCellValue('PRESUPUESTOS'),
      ExcelFormatter.titleStyle,
    );
    _mergeRow(sheet, row, 0, 7);
    row++;

    const headers = [
      'Nombre', 'Categoría', 'Monto Límite',
      'Período', 'Estado', 'Inicio', 'Fin', 'Cuenta',
    ];
    for (int i = 0; i < headers.length; i++) {
      _writeCell(sheet, row, i, TextCellValue(headers[i]), ExcelFormatter.headerStyle);
    }
    row++;

    for (int i = 0; i < data.budgets.length; i++) {
      final b = data.budgets[i];
      final isAlt = i % 2 == 1;
      final style = isAlt ? ExcelFormatter.altRowStyle : ExcelFormatter.valueStyle;
      final rightStyle = isAlt ? ExcelFormatter.altRowRightStyle : ExcelFormatter.valueRightStyle;

      _writeCell(sheet, row, 0, TextCellValue(b.name), style);
      _writeCell(
        sheet, row, 1,
        TextCellValue('${b.categoryIcon} ${b.categoryName}'), style,
      );
      _writeCell(
        sheet, row, 2,
        TextCellValue(ExcelFormatter.formatMoney(b.amount)), rightStyle,
      );
      _writeCell(sheet, row, 3, TextCellValue(b.periodName), style);
      _writeCell(sheet, row, 4, TextCellValue(b.statusText), style);
      _writeCell(
        sheet, row, 5,
        TextCellValue(ExcelFormatter.formatDate(b.startDate)), style,
      );
      _writeCell(
        sheet, row, 6,
        TextCellValue(ExcelFormatter.formatDate(b.endDate)), style,
      );
      _writeCell(
        sheet, row, 7,
        TextCellValue(data.accountNameById(b.accountId)), style,
      );
      row++;
    }
  }

  // ─── Hoja 5: Metas ────────────────────────────────────────────────────

  static void _buildGoalsSheet(Excel workbook, ExportData data) {
    final sheet = workbook['Metas'];
    sheet.setColumnWidth(0, 26.0);
    sheet.setColumnWidth(1, 14.0);
    sheet.setColumnWidth(2, 16.0);
    sheet.setColumnWidth(3, 16.0);
    sheet.setColumnWidth(4, 10.0);
    sheet.setColumnWidth(5, 14.0);
    sheet.setColumnWidth(6, 12.0);
    sheet.setColumnWidth(7, 15.0);
    sheet.setColumnWidth(8, 20.0);

    int row = 0;

    _writeCell(
      sheet, row, 0,
      TextCellValue('METAS FINANCIERAS'),
      ExcelFormatter.titleStyle,
    );
    _mergeRow(sheet, row, 0, 8);
    row++;

    const headers = [
      'Nombre', 'Tipo', 'Objetivo', 'Ahorrado',
      'Progreso', 'Estado', 'Prioridad', 'Fecha Límite', 'Cuenta',
    ];
    for (int i = 0; i < headers.length; i++) {
      _writeCell(sheet, row, i, TextCellValue(headers[i]), ExcelFormatter.headerStyle);
    }
    row++;

    for (int i = 0; i < data.goals.length; i++) {
      final g = data.goals[i];
      final isAlt = i % 2 == 1;
      final style = isAlt ? ExcelFormatter.altRowStyle : ExcelFormatter.valueStyle;
      final rightStyle = isAlt ? ExcelFormatter.altRowRightStyle : ExcelFormatter.valueRightStyle;
      final progress = g.targetAmount > 0 ? g.currentAmount / g.targetAmount : 0.0;

      _writeCell(sheet, row, 0, TextCellValue('${g.emoji} ${g.name}'), style);
      _writeCell(sheet, row, 1, TextCellValue(_goalTypeName(g.type)), style);
      _writeCell(
        sheet, row, 2,
        TextCellValue(ExcelFormatter.formatMoney(g.targetAmount)), rightStyle,
      );
      _writeCell(
        sheet, row, 3,
        TextCellValue(ExcelFormatter.formatMoney(g.currentAmount)),
        ExcelFormatter.amountStyle(isIncome: true, isAltRow: isAlt),
      );
      _writeCell(
        sheet, row, 4,
        TextCellValue(ExcelFormatter.formatPercent(progress)),
        ExcelFormatter.percentageStyle(progress),
      );
      _writeCell(sheet, row, 5, TextCellValue(_goalStatusName(g.status)), style);
      _writeCell(sheet, row, 6, TextCellValue(_goalPriorityName(g.priority)), style);
      _writeCell(
        sheet, row, 7,
        TextCellValue(ExcelFormatter.formatDate(g.targetDate)), style,
      );
      _writeCell(
        sheet, row, 8,
        TextCellValue(data.accountNameById(g.accountId)), style,
      );
      row++;
    }
  }

  // ─── Hoja extra: Por Cuenta ───────────────────────────────────────────

  static void _buildByAccountSheet(Excel workbook, ExportData data) {
    final sheet = workbook['Por Cuenta'];
    sheet.setColumnWidth(0, 30.0);  // Cuenta
    sheet.setColumnWidth(1, 18.0);  // Tipo
    sheet.setColumnWidth(2, 16.0);  // Ingresos
    sheet.setColumnWidth(3, 16.0);  // Gastos
    sheet.setColumnWidth(4, 16.0);  // Balance
    sheet.setColumnWidth(5, 14.0);  // Movimientos
    sheet.setColumnWidth(6, 14.0);  // % del gasto

    int row = 0;

    // Título
    _writeCell(
      sheet, row, 0,
      TextCellValue('DESGLOSE POR CUENTA — ${data.config.dateRangeLabel}'),
      ExcelFormatter.titleStyle,
    );
    _mergeRow(sheet, row, 0, 6);
    row++;

    _writeCell(
      sheet, row, 0,
      TextCellValue(
        'Generado: ${ExcelFormatter.formatDateTime(data.generatedAt)}  |  '
        '${data.accounts.length} cuentas',
      ),
      ExcelFormatter.metadataStyle,
    );
    _mergeRow(sheet, row, 0, 6);
    row += 2;

    // ── Tabla resumen por cuenta ──────────────────────────────────────
    _writeSectionHeader(sheet, row, 'TOTALES POR CUENTA', 7);
    row++;

    const summaryHeaders = [
      'Cuenta', 'Tipo de cuenta', 'Ingresos', 'Gastos', 'Balance', 'Movimientos', '% del gasto total',
    ];
    for (int i = 0; i < summaryHeaders.length; i++) {
      _writeCell(sheet, row, i, TextCellValue(summaryHeaders[i]), ExcelFormatter.headerStyle);
    }
    row++;

    for (int i = 0; i < data.accounts.length; i++) {
      final acc = data.accounts[i];
      final accTx = data.transactions.where((t) => t.accountId == acc.id).toList();
      final income = accTx
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (s, t) => s + t.amount);
      final expense = accTx
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (s, t) => s + t.amount);
      final balance = income - expense;
      final pctOfTotal = data.totalExpense > 0 ? expense / data.totalExpense : 0.0;
      final isAlt = i % 2 == 1;
      final style = isAlt ? ExcelFormatter.altRowStyle : ExcelFormatter.valueStyle;

      _writeCell(sheet, row, 0, TextCellValue('${acc.emoji} ${acc.name}'), style);
      _writeCell(sheet, row, 1, TextCellValue(acc.typeName), style);
      _writeCell(
        sheet, row, 2,
        TextCellValue(ExcelFormatter.formatMoney(income)),
        ExcelFormatter.amountStyle(isIncome: true, isAltRow: isAlt),
      );
      _writeCell(
        sheet, row, 3,
        TextCellValue(ExcelFormatter.formatMoney(expense)),
        ExcelFormatter.amountStyle(isIncome: false, isAltRow: isAlt),
      );
      _writeCell(
        sheet, row, 4,
        TextCellValue(ExcelFormatter.formatMoneyWithSign(balance)),
        ExcelFormatter.balanceStyle(isPositive: balance >= 0),
      );
      _writeCell(sheet, row, 5, IntCellValue(accTx.length), style);
      _writeCell(
        sheet, row, 6,
        TextCellValue(ExcelFormatter.formatPercent(pctOfTotal)),
        ExcelFormatter.percentageStyle(pctOfTotal),
      );
      row++;
    }

    // Fila de totales globales
    row++;
    _writeCell(sheet, row, 1, TextCellValue('TOTAL TODAS LAS CUENTAS'), ExcelFormatter.labelStyle);
    _writeCell(
      sheet, row, 2,
      TextCellValue(ExcelFormatter.formatMoney(data.totalIncome)),
      ExcelFormatter.incomeAmountStyle,
    );
    _writeCell(
      sheet, row, 3,
      TextCellValue(ExcelFormatter.formatMoney(data.totalExpense)),
      ExcelFormatter.expenseAmountStyle,
    );
    _writeCell(
      sheet, row, 4,
      TextCellValue(ExcelFormatter.formatMoneyWithSign(data.netBalance)),
      ExcelFormatter.balanceStyle(isPositive: data.netBalance >= 0),
    );
    _writeCell(sheet, row, 5, IntCellValue(data.transactionCount), ExcelFormatter.labelStyle);
    // Saldo inicial total si alguna cuenta tiene uno configurado
    if (data.totalInitialBalance != 0) {
      row++;
      _writeCell(sheet, row, 1, TextCellValue('SALDO INICIAL TOTAL'), ExcelFormatter.labelStyle);
      _writeCell(
        sheet, row, 2,
        TextCellValue(ExcelFormatter.formatMoney(data.totalInitialBalance)),
        ExcelFormatter.incomeAmountStyle,
      );
      row++;
      _writeCell(sheet, row, 1, TextCellValue('BALANCE REAL TOTAL'), ExcelFormatter.labelStyle);
      _writeCell(
        sheet, row, 2,
        TextCellValue(ExcelFormatter.formatMoneyWithSign(data.totalBalance)),
        ExcelFormatter.balanceStyle(isPositive: data.totalBalance >= 0),
      );
    }
    row += 2;

    // ── Desglose de transacciones agrupadas por cuenta ─────────────────
    for (final acc in data.accounts) {
      final accTx = data.transactions
          .where((t) => t.accountId == acc.id)
          .take(_maxRows)
          .toList();
      if (accTx.isEmpty) continue;

      // Sub-encabezado de cuenta
      _writeCell(
        sheet, row, 0,
        TextCellValue('${acc.emoji} ${acc.name}  (${accTx.length} movimientos)'),
        ExcelFormatter.subHeaderStyle,
      );
      _mergeRow(sheet, row, 0, 6);
      row++;

      // Encabezados de columna de transacciones
      const txHeaders = ['#', 'Fecha', 'Tipo', 'Descripción', 'Categoría', 'Monto', ''];
      for (int i = 0; i < txHeaders.length - 1; i++) {
        _writeCell(
          sheet, row, i,
          TextCellValue(txHeaders[i]),
          ExcelFormatter.headerStyle,
        );
      }
      row++;

      for (int i = 0; i < accTx.length; i++) {
        final t = accTx[i];
        final isAlt = i % 2 == 1;
        final isIncome = t.type == TransactionType.income;
        final isTransfer = t.type == TransactionType.transfer;
        final typeLabel = isTransfer
            ? 'Transferencia'
            : (isIncome ? 'Ingreso' : 'Gasto');
        final style = isAlt ? ExcelFormatter.altRowStyle : ExcelFormatter.valueStyle;

        _writeCell(sheet, row, 0, IntCellValue(i + 1), style);
        _writeCell(sheet, row, 1, TextCellValue(ExcelFormatter.formatDate(t.date)), style);
        _writeCell(sheet, row, 2, TextCellValue(typeLabel), style);
        _writeCell(sheet, row, 3, TextCellValue(t.description), style);
        _writeCell(sheet, row, 4, TextCellValue(t.categoryName), style);
        _writeCell(
          sheet, row, 5,
          TextCellValue(ExcelFormatter.formatMoney(t.amount)),
          ExcelFormatter.amountStyle(
            isIncome: isIncome,
            isAltRow: isAlt,
            isTransfer: isTransfer,
          ),
        );
        row++;
      }

      // Mini-totales al pie de cada cuenta
      final accIncome = accTx
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (s, t) => s + t.amount);
      final accExpense = accTx
          .where((t) => t.type == TransactionType.expense)
          .fold(0.0, (s, t) => s + t.amount);

      _writeCell(sheet, row, 4, TextCellValue('Ingresos:'), ExcelFormatter.labelStyle);
      _writeCell(
        sheet, row, 5,
        TextCellValue(ExcelFormatter.formatMoney(accIncome)),
        ExcelFormatter.incomeAmountStyle,
      );
      row++;
      _writeCell(sheet, row, 4, TextCellValue('Gastos:'), ExcelFormatter.labelStyle);
      _writeCell(
        sheet, row, 5,
        TextCellValue(ExcelFormatter.formatMoney(accExpense)),
        ExcelFormatter.expenseAmountStyle,
      );
      row++;
      _writeCell(sheet, row, 4, TextCellValue('Balance:'), ExcelFormatter.labelStyle);
      _writeCell(
        sheet, row, 5,
        TextCellValue(ExcelFormatter.formatMoneyWithSign(accIncome - accExpense)),
        ExcelFormatter.balanceStyle(isPositive: accIncome >= accExpense),
      );
      row++;
      if (acc.initialBalance != 0) {
        _writeCell(sheet, row, 4, TextCellValue('Saldo Inicial:'), ExcelFormatter.labelStyle);
        _writeCell(
          sheet, row, 5,
          TextCellValue(ExcelFormatter.formatMoney(acc.initialBalance)),
          ExcelFormatter.incomeAmountStyle,
        );
        row++;
        final realBalance = acc.initialBalance + accIncome - accExpense;
        _writeCell(sheet, row, 4, TextCellValue('Balance Real:'), ExcelFormatter.labelStyle);
        _writeCell(
          sheet, row, 5,
          TextCellValue(ExcelFormatter.formatMoneyWithSign(realBalance)),
          ExcelFormatter.balanceStyle(isPositive: realBalance >= 0),
        );
        row++;
      }
      row++; // espacio entre cuentas
    }
  }

  // ─── Helpers internos ─────────────────────────────────────────────────

  static void _writeCell(
    Sheet sheet,
    int row,
    int col,
    CellValue value,
    CellStyle style,
  ) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = value;
    cell.cellStyle = style;
  }

  static void _mergeRow(Sheet sheet, int row, int fromCol, int toCol) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: fromCol, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: toCol, rowIndex: row),
    );
  }

  static void _writeSectionHeader(
    Sheet sheet,
    int row,
    String title,
    int spanCols,
  ) {
    _writeCell(sheet, row, 0, TextCellValue(title), ExcelFormatter.headerStyle);
    _mergeRow(sheet, row, 0, spanCols - 1);
  }

  static void _writeLabelValue(
    Sheet sheet,
    int row,
    String label,
    String value, {
    bool valueIsIncome = false,
    bool valueIsExpense = false,
  }) {
    _writeCell(sheet, row, 0, TextCellValue(label), ExcelFormatter.labelStyle);
    final CellStyle valueStyle;
    if (valueIsIncome) {
      valueStyle = ExcelFormatter.incomeAmountStyle;
    } else if (valueIsExpense) {
      valueStyle = ExcelFormatter.expenseAmountStyle;
    } else {
      valueStyle = ExcelFormatter.valueStyle;
    }
    _writeCell(sheet, row, 1, TextCellValue(value), valueStyle);
  }

  // ─── Conversión de enums a texto ──────────────────────────────────────

  static String _goalTypeName(GoalType type) {
    switch (type) {
      case GoalType.purchase:
        return 'Compra';
      case GoalType.savings:
        return 'Ahorro';
      case GoalType.emergency:
        return 'Emergencia';
      case GoalType.vacation:
        return 'Vacaciones';
      case GoalType.education:
        return 'Educación';
      case GoalType.custom:
        return 'Personalizada';
    }
  }

  static String _goalStatusName(GoalStatus status) {
    switch (status) {
      case GoalStatus.active:
        return 'Activa';
      case GoalStatus.paused:
        return 'Pausada';
      case GoalStatus.completed:
        return 'Completada';
      case GoalStatus.cancelled:
        return 'Cancelada';
    }
  }

  static String _goalPriorityName(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low:
        return 'Baja';
      case GoalPriority.medium:
        return 'Media';
      case GoalPriority.high:
        return 'Alta';
      case GoalPriority.urgent:
        return 'Urgente';
    }
  }
}
