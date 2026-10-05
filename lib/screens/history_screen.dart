import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../models/history_filters.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../services/account_service.dart';
import '../utils/format_utils.dart';
import '../widgets/history_filters_sheet.dart';
import '../widgets/transaction_actions_sheet.dart';
import 'add_transaction_screen.dart';
import 'export_screen.dart';
import 'financial_calendar_screen.dart';
import '../models/export_config.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';

/// Marcadores livianos usados para aplanar (encabezado / transacción /
/// separador) en una sola lista consumida por el SliverList perezoso de
/// _buildTransactionsSliver — ver esa función para el porqué.
class _DateHeaderItem {
  final String date;
  final List<Transaction> transactions;
  const _DateHeaderItem(this.date, this.transactions);
}

class _GroupSpacer {
  const _GroupSpacer();
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  final AccountService _accountService = AccountService();
  List<Transaction> _filteredTransactions = [];
  HistoryFilters _filters = HistoryFilters.empty;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _isLoading = true;

  // Modo selección: permite marcar varias transacciones y eliminarlas juntas.
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  // Definición de colores consistentes
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color deepBlue = AppColors.deepBlue;
  static const Color successGreen = AppColors.primaryGreen;
  static const Color dangerRed = AppColors.dangerRed;
  static const Color infoBlue = AppColors.primaryBlue;

  // Colores de texto y fondo
  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color backgroundLight = AppColors.backgroundLight;
  static const Color backgroundCard = AppColors.backgroundCard;
  static const Color borderLight = AppColors.borderLight;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadTransactions();
    // Escuchar cambios en CategoryService (para actualizar nombres/emojis)
    _categoryService.addListener(_onCategoryChanged);
    // Escuchar cambios de cuenta activa
    _accountService.addListener(_onAccountChanged);
  }

  void _onCategoryChanged() {
    if (mounted) {
      setState(() {
        // Forzar rebuild para mostrar nombres/emojis actualizados
      });
    }
  }

  void _onAccountChanged() {
    if (mounted) {
      _loadTransactions();
    }
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
  }

  Future<void> _loadTransactions() async {
    await _transactionService.loadTransactions();
    _applyFilter();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  // Un solo recorrido O(n) combinando todos los criterios activos — rápido
  // incluso con historiales grandes, en vez de encadenar varios .where().
  void _applyFilter() {
    setState(() {
      _filteredTransactions = _transactionService.transactions
          .where(_filters.matches)
          .toList();

      // Lo seleccionado que dejó de estar visible (nuevo filtro, otra cuenta
      // o ya eliminado) se desmarca: nunca se borra algo que no se está viendo.
      if (_selectedIds.isNotEmpty) {
        _selectedIds.retainAll(_filteredTransactions.map((t) => t.id).toSet());
      }
    });
  }

  // ───────────────────────── Modo selección ─────────────────────────

  bool get _allSelected =>
      _filteredTransactions.isNotEmpty &&
      _selectedIds.length == _filteredTransactions.length;

  void _enterSelectionMode([Transaction? first]) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      if (first != null) _selectedIds.add(first.id);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(Transaction transaction) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.remove(transaction.id)) {
        _selectedIds.add(transaction.id);
      }
      // Al desmarcar la última, el modo se cierra solo.
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  // "Todas" = las transacciones visibles con los filtros actuales (la misma
  // regla que ya usa "Eliminar todas").
  void _toggleSelectAll() {
    HapticFeedback.lightImpact();
    setState(() {
      final wasAll = _allSelected;
      _selectedIds.clear();
      if (!wasAll) _selectedIds.addAll(_filteredTransactions.map((t) => t.id));
    });
  }

  Future<void> _deleteSelected() async {
    final selected = _filteredTransactions
        .where((t) => _selectedIds.contains(t.id))
        .toList();
    if (selected.isEmpty) return;

    // Si se marcó todo lo visible, es exactamente "Eliminar todas": mismo
    // flujo de doble confirmación (aviso + escribir ELIMINAR).
    if (_allSelected) {
      _showDeleteAllDialog();
      return;
    }

    final count = selected.length;
    final hasTransfers = selected.any((t) => t.isTransfer);
    final confirmed = await showAppConfirmDialog(
      context,
      title: count == 1
          ? '¿Eliminar transacción?'
          : '¿Eliminar $count transacciones?',
      message: count == 1
          ? 'Esta acción no se puede deshacer. ¿Estás seguro de eliminar '
                '"${selected.first.description}"?'
          : 'Esta acción no se puede deshacer. Se eliminarán las $count '
                'transacciones seleccionadas.',
      extra: hasTransfers
          ? const Text(
              'Las transferencias se eliminan completas (también en la otra cuenta).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: textMedium, height: 1.4),
            )
          : null,
    );
    if (confirmed != true || !mounted) return;

    await _deleteTransactions(
      selected,
      successMessage: count == 1
          ? 'Transacción eliminada'
          : '$count transacciones eliminadas',
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _filters = _filters.copyWith(searchQuery: value);
      _applyFilter();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _filters = _filters.copyWith(searchQuery: '');
    _applyFilter();
  }

  // Alterna un chip de tipo rápido (Ingresos/Gastos/Transferencias). Tocar
  // el mismo chip otra vez lo desactiva (vuelve a "Todas").
  void _toggleQuickType(TransactionType type) {
    HapticFeedback.lightImpact();
    final isActive =
        _filters.transactionTypes.length == 1 &&
        _filters.transactionTypes.contains(type);
    _filters = _filters.copyWith(transactionTypes: isActive ? {} : {type});
    _applyFilter();
  }

  void _selectAllTypes() {
    HapticFeedback.lightImpact();
    _filters = _filters.copyWith(transactionTypes: {});
    _applyFilter();
  }

  // "Este mes" es independiente del tipo — se puede combinar, ej. Gastos +
  // Este mes. Tocarlo de nuevo lo desactiva.
  void _toggleThisMonth() {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0);
    final isActive =
        _isSameDay(_filters.dateFrom, from) && _isSameDay(_filters.dateTo, to);
    if (isActive) {
      _filters = _filters.copyWith(clearDateFrom: true, clearDateTo: true);
    } else {
      _filters = _filters.copyWith(dateFrom: from, dateTo: to);
    }
    _applyFilter();
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _openAdvancedFilters() async {
    HapticFeedback.lightImpact();
    final result = await showModalBottomSheet<HistoryFilters>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => HistoryFiltersSheet(
        initialFilters: _filters,
        accounts: _accountService.accounts,
        customCategories: _categoryService.customCategories,
      ),
    );
    if (result != null) {
      setState(() => _filters = result);
      _applyFilter();
    }
  }

  void _clearAllFilters() {
    HapticFeedback.lightImpact();
    _searchController.clear();
    _filters = HistoryFilters.empty;
    _applyFilter();
  }

  @override
  void dispose() {
    _categoryService.removeListener(_onCategoryChanged);
    _accountService.removeListener(_onAccountChanged);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [primaryBlue, darkBlue],
                  ),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Cargando historial...',
                style: TextStyle(
                  color: textMedium,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // El botón Atrás cierra primero el modo selección y recién después sale.
    return PopScope(
      canPop: !_selectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectionMode) _exitSelectionMode();
      },
      child: Scaffold(
        backgroundColor: backgroundLight,
        body: RefreshIndicator(
          onRefresh: _loadTransactions,
          color: primaryBlue,
          backgroundColor: Colors.white,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildModernAppBar(),
              SliverToBoxAdapter(
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Opacity(
                        opacity: _fadeInAnimation.value,
                        child: Column(
                          children: [
                            _buildFilterSection(),
                            _buildSummarySection(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildTransactionsSliver(),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: backgroundLight,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryBlue, darkBlue, deepBlue],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: _buildHeaderTitle()),
                      const SizedBox(width: 16),
                      Row(
                        children: _selectionMode
                            ? [
                                _buildHeaderAction(
                                  Icons.close_rounded,
                                  'Cancelar selección',
                                  _exitSelectionMode,
                                ),
                                const SizedBox(width: 8),
                                _buildHeaderAction(
                                  _allSelected
                                      ? Icons.deselect_rounded
                                      : Icons.select_all_rounded,
                                  _allSelected
                                      ? 'Quitar selección'
                                      : 'Seleccionar todas',
                                  _filteredTransactions.isNotEmpty
                                      ? _toggleSelectAll
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                _buildHeaderAction(
                                  Icons.delete_rounded,
                                  'Eliminar seleccionadas',
                                  _selectedIds.isNotEmpty
                                      ? _deleteSelected
                                      : null,
                                ),
                              ]
                            : [
                                _buildHeaderAction(
                                  Icons.calendar_month_rounded,
                                  'Calendario financiero',
                                  _navigateToCalendar,
                                ),
                                const SizedBox(width: 8),
                                _buildHeaderAction(
                                  Icons.file_download_outlined,
                                  'Exportar',
                                  _navigateToExport,
                                ),
                                const SizedBox(width: 8),
                                _buildHeaderAction(
                                  Icons.delete_sweep_rounded,
                                  'Eliminar todas',
                                  _filteredTransactions.isNotEmpty
                                      ? _showDeleteAllDialog
                                      : null,
                                ),
                              ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Título del encabezado: "Historial" o el conteo de la selección. Va dentro
  /// de un FittedBox para que nunca desborde junto a los botones.
  Widget _buildHeaderTitle() {
    final String title;
    final String subtitle;
    if (_selectionMode) {
      final n = _selectedIds.length;
      title = n == 0
          ? 'Selecciona'
          : (n == 1 ? '1 seleccionada' : '$n seleccionadas');
      subtitle = 'Toca para marcar';
    } else {
      title = 'Historial';
      subtitle = 'Revisa todas tus transacciones';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildHeaderAction(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed,
  ) {
    final isEnabled = onPressed != null;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          if (isEnabled) {
            HapticFeedback.lightImpact();
            onPressed();
          }
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isEnabled
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            border: Border.all(
              color: isEnabled
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isEnabled ? Colors.white : Colors.white.withOpacity(0.5),
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: borderLight, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [primaryBlue, darkBlue],
                  ),
                ),
                child: const Icon(
                  Icons.filter_list_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtrar Transacciones',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Encuentra lo que buscas rápidamente',
                      style: TextStyle(color: textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (_filters.hasAnyFilter)
                TextButton(
                  onPressed: _clearAllFilters,
                  child: const Text('Limpiar'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchField(),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickChip(
                  label: 'Todas',
                  isSelected: !_filters.hasTypeFilter,
                  onTap: _selectAllTypes,
                ),
                _buildQuickChip(
                  label: 'Ingresos',
                  isSelected:
                      _filters.transactionTypes.length == 1 &&
                      _filters.transactionTypes.contains(
                        TransactionType.income,
                      ),
                  onTap: () => _toggleQuickType(TransactionType.income),
                ),
                _buildQuickChip(
                  label: 'Gastos',
                  isSelected:
                      _filters.transactionTypes.length == 1 &&
                      _filters.transactionTypes.contains(
                        TransactionType.expense,
                      ),
                  onTap: () => _toggleQuickType(TransactionType.expense),
                ),
                _buildQuickChip(
                  label: 'Transferencias',
                  isSelected:
                      _filters.transactionTypes.length == 1 &&
                      _filters.transactionTypes.contains(
                        TransactionType.transfer,
                      ),
                  onTap: () => _toggleQuickType(TransactionType.transfer),
                ),
                _buildQuickChip(
                  label: 'Este mes',
                  isSelected:
                      _isSameDay(
                        _filters.dateFrom,
                        DateTime(DateTime.now().year, DateTime.now().month, 1),
                      ) &&
                      _isSameDay(
                        _filters.dateTo,
                        DateTime(
                          DateTime.now().year,
                          DateTime.now().month + 1,
                          0,
                        ),
                      ),
                  onTap: _toggleThisMonth,
                ),
                _buildMoreFiltersChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Buscar por descripción o categoría...',
        hintStyle: const TextStyle(color: textMedium, fontSize: 14),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: textMedium,
          size: 22,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: textMedium,
                size: 20,
              ),
              onPressed: _clearSearch,
            );
          },
        ),
        filled: true,
        fillColor: backgroundCard,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
      ),
    );
  }

  Widget _buildQuickChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryBlue : backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryBlue : borderLight,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : textDark,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildMoreFiltersChip() {
    final count = _filters.advancedFilterCount;
    final isActive = count > 0;
    return GestureDetector(
      onTap: _openAdvancedFilters,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryBlue : backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? primaryBlue : borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 16,
              color: isActive ? Colors.white : textDark,
            ),
            const SizedBox(width: 6),
            Text(
              isActive ? 'Más filtros ($count)' : 'Más filtros',
              style: TextStyle(
                color: isActive ? Colors.white : textDark,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final totalIncome = _filteredTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);

    final totalExpenses = _filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);

    final balance = totalIncome - totalExpenses;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Resumen principal
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: borderLight, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: const LinearGradient(
                          colors: [infoBlue, primaryBlue],
                        ),
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Resumen Financiero',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_filteredTransactions.length} transacciones encontradas',
                            style: const TextStyle(
                              color: textMedium,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Ingresos',
                        FormatUtils.formatMoney(totalIncome),
                        successGreen,
                        Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Total Gastos',
                        FormatUtils.formatMoney(totalExpenses),
                        dangerRed,
                        Icons.trending_down_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: balance >= 0
                        ? successGreen.withOpacity(0.1)
                        : dangerRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: balance >= 0
                          ? successGreen.withOpacity(0.2)
                          : dangerRed.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        balance >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        color: balance >= 0 ? successGreen : dangerRed,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: AmountText(
                          'Balance: ${FormatUtils.formatMoney(balance.abs())}',
                          alignment: Alignment.center,
                          style: TextStyle(
                            color: balance >= 0 ? successGreen : dangerRed,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Icon(icon, color: color, size: 20)],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Construye la lista de transacciones como un SliverList perezoso: con
  // historiales grandes, solo se construyen los widgets de las filas
  // realmente visibles (antes se armaban todas de una vez en un Column).
  Widget _buildTransactionsSliver() {
    if (_filteredTransactions.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    final groupedTransactions = _groupTransactionsByDate(_filteredTransactions);

    // Aplanamos (encabezados de fecha + transacciones + separadores) en una
    // sola lista liviana — son referencias, no widgets, así que hacerlo de
    // una vez es barato incluso con miles de transacciones.
    final items = <Object>[];
    for (final entry in groupedTransactions.entries) {
      items.add(_DateHeaderItem(entry.key, entry.value));
      items.addAll(entry.value);
      items.add(const _GroupSpacer());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index == 0) return _buildListHeading();
          final item = items[index - 1];
          if (item is _DateHeaderItem) {
            return _buildDateHeader(item.date, item.transactions);
          }
          if (item is _GroupSpacer) {
            return const SizedBox(height: 16);
          }
          return _buildTransactionItem(item as Transaction);
        }, childCount: items.length + 1),
      ),
    );
  }

  /// "Transacciones" + el punto de entrada visible al modo selección (el gesto
  /// de mantener presionado no se descubre solo).
  Widget _buildListHeading() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Transacciones',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textDark,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (_selectionMode)
            TextButton(
              onPressed: _toggleSelectAll,
              child: Text(
                _allSelected ? 'Quitar selección' : 'Seleccionar todas',
              ),
            )
          else
            TextButton.icon(
              onPressed: _enterSelectionMode,
              icon: const Icon(Icons.checklist_rounded, size: 20),
              label: const Text('Seleccionar'),
            ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String date, List<Transaction> transactions) {
    // Las transferencias no son ingreso ni gasto: no participan del total
    // neto del día (solo se muestran como su propia línea, más abajo).
    final totalAmount = transactions.fold(0.0, (sum, t) {
      if (t.type == TransactionType.income) return sum + t.amount;
      if (t.type == TransactionType.expense) return sum - t.amount;
      return sum;
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLight, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: textMedium, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: textDark,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: totalAmount >= 0
                    ? successGreen.withOpacity(0.1)
                    : dangerRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AmountText(
                '${totalAmount >= 0 ? '+' : ''}${FormatUtils.formatMoney(totalAmount.abs())}',
                alignment: Alignment.centerRight,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: totalAmount >= 0 ? successGreen : dangerRed,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final color = _transactionColor(transaction);
    final sign = _transactionSign(transaction);
    final isSelected = _selectionMode && _selectedIds.contains(transaction.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? primaryBlue.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isSelected ? primaryBlue : borderLight,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Semantics(
        selected: _selectionMode ? isSelected : null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            // Tocar: en modo normal abre Editar/Eliminar; en modo selección
            // marca o desmarca. Mantener presionado inicia la selección.
            onTap: () => _selectionMode
                ? _toggleSelected(transaction)
                : _showTransactionOptions(transaction),
            onLongPress: () => _selectionMode
                ? _toggleSelected(transaction)
                : _enterSelectionMode(transaction),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  _buildTransactionLeading(transaction, color, isSelected),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.description,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getCategoryName(transaction),
                          style: const TextStyle(
                            color: textMedium,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          FormatUtils.formatDateForList(transaction.date),
                          style: TextStyle(fontSize: 12, color: textMedium),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$sign${FormatUtils.formatMoney(transaction.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Emoji de la categoría. En modo selección lleva encima un círculo de
  /// marcado (vacío / con check): no ocupa espacio extra en pantallas angostas.
  Widget _buildTransactionLeading(
    Transaction transaction,
    Color color,
    bool isSelected,
  ) {
    final tile = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isSelected
            ? primaryBlue.withOpacity(0.12)
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          _getCategoryEmoji(transaction),
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );

    if (!_selectionMode) return tile;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          top: -6,
          left: -6,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? primaryBlue : Colors.white,
              border: Border.all(
                color: isSelected ? primaryBlue : textMedium.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
        ),
      ],
    );
  }

  /// Color semántico según el tipo de transacción (verde/rojo/azul).
  Color _transactionColor(Transaction t) {
    switch (t.type) {
      case TransactionType.income:
        return successGreen;
      case TransactionType.expense:
        return dangerRed;
      case TransactionType.transfer:
        return primaryBlue;
    }
  }

  /// Signo del monto según el tipo de transacción (una transferencia usa
  /// [Transaction.isTransferOut] en vez del tipo para saber el signo).
  String _transactionSign(Transaction t) {
    switch (t.type) {
      case TransactionType.income:
        return '+';
      case TransactionType.expense:
        return '-';
      case TransactionType.transfer:
        return (t.isTransferOut ?? true) ? '-' : '+';
    }
  }

  /// Obtiene el nombre actualizado de la categoría
  String _getCategoryName(Transaction transaction) {
    if (transaction.hasCustomCategory) {
      final info = _categoryService.getCategoryInfo(
        transaction.customCategoryId,
        transaction.expenseCategory,
      );
      return info['name']!;
    }
    return transaction.categoryName;
  }

  /// Obtiene el emoji actualizado de la categoría
  String _getCategoryEmoji(Transaction transaction) {
    if (transaction.hasCustomCategory) {
      final info = _categoryService.getCategoryInfo(
        transaction.customCategoryId,
        transaction.expenseCategory,
      );
      return info['emoji']!;
    }
    return transaction.categoryIcon;
  }

  Widget _buildEmptyState() {
    // Distinguimos "no hay transacciones" de "ninguna coincide con los
    // filtros" — son situaciones distintas y ameritan mensajes/CTA distintos.
    final hasFilters = _filters.hasAnyFilter;
    final String message = hasFilters ? 'Sin resultados' : 'Historial vacío';
    final String subtitle = hasFilters
        ? 'No encontramos transacciones que coincidan con tu búsqueda o filtros'
        : 'Comienza agregando tu primera transacción';
    final IconData icon = hasFilters
        ? Icons.search_off_rounded
        : Icons.history_rounded;

    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(colors: [primaryBlue, darkBlue]),
            ),
            child: Icon(icon, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textMedium,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              hasFilters ? _clearAllFilters() : _navigateToAddTransaction();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [primaryBlue, darkBlue]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    hasFilters
                        ? Icons.filter_alt_off_rounded
                        : Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasFilters ? 'Limpiar filtros' : 'Agregar Transacción',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Transaction>> _groupTransactionsByDate(
    List<Transaction> transactions,
  ) {
    final Map<String, List<Transaction>> grouped = {};

    for (final transaction in transactions) {
      final dateKey = FormatUtils.formatDateForList(transaction.date);

      if (grouped[dateKey] == null) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }

    return grouped;
  }

  void _navigateToExport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExportScreen(
          initialConfig: ExportConfig.forAccount(
            _accountService.activeAccountId,
          ),
        ),
      ),
    );
  }

  void _navigateToCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FinancialCalendarScreen()),
    );
  }

  Future<void> _navigateToAddTransaction() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const AddTransactionScreen(initialType: TransactionType.income),
      ),
    );

    if (result == true) {
      _loadTransactions();
    }
  }

  // Menú contextual (detalle + Editar/Eliminar): widget compartido con Inicio.
  Future<void> _showTransactionOptions(Transaction transaction) async {
    final changed = await showTransactionActions(context, transaction);
    if (changed && mounted) _loadTransactions();
  }

  // Método para mostrar el diálogo de eliminar todas las transacciones
  void _showDeleteAllDialog() {
    showDialog(context: context, builder: (context) => _buildDeleteAllDialog());
  }

  Widget _buildDeleteAllDialog() {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: dangerRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Icon(Icons.warning_rounded, color: dangerRed, size: 32),
          ),
          const SizedBox(height: 20),
          const Text(
            '¿Eliminar transacciones de esta cuenta?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _deleteAllWarning(),
            style: const TextStyle(
              fontSize: 14,
              color: textMedium,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: borderLight),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      color: textMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showDeleteAllConfirmationDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: dangerRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Segunda confirmación con texto
  void _showDeleteAllConfirmationDialog() {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: dangerRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: dangerRed,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Confirmación Final',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para confirmar que deseas eliminar las transacciones de esta cuenta, escribe "ELIMINAR" en el campo de abajo:',
                  style: TextStyle(
                    fontSize: 14,
                    color: textMedium,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: confirmController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ELIMINAR',
                    hintStyle: TextStyle(
                      color: textMedium.withOpacity(0.5),
                      letterSpacing: 2,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderLight),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: dangerRed, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: borderLight),
                          ),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: textMedium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed:
                            confirmController.text.trim().toUpperCase() ==
                                'ELIMINAR'
                            ? () {
                                Navigator.pop(context);
                                _deleteAllTransactions();
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dangerRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Eliminar Todo',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _deleteAllWarning() {
    final count = _filteredTransactions.length;
    final hasTransfers = _filteredTransactions.any((t) => t.isTransfer);
    final what = count == 1 ? 'la transacción' : 'las $count transacciones';
    final scope = hasTransfers
        ? 'Las transferencias se eliminan completas, también en la otra cuenta.'
        : 'Las otras cuentas no se verán afectadas.';
    return 'Esta acción eliminará $what de la cuenta activa. $scope '
        'No se puede deshacer.';
  }

  // Elimina exactamente las transacciones visibles en pantalla
  Future<void> _deleteAllTransactions() => _deleteTransactions(
    List.of(_filteredTransactions),
    successMessage: 'Todas las transacciones han sido eliminadas',
  );

  /// Borrado común de "Eliminar todas" y de la selección múltiple: captura los
  /// IDs antes de cualquier operación asíncrona y borra solo esos.
  Future<void> _deleteTransactions(
    List<Transaction> toDelete, {
    required String successMessage,
  }) async {
    final idsToDelete = toDelete.map((t) => t.id).toList();
    try {
      await _transactionService.deleteTransactionsByIds(idsToDelete);
      if (mounted) {
        setState(() {
          _selectionMode = false;
          _selectedIds.clear();
        });
      }
      await _loadTransactions();
      if (mounted) _showSuccessSnackBar(successMessage);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar transacciones: ${e.toString()}'),
            backgroundColor: dangerRed,
          ),
        );
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: successGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: successGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
