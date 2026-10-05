import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/account.dart';
import '../models/custom_category.dart';
import '../models/history_filters.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';

/// Nombre + emoji de cada categoría de gasto, en el mismo orden y con los
/// mismos textos que ya se ven en el historial (Transaction.categoryName).
const List<(ExpenseCategory, String, String)> _expenseCategoryOptions = [
  (ExpenseCategory.transport, 'Transporte', '🚗'),
  (ExpenseCategory.food, 'Alimentación', '🍕'),
  (ExpenseCategory.utilities, 'Servicios Básicos', '💡'),
  (ExpenseCategory.health, 'Salud', '🏥'),
  (ExpenseCategory.education, 'Educación', '📚'),
  (ExpenseCategory.entertainment, 'Entretenimiento', '🎬'),
  (ExpenseCategory.clothing, 'Ropa y Calzado', '👕'),
  (ExpenseCategory.home, 'Hogar y Muebles', '🏠'),
  (ExpenseCategory.technology, 'Tecnología', '📱'),
  (ExpenseCategory.savings, 'Ahorros e Inversión', '💰'),
  (ExpenseCategory.gifts, 'Regalos y Donaciones', '🎁'),
  (ExpenseCategory.other, 'Otros gastos', '📦'),
];

const List<(IncomeCategory, String, String)> _incomeCategoryOptions = [
  (IncomeCategory.salary, 'Salario', '💼'),
  (IncomeCategory.freelance, 'Freelance', '💻'),
  (IncomeCategory.business, 'Negocio', '🏪'),
  (IncomeCategory.investment, 'Inversiones', '📈'),
  (IncomeCategory.rental, 'Alquiler', '🏠'),
  (IncomeCategory.bonus, 'Bonificación', '🎯'),
  (IncomeCategory.commission, 'Comisión', '🤝'),
  (IncomeCategory.refund, 'Reembolso', '↩️'),
  (IncomeCategory.gift, 'Regalo', '🎁'),
  (IncomeCategory.extra, 'Extra', '⭐'),
  (IncomeCategory.other, 'Otros ingresos', '💰'),
];

/// Hoja inferior de filtros avanzados del Historial: fecha, cuentas,
/// categorías y rango de monto. Devuelve el [HistoryFilters] resultante
/// vía `Navigator.pop` — o `null` si se cierra sin aplicar.
///
/// Solo edita los campos "avanzados"; `searchQuery` y `transactionTypes`
/// (controlados por la búsqueda y los chips rápidos de la pantalla) se
/// preservan tal cual venían en [initialFilters].
class HistoryFiltersSheet extends StatefulWidget {
  final HistoryFilters initialFilters;
  final List<Account> accounts;
  final List<CustomCategory> customCategories;

  const HistoryFiltersSheet({
    super.key,
    required this.initialFilters,
    required this.accounts,
    required this.customCategories,
  });

  @override
  State<HistoryFiltersSheet> createState() => _HistoryFiltersSheetState();
}

enum _DatePreset { thisMonth, thisYear, allTime, custom }

class _HistoryFiltersSheetState extends State<HistoryFiltersSheet> {
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color borderLight = AppColors.borderLight;
  static const Color backgroundLight = AppColors.backgroundLight;

  DateTime? _dateFrom;
  DateTime? _dateTo;
  late Set<String> _accountIds;
  late Set<ExpenseCategory> _expenseCategories;
  late Set<IncomeCategory> _incomeCategories;
  late Set<String> _customCategoryIds;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilters;
    _dateFrom = f.dateFrom;
    _dateTo = f.dateTo;
    _accountIds = Set.of(f.accountIds);
    _expenseCategories = Set.of(f.expenseCategories);
    _incomeCategories = Set.of(f.incomeCategories);
    _customCategoryIds = Set.of(f.customCategoryIds);
    _minController = TextEditingController(
      text: f.amountMin != null ? _trimZeros(f.amountMin!) : '',
    );
    _maxController = TextEditingController(
      text: f.amountMax != null ? _trimZeros(f.amountMax!) : '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  static String _trimZeros(double value) {
    final text = value.toStringAsFixed(2);
    return text.endsWith('.00') ? text.substring(0, text.length - 3) : text;
  }

  _DatePreset get _activePreset {
    if (_dateFrom == null && _dateTo == null) return _DatePreset.allTime;
    final now = DateTime.now();
    if (_isSameDay(_dateFrom, DateTime(now.year, now.month, 1)) &&
        _isSameDay(_dateTo, DateTime(now.year, now.month + 1, 0))) {
      return _DatePreset.thisMonth;
    }
    if (_isSameDay(_dateFrom, DateTime(now.year, 1, 1)) &&
        _isSameDay(_dateTo, DateTime(now.year, 12, 31))) {
      return _DatePreset.thisYear;
    }
    return _DatePreset.custom;
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _applyPreset(_DatePreset preset) {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() {
      switch (preset) {
        case _DatePreset.thisMonth:
          _dateFrom = DateTime(now.year, now.month, 1);
          _dateTo = DateTime(now.year, now.month + 1, 0);
          break;
        case _DatePreset.thisYear:
          _dateFrom = DateTime(now.year, 1, 1);
          _dateTo = DateTime(now.year, 12, 31);
          break;
        case _DatePreset.allTime:
          _dateFrom = null;
          _dateTo = null;
          break;
        case _DatePreset.custom:
          break;
      }
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = (isFrom ? _dateFrom : _dateTo) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) _dateFrom = picked;
      }
    });
  }

  void _clearAll() {
    HapticFeedback.lightImpact();
    setState(() {
      _dateFrom = null;
      _dateTo = null;
      _accountIds = {};
      _expenseCategories = {};
      _incomeCategories = {};
      _customCategoryIds = {};
      _minController.clear();
      _maxController.clear();
    });
  }

  void _apply() {
    final min = double.tryParse(_minController.text);
    final max = double.tryParse(_maxController.text);
    final result = widget.initialFilters.copyWith(
      dateFrom: _dateFrom,
      clearDateFrom: _dateFrom == null,
      dateTo: _dateTo,
      clearDateTo: _dateTo == null,
      accountIds: _accountIds,
      expenseCategories: _expenseCategories,
      incomeCategories: _incomeCategories,
      customCategoryIds: _customCategoryIds,
      amountMin: min,
      clearAmountMin: min == null,
      amountMax: max,
      clearAmountMax: max == null,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Más filtros',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    TextButton(
                      onPressed: _clearAll,
                      child: const Text('Limpiar'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    _sectionLabel('Rango de fechas'),
                    const SizedBox(height: 10),
                    _buildDatePresets(),
                    const SizedBox(height: 10),
                    _buildDateRangeRow(),
                    const SizedBox(height: 24),
                    _sectionLabel('Cuentas'),
                    const SizedBox(height: 10),
                    _buildAccountChips(),
                    const SizedBox(height: 24),
                    _sectionLabel('Categorías de gasto'),
                    const SizedBox(height: 10),
                    _buildCategoryChips(
                      options: _expenseCategoryOptions,
                      selected: _expenseCategories,
                      onToggle: (c) => setState(() {
                        _expenseCategories.contains(c)
                            ? _expenseCategories.remove(c)
                            : _expenseCategories.add(c);
                      }),
                    ),
                    const SizedBox(height: 24),
                    _sectionLabel('Categorías de ingreso'),
                    const SizedBox(height: 10),
                    _buildCategoryChips(
                      options: _incomeCategoryOptions,
                      selected: _incomeCategories,
                      onToggle: (c) => setState(() {
                        _incomeCategories.contains(c)
                            ? _incomeCategories.remove(c)
                            : _incomeCategories.add(c);
                      }),
                    ),
                    if (widget.customCategories.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionLabel('Categorías personalizadas'),
                      const SizedBox(height: 10),
                      _buildCustomCategoryChips(),
                    ],
                    const SizedBox(height: 24),
                    _sectionLabel('Rango de monto'),
                    const SizedBox(height: 10),
                    _buildAmountRange(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _apply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Aplicar filtros',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: textMedium,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildDatePresets() {
    const presets = [
      (_DatePreset.allTime, 'Todo'),
      (_DatePreset.thisMonth, 'Este mes'),
      (_DatePreset.thisYear, 'Este año'),
    ];
    final active = _activePreset;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((p) {
        final isSelected = active == p.$1;
        return GestureDetector(
          onTap: () => _applyPreset(p.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryBlue : backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? primaryBlue : borderLight),
            ),
            child: Text(
              p.$2,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : textDark,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateRangeRow() {
    return Row(
      children: [
        Expanded(
          child: _dateButton(label: 'Desde', date: _dateFrom, isFrom: true),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _dateButton(label: 'Hasta', date: _dateTo, isFrom: false),
        ),
      ],
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime? date,
    required bool isFrom,
  }) {
    final formatted = date == null
        ? 'Sin límite'
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';
    return GestureDetector(
      onTap: () => _pickDate(isFrom: isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: textMedium),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 13,
                  color: primaryBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountChips() {
    if (widget.accounts.isEmpty) {
      return const Text(
        'No hay cuentas disponibles',
        style: TextStyle(fontSize: 13, color: textMedium),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.accounts.map((account) {
        final isSelected = _accountIds.contains(account.id);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              isSelected
                  ? _accountIds.remove(account.id)
                  : _accountIds.add(account.id);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? account.color.withOpacity(0.12)
                  : backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? account.color : borderLight,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(account.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  account.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? account.color : textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryChips<T>({
    required List<(T, String, String)> options,
    required Set<T> selected,
    required ValueChanged<T> onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final (value, name, emoji) = option;
        final isSelected = selected.contains(value);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggle(value);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryBlue.withOpacity(0.1)
                  : backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? primaryBlue : borderLight,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? primaryBlue : textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.customCategories.map((category) {
        final isSelected = _customCategoryIds.contains(category.id);
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              isSelected
                  ? _customCategoryIds.remove(category.id)
                  : _customCategoryIds.add(category.id);
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryBlue.withOpacity(0.1)
                  : backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? primaryBlue : borderLight,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? primaryBlue : textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmountRange() {
    return Row(
      children: [
        Expanded(
          child: _amountField(controller: _minController, hint: 'Mínimo'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _amountField(controller: _maxController, hint: 'Máximo'),
        ),
      ],
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        prefixText: '${FormatUtils.currencySymbol} ',
        hintText: hint,
        filled: true,
        fillColor: backgroundLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
      ),
    );
  }
}
