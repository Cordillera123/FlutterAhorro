import 'transaction.dart';

/// Criterios de filtrado del Historial de transacciones.
///
/// Objeto inmutable: cada cambio crea una copia nueva vía [copyWith]. Expone
/// un único [matches] que combina todos los criterios en un solo recorrido
/// — así filtrar la lista completa sigue siendo un solo paso O(n), aunque
/// haya muchos criterios activos a la vez.
class HistoryFilters {
  final String searchQuery;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Set<String> accountIds;
  final Set<ExpenseCategory> expenseCategories;
  final Set<IncomeCategory> incomeCategories;
  final Set<String> customCategoryIds;
  final Set<TransactionType> transactionTypes;
  final double? amountMin;
  final double? amountMax;

  const HistoryFilters({
    this.searchQuery = '',
    this.dateFrom,
    this.dateTo,
    this.accountIds = const {},
    this.expenseCategories = const {},
    this.incomeCategories = const {},
    this.customCategoryIds = const {},
    this.transactionTypes = const {},
    this.amountMin,
    this.amountMax,
  });

  static const HistoryFilters empty = HistoryFilters();

  // ─── Flags ──────────────────────────────────────────────────────────────

  bool get hasSearch => searchQuery.trim().isNotEmpty;
  bool get hasDateFilter => dateFrom != null || dateTo != null;
  bool get hasAccountFilter => accountIds.isNotEmpty;
  bool get hasCategoryFilter =>
      expenseCategories.isNotEmpty ||
      incomeCategories.isNotEmpty ||
      customCategoryIds.isNotEmpty;
  bool get hasTypeFilter => transactionTypes.isNotEmpty;
  bool get hasAmountFilter => amountMin != null || amountMax != null;

  /// Filtros "avanzados" — los que viven en la hoja "Más filtros" (todo
  /// menos la búsqueda de texto y los chips rápidos de tipo).
  bool get hasAdvancedFilters =>
      hasDateFilter || hasAccountFilter || hasCategoryFilter || hasAmountFilter;

  bool get hasAnyFilter => hasSearch || hasTypeFilter || hasAdvancedFilters;

  /// Cantidad de grupos de filtro avanzado activos — para el badge del
  /// botón "Más filtros".
  int get advancedFilterCount {
    var count = 0;
    if (hasDateFilter) count++;
    if (hasAccountFilter) count++;
    if (hasCategoryFilter) count++;
    if (hasAmountFilter) count++;
    return count;
  }

  // ─── Copia ──────────────────────────────────────────────────────────────

  HistoryFilters copyWith({
    String? searchQuery,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
    Set<String>? accountIds,
    Set<ExpenseCategory>? expenseCategories,
    Set<IncomeCategory>? incomeCategories,
    Set<String>? customCategoryIds,
    Set<TransactionType>? transactionTypes,
    double? amountMin,
    bool clearAmountMin = false,
    double? amountMax,
    bool clearAmountMax = false,
  }) {
    return HistoryFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      accountIds: accountIds ?? this.accountIds,
      expenseCategories: expenseCategories ?? this.expenseCategories,
      incomeCategories: incomeCategories ?? this.incomeCategories,
      customCategoryIds: customCategoryIds ?? this.customCategoryIds,
      transactionTypes: transactionTypes ?? this.transactionTypes,
      amountMin: clearAmountMin ? null : (amountMin ?? this.amountMin),
      amountMax: clearAmountMax ? null : (amountMax ?? this.amountMax),
    );
  }

  /// Quita todos los filtros avanzados (fecha, cuentas, categorías, monto)
  /// pero conserva la búsqueda de texto y los chips rápidos de tipo.
  HistoryFilters clearAdvanced() {
    return HistoryFilters(
      searchQuery: searchQuery,
      transactionTypes: transactionTypes,
    );
  }

  // ─── Matching ───────────────────────────────────────────────────────────

  bool matches(Transaction t) {
    if (transactionTypes.isNotEmpty && !transactionTypes.contains(t.type)) {
      return false;
    }

    if (dateFrom != null || dateTo != null) {
      final day = DateTime(t.date.year, t.date.month, t.date.day);
      if (dateFrom != null) {
        final from = DateTime(dateFrom!.year, dateFrom!.month, dateFrom!.day);
        if (day.isBefore(from)) return false;
      }
      if (dateTo != null) {
        final to = DateTime(dateTo!.year, dateTo!.month, dateTo!.day);
        if (day.isAfter(to)) return false;
      }
    }

    if (accountIds.isNotEmpty && !accountIds.contains(t.accountId)) {
      return false;
    }

    if (hasCategoryFilter && !_matchesCategory(t)) {
      return false;
    }

    if (amountMin != null && t.amount < amountMin!) return false;
    if (amountMax != null && t.amount > amountMax!) return false;

    if (hasSearch) {
      final query = _normalize(searchQuery);
      final haystack = _normalize(
        '${t.description} ${t.categoryName} ${t.customCategoryName ?? ''}',
      );
      if (!haystack.contains(query)) return false;
    }

    return true;
  }

  bool _matchesCategory(Transaction t) {
    if (t.hasCustomCategory) {
      return customCategoryIds.contains(t.customCategoryId);
    }
    if (t.type == TransactionType.expense) {
      return t.expenseCategory != null &&
          expenseCategories.contains(t.expenseCategory);
    }
    if (t.type == TransactionType.income) {
      return t.incomeCategory != null &&
          incomeCategories.contains(t.incomeCategory);
    }
    // Las transferencias no tienen categoría: si hay un filtro de categoría
    // activo, quedan fuera (igual que en la exportación).
    return false;
  }

  static const Map<String, String> _accentMap = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };

  static String _normalize(String input) {
    var result = input.toLowerCase();
    _accentMap.forEach((accented, plain) {
      result = result.replaceAll(accented, plain);
    });
    return result;
  }
}
