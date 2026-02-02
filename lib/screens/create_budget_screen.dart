import 'package:ahorro_app/screens/budget_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/budget_service.dart';
import '../services/category_service.dart';
import '../utils/format_utils.dart';

class CreateBudgetScreen extends StatefulWidget {
  final Budget? budgetToEdit;
  final BudgetPeriod? preselectedPeriod;

  const CreateBudgetScreen({
    super.key,
    this.budgetToEdit,
    this.preselectedPeriod,
  });

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen>
    with TickerProviderStateMixin {
  // Form controllers and services
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final BudgetService _budgetService = BudgetService();
  final CategoryService _categoryService = CategoryService();

  // State variables
  BudgetPeriod _selectedPeriod = BudgetPeriod.monthly;
  ExpenseCategory _selectedCategory = ExpenseCategory.food;
  // Soporte para categorías personalizadas
  String? _selectedCustomCategoryId;
  String? _selectedCustomCategoryName;
  String? _selectedCustomCategoryEmoji;
  
  bool _alertsEnabled = true;
  double _alertThreshold = 0.8;
  bool _isLoading = false;
  bool _isEditMode = false;

  // Animations
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  // Color constants
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);
  static const Color deepBlue = Color(0xFF1E40AF);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color infoBlue = Color(0xFF0EA5E9);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundCard = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.budgetToEdit != null;

    if (widget.preselectedPeriod != null) {
      _selectedPeriod = widget.preselectedPeriod!;
    }

    _initAnimations();
    _loadCategories();
    _loadBudgetData();
  }

  Future<void> _loadCategories() async {
    await _categoryService.loadCategories();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Initialization methods
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

    _animationController.forward();
  }

  void _loadBudgetData() {
    if (_isEditMode && widget.budgetToEdit != null) {
      final budget = widget.budgetToEdit!;
      _nameController.text = budget.name;
      _amountController.text = FormatUtils.formatMoney(budget.amount);
      _selectedPeriod = budget.period;
      _selectedCategory = budget.category;
      _alertsEnabled = budget.alertsEnabled;
      _alertThreshold = budget.alertThreshold;
      // Cargar categoría personalizada si existe
      _selectedCustomCategoryId = budget.customCategoryId;
      _selectedCustomCategoryName = budget.customCategoryName;
      _selectedCustomCategoryEmoji = budget.customCategoryEmoji;
    } else {
      // Configurar valores por defecto
      _nameController.text =
          'Presupuesto ${_getCategoryName(_selectedCategory)}';
      // CORREGIDO: No establecer monto por defecto
      _amountController.text = '';
    }
  }

  void _setDefaultAmount() {
    // CORREGIDO: Establecer en 0 por defecto
    _amountController.text = '';
  }

  // Build methods
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: CustomScrollView(
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
                    child: Form(
                      key: _formKey,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNameField(),
                            const SizedBox(height: 24),
                            _buildAmountField(),
                            const SizedBox(height: 24),
                            _buildPeriodSelector(),
                            const SizedBox(height: 24),
                            _buildCategorySelector(),
                            const SizedBox(height: 24),
                            _buildAlertsSettings(),
                            const SizedBox(height: 32),
                            _buildPreview(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _buildModernFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditMode
                                  ? 'Editar Presupuesto'
                                  : 'Crear Presupuesto',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Configura límites inteligentes para tus gastos',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildHeaderIcon(),
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

  Widget _buildHeaderIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.2),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
      ),
      child: Icon(
        _isEditMode ? Icons.edit_rounded : Icons.add_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildNameField() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: primaryBlue.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.label_rounded,
                  color: primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nombre del Presupuesto',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Dale un nombre descriptivo',
                      style: TextStyle(color: textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: 'Ej: Presupuesto de comida mensual',
              hintStyle: const TextStyle(color: textMedium, fontSize: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryBlue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: dangerRed),
              ),
              contentPadding: const EdgeInsets.all(20),
              filled: true,
              fillColor: backgroundCard,
            ),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textDark,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa un nombre';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: successGreen.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.attach_money_rounded,
                  color: successGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monto del Presupuesto',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Establece el límite de gasto',
                      style: TextStyle(color: textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              LengthLimitingTextInputFormatter(10),
              _BudgetAmountInputFormatter(),
            ],
            decoration: InputDecoration(
              hintText: '\$0.00',
              hintStyle: const TextStyle(
                color: textMedium,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: successGreen, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: dangerRed),
              ),
              contentPadding: const EdgeInsets.all(20),
              filled: true,
              fillColor: backgroundCard,
            ),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: successGreen,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa un monto';
              }
              // CORREGIDO: Usar FormatUtils.parseAmount para validar
              try {
                final amount = FormatUtils.parseAmount(value);
                if (amount <= 0) {
                  return 'El monto debe ser mayor a \$0.00';
                }
                if (amount > 999999.99) {
                  return 'El monto máximo es \$999,999.99';
                }
                if (amount < 0.01) {
                  return 'El monto mínimo es \$0.01';
                }
              } catch (e) {
                return 'Formato de monto inválido';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: warningYellow.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.schedule_rounded,
                  color: warningYellow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Período del Presupuesto',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Elige la duración del presupuesto',
                      style: TextStyle(color: textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildPeriodOption(
                  BudgetPeriod.weekly,
                  'Semanal',
                  Icons.date_range_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPeriodOption(
                  BudgetPeriod.monthly,
                  'Mensual',
                  Icons.calendar_month_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPeriodOption(
                  BudgetPeriod.yearly,
                  'Anual',
                  Icons.event_note_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodOption(BudgetPeriod period, String name, IconData icon) {
    final isSelected = _selectedPeriod == period;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedPeriod = period;
          _nameController.text =
              'Presupuesto ${_getCategoryName(_selectedCategory)} ${name.toLowerCase()}';
          // CORREGIDO: No establecer monto automáticamente
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? warningYellow.withOpacity(0.1) : backgroundCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? warningYellow : borderLight,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: warningYellow.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? warningYellow : textMedium,
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isSelected ? warningYellow : textDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    // Categorías del sistema
    final systemCategories = ExpenseCategory.values.map((c) => {
      'category': c,
      'name': _getCategoryName(c),
      'icon': _getCategoryIcon(c),
      'isSystem': true,
    }).toList();

    // Categorías personalizadas
    final customCategories = _categoryService.customCategories.map((c) => {
      'customId': c.id,
      'name': c.name,
      'icon': c.emoji,
      'isSystem': false,
    }).toList();

    // Combinar todas
    final allCategories = [...systemCategories, ...customCategories];

    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: infoBlue.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.category_rounded,
                  color: infoBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Categoría',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Selecciona el tipo de gasto',
                      style: TextStyle(color: textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.0,
            ),
            itemCount: allCategories.length,
            itemBuilder: (context, index) {
              final categoryData = allCategories[index];
              final isSystem = categoryData['isSystem'] as bool;
              
              bool isSelected;
              if (isSystem) {
                isSelected = _selectedCustomCategoryId == null && 
                             _selectedCategory == categoryData['category'];
              } else {
                isSelected = _selectedCustomCategoryId == categoryData['customId'];
              }

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isSystem) {
                      _selectedCategory = categoryData['category'] as ExpenseCategory;
                      _selectedCustomCategoryId = null;
                      _selectedCustomCategoryName = null;
                      _selectedCustomCategoryEmoji = null;
                      _nameController.text =
                          'Presupuesto ${_getCategoryName(_selectedCategory)} ${_getPeriodName(_selectedPeriod).toLowerCase()}';
                    } else {
                      _selectedCustomCategoryId = categoryData['customId'] as String;
                      _selectedCustomCategoryName = categoryData['name'] as String;
                      _selectedCustomCategoryEmoji = categoryData['icon'] as String;
                      _nameController.text =
                          'Presupuesto ${categoryData['name']} ${_getPeriodName(_selectedPeriod).toLowerCase()}';
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? infoBlue.withOpacity(0.1)
                        : backgroundCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? infoBlue : borderLight,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: infoBlue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        categoryData['icon'] as String,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          categoryData['name'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isSelected ? infoBlue : textDark,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSettings() {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: dangerRed.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: dangerRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alertas Inteligentes',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Configura cuándo recibir notificaciones',
                      style: TextStyle(color: textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Activar alertas',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch(
                value: _alertsEnabled,
                onChanged: (value) {
                  setState(() {
                    _alertsEnabled = value;
                  });
                },
                activeColor: successGreen,
              ),
            ],
          ),
          if (_alertsEnabled) ...[
            const SizedBox(height: 20),
            Text(
              'Alertar al ${(_alertThreshold * 100).toStringAsFixed(0)}% del presupuesto',
              style: const TextStyle(
                color: textDark,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: dangerRed,
                inactiveTrackColor: borderLight,
                thumbColor: dangerRed,
                overlayColor: dangerRed.withOpacity(0.2),
                trackHeight: 6,
              ),
              child: Slider(
                value: _alertThreshold,
                min: 0.5,
                max: 0.95,
                divisions: 9,
                onChanged: (value) {
                  setState(() {
                    _alertThreshold = value;
                  });
                },
              ),
            ),
            Text(
              'Recibirás una notificación cuando hayas gastado el ${(_alertThreshold * 100).toStringAsFixed(0)}% de tu presupuesto',
              style: const TextStyle(
                color: textMedium,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_amountController.text.isEmpty) return const SizedBox.shrink();

    final amount = FormatUtils.parseAmount(_amountController.text);
    final name = _nameController.text;

    return Container(
      padding: const EdgeInsets.all(24),
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
        border: Border.all(color: primaryBlue.withOpacity(0.2), width: 1),
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
                  color: primaryBlue.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.preview_rounded,
                  color: primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vista Previa',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Así se verá tu presupuesto',
                      style: TextStyle(color: textMedium, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryBlue.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          _getCategoryIcon(_selectedCategory),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isEmpty ? 'Sin nombre' : name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_getCategoryName(_selectedCategory)} • ${_getPeriodName(_selectedPeriod)}',
                            style: const TextStyle(
                              color: textMedium,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      FormatUtils.formatMoney(amount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primaryBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.0, // Sin progreso por ser nuevo
                    child: Container(
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _alertsEnabled
                      ? 'Alertas activadas al ${(_alertThreshold * 100).toStringAsFixed(0)}%'
                      : 'Sin alertas configuradas',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFAB() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [primaryBlue, darkBlue]),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: _isLoading
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  _saveBudget();
                },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              else
                Icon(
                  _isEditMode ? Icons.save_rounded : Icons.add_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              const SizedBox(width: 10),
              Text(
                _isLoading
                    ? 'Guardando...'
                    : _isEditMode
                    ? 'Guardar Cambios'
                    : 'Crear Presupuesto',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Utility methods
  String _getCategoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.transport:
        return 'Transporte';
      case ExpenseCategory.food:
        return 'Alimentación';
      case ExpenseCategory.utilities:
        return 'Servicios Básicos';
      case ExpenseCategory.health:
        return 'Salud';
      case ExpenseCategory.education:
        return 'Educación';
      case ExpenseCategory.entertainment:
        return 'Entretenimiento';
      case ExpenseCategory.clothing:
        return 'Ropa y Calzado';
      case ExpenseCategory.home:
        return 'Hogar y Muebles';
      case ExpenseCategory.technology:
        return 'Tecnología';
      case ExpenseCategory.savings:
        return 'Ahorros e Inversión';
      case ExpenseCategory.gifts:
        return 'Regalos y Donaciones';
      case ExpenseCategory.other:
        return 'Otros';
    }
  }

  String _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
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

  String _getPeriodName(BudgetPeriod period) {
    switch (period) {
      case BudgetPeriod.weekly:
        return 'Semanal';
      case BudgetPeriod.monthly:
        return 'Mensual';
      case BudgetPeriod.yearly:
        return 'Anual';
    }
  }

  // Action methods
  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // AGREGAR ESTA LÍNEA AL PRINCIPIO:
      await _budgetService.loadBudgets();

      // CORREGIDO: Usar FormatUtils.parseAmount en lugar de double.tryParse
      final amount = FormatUtils.parseAmount(_amountController.text);
      if (amount <= 0) {
        _showErrorMessage('Por favor ingresa un monto válido');
        return;
      }

      final dates = BudgetService.generateBudgetDates(
        _selectedPeriod,
        DateTime.now(),
      );

      final budget = Budget(
        id: _isEditMode ? widget.budgetToEdit!.id : null,
        name: _nameController.text,
        amount: amount,
        period: _selectedPeriod,
        category: _selectedCustomCategoryId != null ? ExpenseCategory.other : _selectedCategory,
        customCategoryId: _selectedCustomCategoryId,
        customCategoryName: _selectedCustomCategoryName,
        customCategoryEmoji: _selectedCustomCategoryEmoji,
        startDate: dates['start']!,
        endDate: dates['end']!,
        alertsEnabled: _alertsEnabled,
        alertThreshold: _alertThreshold,
        createdAt: _isEditMode
            ? widget.budgetToEdit!.createdAt
            : DateTime.now(),
      );

      if (_isEditMode) {
        await _budgetService.updateBudget(budget);
      } else {
        await _budgetService.addBudget(budget);
        _budgetService.debugPrintBudgets(); // Para verificar que se agregó
      }

      if (mounted) {
        // Navegar a la pantalla de éxito
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                BudgetSuccessScreen(budget: budget, isEdit: _isEditMode),
          ),
        );

        // La pantalla de éxito hará pop automáticamente con true
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessMessage() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: successGreen.withOpacity(0.1),
                  border: Border.all(
                    color: successGreen.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: successGreen,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isEditMode ? 'Presupuesto actualizado' : 'Presupuesto creado',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: successGreen,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _isEditMode
                    ? 'Los cambios han sido guardados exitosamente.'
                    : 'Tu presupuesto ha sido creado y está activo.',
                style: const TextStyle(
                  fontSize: 14,
                  color: textMedium,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: successGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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

  void _showErrorMessage(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: dangerRed.withOpacity(0.1),
                  border: Border.all(
                    color: dangerRed.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.error_rounded,
                  color: dangerRed,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Error',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: dangerRed,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message.contains('existe un presupuesto')
                    ? message
                    : 'No se pudo guardar el presupuesto. Inténtalo de nuevo.',
                style: const TextStyle(
                  fontSize: 14,
                  color: textMedium,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: dangerRed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
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
}

class _BudgetAmountInputFormatter extends TextInputFormatter {
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
