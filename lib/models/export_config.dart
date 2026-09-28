import 'transaction.dart';

/// Formato de exportación soportado.
enum ExportFormat {
  excel,
  pdf, // Reservado para implementación futura
  csv, // Reservado para implementación futura
}

/// Tipo de reporte: controla qué hojas incluye el exportador.
enum ReportType {
  transactions, // Transacciones + Por Categoría
  budgets, // Solo presupuestos
  goals, // Solo metas
  fullReport, // Todas las hojas
}

// ─────────────────────────────────────────────────────────────────────────────
// ExportFilters — solo lo que filtra datos
// ─────────────────────────────────────────────────────────────────────────────

/// Filtros de datos para la exportación.
///
/// Contiene únicamente los criterios que restringen qué registros se incluyen
/// en el reporte. Los metadatos del reporte (formato, tipo, opciones) viven
/// en [ExportConfig].
class ExportFilters {
  /// Fecha de inicio del período (inclusive).
  final DateTime dateFrom;

  /// Fecha de fin del período (inclusive).
  final DateTime dateTo;

  /// IDs de cuentas a incluir. Lista vacía = todas las cuentas.
  final List<String> accountIds;

  /// Categorías de gasto del sistema. Lista vacía = todas.
  final List<ExpenseCategory> expenseCategories;

  /// Categorías de ingreso. Lista vacía = todas.
  final List<IncomeCategory> incomeCategories;

  /// IDs de categorías personalizadas. Lista vacía = todas.
  final List<String> customCategoryIds;

  /// Tipos de movimiento. Lista vacía = ingresos y gastos.
  final List<TransactionType> transactionTypes;

  const ExportFilters({
    required this.dateFrom,
    required this.dateTo,
    this.accountIds = const [],
    this.expenseCategories = const [],
    this.incomeCategories = const [],
    this.customCategoryIds = const [],
    this.transactionTypes = const [],
  });

  // ─── Flags computados ───────────────────────────────────────────────────

  bool get hasAccountFilter => accountIds.isNotEmpty;

  bool get hasCategoryFilter =>
      expenseCategories.isNotEmpty ||
      incomeCategories.isNotEmpty ||
      customCategoryIds.isNotEmpty;

  bool get hasTypeFilter => transactionTypes.isNotEmpty;

  bool get hasAnyFilter =>
      hasAccountFilter || hasCategoryFilter || hasTypeFilter;

  // ─── Helpers de display ─────────────────────────────────────────────────

  String get dateRangeLabel {
    final from =
        '${dateFrom.day.toString().padLeft(2, '0')}/'
        '${dateFrom.month.toString().padLeft(2, '0')}/'
        '${dateFrom.year}';
    final to =
        '${dateTo.day.toString().padLeft(2, '0')}/'
        '${dateTo.month.toString().padLeft(2, '0')}/'
        '${dateTo.year}';
    return '$from — $to';
  }

  String get filterSummary {
    if (!hasAnyFilter) return 'Sin filtros adicionales';
    final parts = <String>[];
    if (hasAccountFilter) parts.add('${accountIds.length} cuenta(s)');
    if (hasCategoryFilter) parts.add('Categorías filtradas');
    if (hasTypeFilter) {
      final names = transactionTypes
          .map((t) {
            switch (t) {
              case TransactionType.income:
                return 'Ingresos';
              case TransactionType.expense:
                return 'Gastos';
              case TransactionType.transfer:
                return 'Transferencias';
            }
          })
          .join(', ');
      parts.add(names);
    }
    return parts.join(' · ');
  }

  // ─── Factory constructors para rangos de fecha comunes ──────────────────

  /// Mes en curso, todas las cuentas, sin filtros adicionales.
  factory ExportFilters.currentMonth() {
    final now = DateTime.now();
    return ExportFilters(
      dateFrom: DateTime(now.year, now.month, 1),
      dateTo: DateTime(now.year, now.month + 1, 0),
    );
  }

  /// Año en curso, todas las cuentas.
  factory ExportFilters.currentYear() {
    final now = DateTime.now();
    return ExportFilters(
      dateFrom: DateTime(now.year, 1, 1),
      dateTo: DateTime(now.year, 12, 31),
    );
  }

  /// Rango amplio que cubre todo el historial disponible (año 2000–hoy).
  factory ExportFilters.allTime() {
    return ExportFilters(
      dateFrom: DateTime(2000, 1, 1),
      dateTo: DateTime.now(),
    );
  }

  /// Mes en curso, restringido a una cuenta específica.
  factory ExportFilters.forAccount(String accountId) {
    final now = DateTime.now();
    return ExportFilters(
      dateFrom: DateTime(now.year, now.month, 1),
      dateTo: DateTime(now.year, now.month + 1, 0),
      accountIds: [accountId],
    );
  }

  // ─── copyWith ────────────────────────────────────────────────────────────

  ExportFilters copyWith({
    DateTime? dateFrom,
    DateTime? dateTo,
    List<String>? accountIds,
    List<ExpenseCategory>? expenseCategories,
    List<IncomeCategory>? incomeCategories,
    List<String>? customCategoryIds,
    List<TransactionType>? transactionTypes,
  }) {
    return ExportFilters(
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      accountIds: accountIds ?? this.accountIds,
      expenseCategories: expenseCategories ?? this.expenseCategories,
      incomeCategories: incomeCategories ?? this.incomeCategories,
      customCategoryIds: customCategoryIds ?? this.customCategoryIds,
      transactionTypes: transactionTypes ?? this.transactionTypes,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ExportConfig — metadatos del reporte + filtros
// ─────────────────────────────────────────────────────────────────────────────

/// Configuración completa e inmutable de un reporte a exportar.
///
/// Combina los [filters] de datos con las opciones del reporte ([reportType],
/// [format], [includeSummarySheet]). Se construye en la UI y se pasa a
/// [ExportService.generateAndSave].
class ExportConfig {
  /// Filtros que determinan qué registros se incluyen en el reporte.
  final ExportFilters filters;

  final ReportType reportType;
  final ExportFormat format;

  /// Incluir hoja de resumen ejecutivo con métricas clave.
  final bool includeSummarySheet;

  const ExportConfig({
    required this.filters,
    this.reportType = ReportType.fullReport,
    this.format = ExportFormat.excel,
    this.includeSummarySheet = true,
  });

  // ─── Delegación a filtros (atajos de display) ───────────────────────────

  String get dateRangeLabel => filters.dateRangeLabel;
  String get filterSummary => filters.filterSummary;

  // ─── Labels de opciones del reporte ────────────────────────────────────

  String get reportTypeLabel {
    switch (reportType) {
      case ReportType.transactions:
        return 'Solo transacciones';
      case ReportType.budgets:
        return 'Solo presupuestos';
      case ReportType.goals:
        return 'Solo metas';
      case ReportType.fullReport:
        return 'Reporte completo';
    }
  }

  String get formatLabel {
    switch (format) {
      case ExportFormat.excel:
        return 'Excel (.xlsx)';
      case ExportFormat.pdf:
        return 'PDF';
      case ExportFormat.csv:
        return 'CSV';
    }
  }

  // ─── Factory constructors ───────────────────────────────────────────────

  factory ExportConfig.currentMonth() =>
      ExportConfig(filters: ExportFilters.currentMonth());

  factory ExportConfig.currentYear() =>
      ExportConfig(filters: ExportFilters.currentYear());

  factory ExportConfig.allTime() =>
      ExportConfig(filters: ExportFilters.allTime());

  factory ExportConfig.forAccount(String accountId) =>
      ExportConfig(filters: ExportFilters.forAccount(accountId));

  // ─── copyWith ────────────────────────────────────────────────────────────

  ExportConfig copyWith({
    ExportFilters? filters,
    ReportType? reportType,
    ExportFormat? format,
    bool? includeSummarySheet,
  }) {
    return ExportConfig(
      filters: filters ?? this.filters,
      reportType: reportType ?? this.reportType,
      format: format ?? this.format,
      includeSummarySheet: includeSummarySheet ?? this.includeSummarySheet,
    );
  }
}
