import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recurring_expense.dart';
import '../models/transaction.dart';
import '../services/recurring_expense_service.dart';
import '../utils/format_utils.dart';

class AddRecurringExpenseScreen extends StatefulWidget {
  final RecurringExpense? expenseToEdit;
  final String? prefilledCategory;
  final String? prefilledIcon;
  final String? prefilledName;
  final double? prefilledAmount;
  final RecurrenceFrequency? prefilledFrequency;

  const AddRecurringExpenseScreen({
    super.key,
    this.expenseToEdit,
    this.prefilledCategory,
    this.prefilledIcon,
    this.prefilledName,
    this.prefilledAmount,
    this.prefilledFrequency,
  });

  @override
  State<AddRecurringExpenseScreen> createState() =>
      _AddRecurringExpenseScreenState();
}

class _AddRecurringExpenseScreenState extends State<AddRecurringExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _customDaysController = TextEditingController();
  final RecurringExpenseService _recurringExpenseService =
      RecurringExpenseService();

  ExpenseCategory _selectedCategory = ExpenseCategory.transport;
  RecurrenceFrequency _selectedFrequency = RecurrenceFrequency.daily;
  List<WeekDay> _selectedWeekDays = [];
  int _selectedMonthlyDay = 1;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;
  bool _isEditing = false;

  // Definición de colores consistentes
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color darkPurple = Color(0xFF5B21B6);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);

  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundCard = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _isEditing = widget.expenseToEdit != null;
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.expenseToEdit != null) {
      // Editando gasto existente
      final expense = widget.expenseToEdit!;
      _nameController.text = expense.name;
      _descriptionController.text = expense.description;
      _amountController.text = FormatUtils.formatMoney(expense.amount);
      _selectedCategory = expense.category;
      _selectedFrequency = expense.frequency;
      _selectedWeekDays = expense.weekDays ?? [];
      _selectedMonthlyDay = expense.monthlyDay ?? 1;
      _startDate = expense.startDate;
      _endDate = expense.endDate;
      if (expense.customDays != null) {
        _customDaysController.text = expense.customDays.toString();
      }
    } else {
      // Nuevo gasto con valores predefinidos
      if (widget.prefilledCategory != null) {
        // Mapear string a enum
        switch (widget.prefilledCategory) {
          case 'Transporte':
            _selectedCategory = ExpenseCategory.transport;
            _nameController.text = 'Transporte Diario';
            _descriptionController.text = 'Ida y vuelta en bus';
            _selectedFrequency = RecurrenceFrequency.weekly;
            _selectedWeekDays = [
              WeekDay.monday,
              WeekDay.tuesday,
              WeekDay.wednesday,
              WeekDay.thursday,
              WeekDay.friday,
            ];
            break;
          case 'Entretenimiento':
            _selectedCategory = ExpenseCategory.entertainment;
            _nameController.text = 'Suscripción Mensual';
            _descriptionController.text = 'Netflix, Spotify, etc.';
            _selectedFrequency = RecurrenceFrequency.monthly;
            _selectedMonthlyDay = DateTime.now().day;
            break;
          default:
            _selectedCategory = ExpenseCategory.other;
        }
      }

      if (widget.prefilledName != null) {
        _nameController.text = widget.prefilledName!;
      }
      if (widget.prefilledAmount != null) {
        _amountController.text = FormatUtils.formatMoney(
          widget.prefilledAmount!,
        );
      }
      if (widget.prefilledFrequency != null) {
        _selectedFrequency = widget.prefilledFrequency!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar Gasto Recurrente' : 'Nuevo Gasto Recurrente',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primaryPurple,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(),
              const SizedBox(height: 24),
              _buildCategorySection(),
              const SizedBox(height: 24),
              _buildFrequencySection(),
              const SizedBox(height: 24),
              _buildDateSection(),
              const SizedBox(height: 24),
              _buildPreviewSection(),
              const SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: primaryPurple),
              SizedBox(width: 8),
              Text(
                'Información Básica',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Nombre del gasto
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre del gasto',
              hintText: 'Ej: Transporte diario',
              prefixIcon: Icon(Icons.label_outline, color: primaryPurple),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa un nombre';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Descripción
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              hintText: 'Ej: Bus ida y vuelta al trabajo',
              prefixIcon: Icon(
                Icons.description_outlined,
                color: primaryPurple,
              ),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa una descripción';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Monto
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              LengthLimitingTextInputFormatter(10),
              _RecurringAmountInputFormatter(),
            ],
            decoration: const InputDecoration(
              labelText: 'Monto',
              hintText: '\$0.00',
              prefixIcon: Icon(Icons.attach_money, color: primaryPurple),
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa un monto';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'El monto debe ser mayor a \$0.00';
              }
              if (amount > 999999.99) {
                return 'El monto máximo es \$999,999.99';
              }
              if (amount < 0.01) {
                return 'El monto mínimo es \$0.01';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.category_outlined, color: primaryPurple),
              SizedBox(width: 8),
              Text(
                'Categoría',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCategoryGrid(),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    // ACTUALIZADO: Categorías filtradas para gastos recurrentes lógicos
    final categories = [
      // CATEGORÍAS PERFECTAS PARA GASTOS RECURRENTES
      {
        'category': ExpenseCategory.transport,
        'name': 'Transporte',
        'icon': '🚗',
      },
      {'category': ExpenseCategory.food, 'name': 'Alimentación', 'icon': '🍕'},
      {
        'category': ExpenseCategory.utilities,
        'name': 'Servicios Básicos',
        'icon': '💡',
      },
      {'category': ExpenseCategory.health, 'name': 'Salud', 'icon': '🏥'},
      {
        'category': ExpenseCategory.education,
        'name': 'Educación',
        'icon': '📚',
      },
      {'category': ExpenseCategory.home, 'name': 'Hogar', 'icon': '🏠'},

      // CATEGORÍAS CONDICIONALES (pueden ser recurrentes)
      {
        'category': ExpenseCategory.entertainment,
        'name': 'Entretenimiento',
        'icon': '🎬',
      },
      {
        'category': ExpenseCategory.technology,
        'name': 'Tecnología',
        'icon': '📱',
      },
      {'category': ExpenseCategory.savings, 'name': 'Ahorros', 'icon': '💰'},

      // CATEGORÍA GENERAL
      {'category': ExpenseCategory.other, 'name': 'Otros', 'icon': '📦'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio:
            2.0, // AJUSTADO: Reducido para mejor visualización con más categorías
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = _selectedCategory == category['category'];

        return GestureDetector(
          onTap: () => setState(() {
            _selectedCategory = category['category'] as ExpenseCategory;
          }),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryPurple.withOpacity(0.1)
                  : backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? primaryPurple : borderLight,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  category['icon'] as String,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    category['name'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? primaryPurple : textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrequencySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule, color: primaryPurple),
              SizedBox(width: 8),
              Text(
                'Frecuencia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildFrequencySelector(),
          const SizedBox(height: 16),
          _buildFrequencySpecificConfig(),
        ],
      ),
    );
  }

  Widget _buildFrequencySelector() {
    final frequencies = [
      {'frequency': RecurrenceFrequency.daily, 'name': 'Diario', 'icon': '📅'},
      {
        'frequency': RecurrenceFrequency.weekly,
        'name': 'Semanal',
        'icon': '📆',
      },
      {
        'frequency': RecurrenceFrequency.monthly,
        'name': 'Mensual',
        'icon': '🗓️',
      },
      {
        'frequency': RecurrenceFrequency.custom,
        'name': 'Personalizado',
        'icon': '⚙️',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: frequencies.length,
      itemBuilder: (context, index) {
        final frequency = frequencies[index];
        final isSelected = _selectedFrequency == frequency['frequency'];

        return GestureDetector(
          onTap: () => setState(() {
            _selectedFrequency = frequency['frequency'] as RecurrenceFrequency;
          }),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? infoBlue.withOpacity(0.1) : backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? infoBlue : borderLight,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  frequency['icon'] as String,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  frequency['name'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? infoBlue : textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrequencySpecificConfig() {
    switch (_selectedFrequency) {
      case RecurrenceFrequency.weekly:
        return _buildWeekDaySelector();
      case RecurrenceFrequency.monthly:
        return _buildMonthlyDaySelector();
      case RecurrenceFrequency.custom:
        return _buildCustomDaysInput();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWeekDaySelector() {
    final weekDays = [
      {'day': WeekDay.monday, 'name': 'L', 'fullName': 'Lunes'},
      {'day': WeekDay.tuesday, 'name': 'M', 'fullName': 'Martes'},
      {'day': WeekDay.wednesday, 'name': 'X', 'fullName': 'Miércoles'},
      {'day': WeekDay.thursday, 'name': 'J', 'fullName': 'Jueves'},
      {'day': WeekDay.friday, 'name': 'V', 'fullName': 'Viernes'},
      {'day': WeekDay.saturday, 'name': 'S', 'fullName': 'Sábado'},
      {'day': WeekDay.sunday, 'name': 'D', 'fullName': 'Domingo'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona los días de la semana:',
          style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: weekDays.map((dayInfo) {
            final day = dayInfo['day'] as WeekDay;
            final isSelected = _selectedWeekDays.contains(day);

            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedWeekDays.remove(day);
                  } else {
                    _selectedWeekDays.add(day);
                  }
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? primaryPurple : borderLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    dayInfo['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : textMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedWeekDays = [
                    WeekDay.monday,
                    WeekDay.tuesday,
                    WeekDay.wednesday,
                    WeekDay.thursday,
                    WeekDay.friday,
                  ];
                });
              },
              style: TextButton.styleFrom(foregroundColor: infoBlue),
              child: const Text('Días laborales'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedWeekDays = [WeekDay.saturday, WeekDay.sunday];
                });
              },
              style: TextButton.styleFrom(foregroundColor: infoBlue),
              child: const Text('Fin de semana'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthlyDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Día del mes:',
          style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: borderLight),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: _selectedMonthlyDay,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            items: List.generate(31, (index) {
              final day = index + 1;
              return DropdownMenuItem(value: day, child: Text('Día $day'));
            }),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedMonthlyDay = value;
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCustomDaysInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repetir cada cuántos días:',
          style: TextStyle(fontWeight: FontWeight.w600, color: textDark),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _customDaysController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            hintText: 'Ej: 3 (cada 3 días)',
            suffixText: 'días',
          ),
          validator: (value) {
            if (_selectedFrequency == RecurrenceFrequency.custom) {
              if (value == null || value.isEmpty) {
                return 'Ingresa el número de días';
              }
              final days = int.tryParse(value);
              if (days == null || days < 1) {
                return 'Debe ser un número mayor a 0';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.date_range, color: primaryPurple),
              SizedBox(width: 8),
              Text(
                'Período de Vigencia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fecha de inicio
          GestureDetector(
            onTap: () => _selectStartDate(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: borderLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: primaryPurple),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha de inicio',
                          style: TextStyle(fontSize: 12, color: textMedium),
                        ),
                        Text(
                          FormatUtils.formatDateFull(_startDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Fecha de fin (opcional)
          GestureDetector(
            onTap: () => _selectEndDate(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: borderLight),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy, color: warningYellow),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha de fin (opcional)',
                          style: TextStyle(fontSize: 12, color: textMedium),
                        ),
                        Text(
                          _endDate != null
                              ? FormatUtils.formatDateFull(_endDate!)
                              : 'Sin fecha límite',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _endDate != null ? Colors.black : textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_endDate != null)
                    IconButton(
                      onPressed: () => setState(() => _endDate = null),
                      icon: const Icon(Icons.clear, color: dangerRed),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    if (_nameController.text.isEmpty || _amountController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final amount = FormatUtils.parseAmount(_amountController.text);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.preview, color: primaryPurple),
              SizedBox(width: 8),
              Text(
                'Vista Previa',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tarjeta de vista previa
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryPurple.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryPurple.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryPurple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getCategoryIcon(),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nameController.text,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _descriptionController.text,
                        style: const TextStyle(color: textMedium, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFrequencyDescription(),
                        style: const TextStyle(
                          color: primaryPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  FormatUtils.formatMoney(amount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: dangerRed,
                  ),
                ),
              ],
            ),
          ),

          // Mostrar desglose de cálculos para gastos semanales
          if (_selectedFrequency == RecurrenceFrequency.weekly &&
              _selectedWeekDays.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: infoBlue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: infoBlue.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Desglose de cálculos:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: infoBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• Por día: ${FormatUtils.formatMoney(amount / _selectedWeekDays.length)}',
                    style: const TextStyle(fontSize: 11, color: textMedium),
                  ),
                  Text(
                    '• Por semana: ${FormatUtils.formatMoney(amount)}',
                    style: const TextStyle(fontSize: 11, color: textMedium),
                  ),
                  Text(
                    '• Estimado mensual: ${FormatUtils.formatMoney(amount * 4)}',
                    style: const TextStyle(fontSize: 11, color: textMedium),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveRecurringExpense,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isEditing
                    ? 'Actualizar Gasto Recurrente'
                    : 'Crear Gasto Recurrente',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // Métodos auxiliares
  String _getCategoryIcon() {
    switch (_selectedCategory) {
      case ExpenseCategory.transport:
        return '🚗';
      case ExpenseCategory.food:
        return '🍕';
      case ExpenseCategory.utilities:
        return '💡';
      case ExpenseCategory.health:
        return '🏥';
      case ExpenseCategory.education:
        return '📚';
      case ExpenseCategory.entertainment:
        return '🎬';
      case ExpenseCategory.clothing:
        return '👕';
      case ExpenseCategory.home:
        return '🏠';
      case ExpenseCategory.technology:
        return '📱';
      case ExpenseCategory.savings:
        return '💰';
      case ExpenseCategory.gifts:
        return '🎁';
      case ExpenseCategory.other:
        return '📦';
    }
  }

  String _getFrequencyDescription() {
    switch (_selectedFrequency) {
      case RecurrenceFrequency.daily:
        return 'Todos los días';
      case RecurrenceFrequency.weekly:
        if (_selectedWeekDays.isNotEmpty) {
          final dayNames = _selectedWeekDays
              .map((day) => _getWeekDayName(day))
              .join(', ');
          return 'Cada $dayNames';
        }
        return 'Semanal';
      case RecurrenceFrequency.monthly:
        return 'El día $_selectedMonthlyDay de cada mes';
      case RecurrenceFrequency.custom:
        final days = _customDaysController.text;
        return days.isNotEmpty ? 'Cada $days días' : 'Personalizado';
    }
  }

  String _getWeekDayName(WeekDay day) {
    switch (day) {
      case WeekDay.monday:
        return 'Lun';
      case WeekDay.tuesday:
        return 'Mar';
      case WeekDay.wednesday:
        return 'Mié';
      case WeekDay.thursday:
        return 'Jue';
      case WeekDay.friday:
        return 'Vie';
      case WeekDay.saturday:
        return 'Sáb';
      case WeekDay.sunday:
        return 'Dom';
    }
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: primaryPurple),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _startDate = date;
        // Si la fecha de fin es antes que la de inicio, limpiarla
        if (_endDate != null && _endDate!.isBefore(date)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 30)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: primaryPurple),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _endDate = date;
      });
    }
  }

  Future<void> _saveRecurringExpense() async {
    if (!_formKey.currentState!.validate()) return;

    // Validaciones específicas
    if (_selectedFrequency == RecurrenceFrequency.weekly &&
        _selectedWeekDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona al menos un día de la semana'),
          backgroundColor: dangerRed,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = FormatUtils.parseAmount(_amountController.text);

      final expense = RecurringExpense(
        id: _isEditing
            ? widget.expenseToEdit!.id
            : DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text,
        amount: amount,
        category: _selectedCategory,
        frequency: _selectedFrequency,
        customDays: _selectedFrequency == RecurrenceFrequency.custom
            ? int.tryParse(_customDaysController.text)
            : null,
        weekDays: _selectedFrequency == RecurrenceFrequency.weekly
            ? _selectedWeekDays
            : null,
        monthlyDay: _selectedFrequency == RecurrenceFrequency.monthly
            ? _selectedMonthlyDay
            : null,
        startDate: _startDate,
        endDate: _endDate,
        createdAt: _isEditing
            ? widget.expenseToEdit!.createdAt
            : DateTime.now(),
        lastProcessed: _isEditing ? widget.expenseToEdit!.lastProcessed : null,
      );

      if (_isEditing) {
        await _recurringExpenseService.updateRecurringExpense(expense);
      } else {
        await _recurringExpenseService.addRecurringExpense(expense);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Gasto recurrente actualizado correctamente'
                  : 'Gasto recurrente creado exitosamente',
            ),
            backgroundColor: successGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al guardar el gasto recurrente'),
            backgroundColor: dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class _RecurringAmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Si está vacío, permitir
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Validar que solo contenga números y un punto decimal
    if (!RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text)) {
      return oldValue;
    }

    // Convertir a double para validar rango
    final double? amount = double.tryParse(newValue.text);
    if (amount != null && amount > 999999.99) {
      return oldValue;
    }

    return newValue;
  }
}
