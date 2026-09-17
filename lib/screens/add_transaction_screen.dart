import 'package:ahorro_app/screens/transaction_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../models/custom_category.dart';
import '../services/transaction_service.dart';
import '../services/category_service.dart';
import '../services/account_service.dart';
import '../utils/format_utils.dart';
import '../theme/app_colors.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionType initialType;
  final Transaction? transactionToEdit; // Nueva propiedad para edición

  const AddTransactionScreen({
    super.key,
    required this.initialType,
    this.transactionToEdit, // Parámetro opcional para editar
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final TransactionService _transactionService = TransactionService();
  final CategoryService _categoryService = CategoryService();
  final AccountService _accountService = AccountService();

  late TransactionType _selectedType;
  ExpenseCategory? _selectedExpenseCategory;
  IncomeCategory? _selectedIncomeCategory;
  // Soporte para categorías personalizadas
  String? _selectedCustomCategoryId;
  String? _selectedCustomCategoryName;
  String? _selectedCustomCategoryEmoji;
  
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  // Definición de colores consistentes
  static const Color primaryGreen = AppColors.primaryGreen;
  static const Color darkGreen = AppColors.darkGreen;
  static const Color deepGreen = AppColors.deepGreen;
  static const Color primaryRed = AppColors.dangerRed;
  static const Color darkRed = AppColors.darkRed;
  static const Color deepRed = AppColors.deepRed;
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color warningYellow = AppColors.warningYellow;
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
    _selectedType = widget.initialType;
    _initAnimations();
    _loadCategories();

    // Si estamos editando una transacción, pre-llenar los campos
    if (widget.transactionToEdit != null) {
      _loadTransactionData();
    } else {
      // Si es ingreso de salario, preconfigurar
      if (_selectedType == TransactionType.income) {
        _selectedIncomeCategory = IncomeCategory.salary;
        _descriptionController.text = 'Salario del mes';
      }
    }
  }

  Future<void> _loadCategories() async {
    await _categoryService.loadCategories();
    if (mounted) setState(() {});
  }

  void _loadTransactionData() {
    final transaction = widget.transactionToEdit!;
    _amountController.text = transaction.amount.toString();
    _descriptionController.text = transaction.description;
    _selectedDate = transaction.date;
    _selectedType = transaction.type;
    _selectedExpenseCategory = transaction.expenseCategory;
    _selectedIncomeCategory = transaction.incomeCategory;
    // Cargar categoría personalizada si existe
    _selectedCustomCategoryId = transaction.customCategoryId;
    _selectedCustomCategoryName = transaction.customCategoryName;
    _selectedCustomCategoryEmoji = transaction.customCategoryEmoji;
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

    _animationController.forward();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = _selectedType == TransactionType.income;
    final primaryColor = isIncome ? primaryGreen : primaryRed;
    final darkColor = isIncome ? darkGreen : darkRed;
    final deepColor = isIncome ? deepGreen : deepRed;

    return Scaffold(
      backgroundColor: backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(primaryColor, darkColor, deepColor),
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
                            _buildTypeSelector(),
                            const SizedBox(height: 24),
                            _buildAmountField(),
                            const SizedBox(height: 24),
                            _buildDescriptionField(),
                            const SizedBox(height: 24),
                            _buildCategorySelector(),
                            const SizedBox(height: 24),
                            _buildDateSelector(),
                            const SizedBox(height: 32),
                            _buildPreview(),
                            const SizedBox(height: 32),
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

  Widget _buildModernAppBar(
    Color primaryColor,
    Color darkColor,
    Color deepColor,
  ) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: backgroundLight,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, darkColor, deepColor],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
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
                              widget.transactionToEdit != null
                                  ? (_selectedType == TransactionType.income
                                        ? 'Editar Ingreso'
                                        : 'Editar Gasto')
                                  : (_selectedType == TransactionType.income
                                        ? 'Agregar Ingreso'
                                        : 'Agregar Gasto'),
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
                              widget.transactionToEdit != null
                                  ? 'Modifica los datos de tu transacción'
                                  : (_selectedType == TransactionType.income
                                        ? 'Registra tus ingresos fácilmente'
                                        : 'Mantén control de tus gastos'),
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
      width: 52, // MEJORADO: Ligeramente más grande
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18), // MEJORADO: Más redondeado
        color: Colors.white.withOpacity(0.25), // MEJORADO: Más opacidad
        border: Border.all(
          color: Colors.white.withOpacity(0.4), // MEJORADO: Borde más visible
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        _selectedType == TransactionType.income
            ? Icons.trending_up_rounded
            : Icons.trending_down_rounded,
        color: Colors.white,
        size: 26, // MEJORADO: Icono más grande
      ),
    );
  }

  Widget _buildTypeSelector() {
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
                  gradient: const LinearGradient(
                    colors: [primaryBlue, darkBlue],
                  ),
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
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
                      'Tipo de Transacción',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Selecciona si es ingreso o gasto',
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
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedType = TransactionType.income;
                      _selectedExpenseCategory = null;
                      _selectedIncomeCategory = IncomeCategory.salary;
                      // Limpiar categoría personalizada
                      _selectedCustomCategoryId = null;
                      _selectedCustomCategoryName = null;
                      _selectedCustomCategoryEmoji = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedType == TransactionType.income
                          ? primaryGreen.withOpacity(0.1)
                          : backgroundCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedType == TransactionType.income
                            ? primaryGreen
                            : borderLight,
                        width: _selectedType == TransactionType.income ? 2 : 1,
                      ),
                      boxShadow: _selectedType == TransactionType.income
                          ? [
                              BoxShadow(
                                color: primaryGreen.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          color: _selectedType == TransactionType.income
                              ? primaryGreen
                              : textMedium,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ingreso',
                          style: TextStyle(
                            color: _selectedType == TransactionType.income
                                ? primaryGreen
                                : textMedium,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedType = TransactionType.expense;
                      _selectedIncomeCategory = null;
                      _selectedExpenseCategory = ExpenseCategory.other;
                      // Limpiar categoría personalizada
                      _selectedCustomCategoryId = null;
                      _selectedCustomCategoryName = null;
                      _selectedCustomCategoryEmoji = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedType == TransactionType.expense
                          ? primaryRed.withOpacity(0.1)
                          : backgroundCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedType == TransactionType.expense
                            ? primaryRed
                            : borderLight,
                        width: _selectedType == TransactionType.expense ? 2 : 1,
                      ),
                      boxShadow: _selectedType == TransactionType.expense
                          ? [
                              BoxShadow(
                                color: primaryRed.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.trending_down_rounded,
                          color: _selectedType == TransactionType.expense
                              ? primaryRed
                              : textMedium,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Gasto',
                          style: TextStyle(
                            color: _selectedType == TransactionType.expense
                                ? primaryRed
                                : textMedium,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    final isIncome = _selectedType == TransactionType.income;
    final color = isIncome ? primaryGreen : primaryRed;

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
                  color: color.withOpacity(0.1),
                ),
                child: Icon(
                  isIncome
                      ? Icons.attach_money_rounded
                      : Icons.money_off_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monto',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Máximo: \$999.999.999,99',
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
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              LengthLimitingTextInputFormatter(
                13,
              ), // Máximo 13 caracteres (999999999.99)
              _AmountInputFormatter(),
            ],
            decoration: InputDecoration(
              hintText: '\$0.00',
              hintStyle: TextStyle(
                color: textMedium,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: color, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryRed),
              ),
              contentPadding: const EdgeInsets.all(20),
              filled: true,
              fillColor: backgroundCard,
            ),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Por favor ingresa un monto';
              }
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) {
                return 'El monto debe ser mayor a \$0.00';
              }
              if (amount > 999999999.99) {
                return 'El monto máximo es \$999.999.999,99';
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

  Widget _buildDescriptionField() {
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
                  Icons.description_rounded,
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
                      'Descripción',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Añade detalles sobre esta transacción',
                      style: TextStyle(color: textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: _selectedType == TransactionType.income
                  ? 'Ej: Salario de agosto, Freelance, etc.'
                  : 'Ej: Almuerzo, Transporte, etc.',
              hintStyle: TextStyle(color: textMedium, fontSize: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: infoBlue, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: primaryRed),
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
                return 'Por favor ingresa una descripción';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
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
                  Icons.category_rounded,
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
                      'Categoría',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Organiza tu transacción por tipo',
                      style: TextStyle(color: textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_selectedType == TransactionType.income)
            _buildIncomeCategoryGrid()
          else
            _buildExpenseCategoryGrid(),
        ],
      ),
    );
  }

  Widget _buildIncomeCategoryGrid() {
    final categories = [
      {'category': IncomeCategory.salary, 'name': 'Salario', 'icon': '💼'},
      {'category': IncomeCategory.freelance, 'name': 'Freelance', 'icon': '💻'},
      {'category': IncomeCategory.business, 'name': 'Negocio', 'icon': '🏪'},
      {'category': IncomeCategory.investment, 'name': 'Inversiones', 'icon': '📈'},
      {'category': IncomeCategory.rental, 'name': 'Alquiler', 'icon': '🏠'},
      {'category': IncomeCategory.bonus, 'name': 'Bonificación', 'icon': '🎯'},
      {'category': IncomeCategory.commission, 'name': 'Comisión', 'icon': '🤝'},
      {'category': IncomeCategory.refund, 'name': 'Reembolso', 'icon': '↩️'},
      {'category': IncomeCategory.gift, 'name': 'Regalo', 'icon': '🎁'},
      {'category': IncomeCategory.extra, 'name': 'Extra', 'icon': '⭐'},
      {'category': IncomeCategory.other, 'name': 'Otros', 'icon': '💰'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final isSelected = _selectedIncomeCategory == category['category'];

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _selectedIncomeCategory = category['category'] as IncomeCategory;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryGreen.withOpacity(0.1)
                  : backgroundCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primaryGreen : borderLight,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  category['icon'] as String,
                  style: TextStyle(
                    fontSize: isSelected ? 26 : 24,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  category['name'] as String,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11,
                    color: isSelected ? primaryGreen : textDark,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpenseCategoryGrid() {
    // Categorías del sistema
    final systemCategories = [
      {'category': ExpenseCategory.transport, 'name': 'Transporte', 'icon': '🚗', 'isSystem': true},
      {'category': ExpenseCategory.food, 'name': 'Alimentación', 'icon': '🍕', 'isSystem': true},
      {'category': ExpenseCategory.utilities, 'name': 'Servicios', 'icon': '💡', 'isSystem': true},
      {'category': ExpenseCategory.health, 'name': 'Salud', 'icon': '🏥', 'isSystem': true},
      {'category': ExpenseCategory.education, 'name': 'Educación', 'icon': '📚', 'isSystem': true},
      {'category': ExpenseCategory.entertainment, 'name': 'Diversión', 'icon': '🎬', 'isSystem': true},
      {'category': ExpenseCategory.clothing, 'name': 'Ropa', 'icon': '👕', 'isSystem': true},
      {'category': ExpenseCategory.home, 'name': 'Hogar', 'icon': '🏠', 'isSystem': true},
      {'category': ExpenseCategory.technology, 'name': 'Tecnología', 'icon': '📱', 'isSystem': true},
      {'category': ExpenseCategory.savings, 'name': 'Ahorros', 'icon': '💰', 'isSystem': true},
      {'category': ExpenseCategory.gifts, 'name': 'Regalos', 'icon': '🎁', 'isSystem': true},
      {'category': ExpenseCategory.other, 'name': 'Otros', 'icon': '📦', 'isSystem': true},
    ];

    // Agregar categorías personalizadas
    final customCategories = _categoryService.customCategories.map((c) => {
      'customId': c.id,
      'name': c.name,
      'icon': c.emoji,
      'isSystem': false,
    }).toList();

    // Combinar todas las categorías
    final allCategories = [...systemCategories, ...customCategories];

    // Agregar el botón "+" al final
    final totalItems = allCategories.length + 1; // +1 para el botón de agregar

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: totalItems,
      itemBuilder: (context, index) {
        // Si es el último item, mostrar botón de agregar
        if (index == allCategories.length) {
          return _buildAddCategoryButton();
        }

        final category = allCategories[index];
        final isSystem = category['isSystem'] as bool;
        
        bool isSelected;
        if (isSystem) {
          isSelected = _selectedCustomCategoryId == null && 
                       _selectedExpenseCategory == category['category'];
        } else {
          isSelected = _selectedCustomCategoryId == category['customId'];
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (isSystem) {
                _selectedExpenseCategory = category['category'] as ExpenseCategory;
                _selectedCustomCategoryId = null;
                _selectedCustomCategoryName = null;
                _selectedCustomCategoryEmoji = null;
              } else {
                _selectedCustomCategoryId = category['customId'] as String;
                _selectedCustomCategoryName = category['name'] as String;
                _selectedCustomCategoryEmoji = category['icon'] as String;
                _selectedExpenseCategory = null;
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? primaryRed.withOpacity(0.1) : backgroundCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? primaryRed : borderLight,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: primaryRed.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.05),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category['icon'] as String,
                  style: TextStyle(fontSize: isSelected ? 20 : 18),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    category['name'] as String,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 10,
                      color: isSelected ? primaryRed : textDark,
                      height: 1.1,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddCategoryButton() {
    return GestureDetector(
      onTap: () => _showQuickAddCategoryDialog(),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: primaryBlue.withOpacity(0.3),
            width: 1,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add,
                color: primaryBlue,
                size: 18,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Agregar',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: primaryBlue,
                height: 1.1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAddCategoryDialog() {
    final nameController = TextEditingController();
    String selectedEmoji = '📁';
    final formKey = GlobalKey<FormState>();
    bool isCreating = false;

    final emojis = [
      '🏋️', '🐕', '🐱', '💅', '🎮', '🎨', '🎵', '📷',
      '✈️', '🏖️', '☕', '🍺', '🛒', '💊', '📱', '💻',
      '🏠', '🚗', '🎓', '💼', '🎁', '💰', '📦', '⭐',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Título
                    const Text(
                      'Nueva categoría',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Crea una categoría personalizada para tus gastos',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Sección Emoji
                    const Text(
                      'Selecciona un emoji',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: emojis.length,
                      itemBuilder: (context, index) {
                        final emoji = emojis[index];
                        final isSelected = emoji == selectedEmoji;
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedEmoji = emoji;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryBlue.withOpacity(0.15)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? primaryBlue : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                emoji,
                                style: TextStyle(fontSize: isSelected ? 22 : 18),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Sección Nombre
                    const Text(
                      'Nombre de la categoría',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Ej: Mascotas, Gimnasio, Streaming...',
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: primaryBlue, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: primaryRed, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            selectedEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Ingresa un nombre para la categoría';
                        }
                        if (value.trim().length < 2) {
                          return 'El nombre es muy corto (mín. 2 caracteres)';
                        }
                        if (value.trim().length > 20) {
                          return 'El nombre es muy largo (máx. 20 caracteres)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),
                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isCreating
                                ? null
                                : () async {
                              if (formKey.currentState!.validate()) {
                                setModalState(() => isCreating = true);
                                try {
                                  final newCategory = await _categoryService.addCategory(
                                    name: nameController.text.trim(),
                                    emoji: selectedEmoji,
                                  );
                                  if (!mounted) return;
                                  Navigator.pop(context);
                                  // Seleccionar la nueva categoría
                                  setState(() {
                                    _selectedCustomCategoryId = newCategory.id;
                                    _selectedCustomCategoryName = newCategory.name;
                                    _selectedCustomCategoryEmoji = newCategory.emoji;
                                    _selectedExpenseCategory = null;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Text(newCategory.emoji, style: const TextStyle(fontSize: 18)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              '¡Categoría "${newCategory.name}" creada!',
                                              style: const TextStyle(fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFF059669),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                } catch (e) {
                                  setModalState(() => isCreating = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: primaryRed,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      margin: const EdgeInsets.all(16),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: isCreating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Crear categoría',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
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
                  Icons.calendar_today_rounded,
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
                      'Fecha',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Selecciona cuándo ocurrió',
                      style: TextStyle(color: textMedium, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _selectDate();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: backgroundCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderLight),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.event_rounded,
                      color: primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FormatUtils.formatDateFull(_selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          FormatUtils.formatDateForList(_selectedDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      color: primaryBlue,
                      size: 20,
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

  Widget _buildPreview() {
    if (_amountController.text.isEmpty) return const SizedBox.shrink();

    final amount = double.tryParse(_amountController.text) ?? 0;
    final description = _descriptionController.text;
    final isIncome = _selectedType == TransactionType.income;
    final color = isIncome ? primaryGreen : primaryRed;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2), width: 1),
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
                  color: color.withOpacity(0.1),
                ),
                child: Icon(Icons.preview_rounded, color: color, size: 20),
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
                      'Así se verá tu transacción',
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
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _getSelectedCategoryIcon(),
                      style: const TextStyle(
                        fontSize: 22,
                      ), // MEJORADO: Emoji más grande
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description.isEmpty ? 'Sin descripción' : description,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: textDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6), // MEJORADO: Más espacio
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getSelectedCategoryName(),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        FormatUtils.formatDateForList(_selectedDate),
                        style: const TextStyle(
                          color: textMedium,
                          fontSize: 13, // MEJORADO: Texto un poco más grande
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? '+' : '-'}${FormatUtils.formatMoney(amount)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isIncome
                            ? primaryGreen.withOpacity(0.1)
                            : primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isIncome ? 'Ingreso' : 'Gasto',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernFAB() {
    final isIncome = _selectedType == TransactionType.income;
    final color = isIncome ? primaryGreen : primaryRed;
    final darkColor = isIncome ? darkGreen : darkRed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      height: 64, // MEJORADO: Botón más alto
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(colors: [color, darkColor]),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4), // MEJORADO: Sombra más pronunciada
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: _isLoading
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  _saveTransaction();
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isIncome ? Icons.savings_rounded : Icons.payment_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isLoading
                        ? 'Guardando transacción...'
                        : isIncome
                        ? 'Agregar Ingreso'
                        : 'Agregar Gasto',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18, // MEJORADO: Texto más grande
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!_isLoading)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textDark,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  String _getSelectedCategoryIcon() {
    if (_selectedType == TransactionType.income) {
      switch (_selectedIncomeCategory) {
        case IncomeCategory.salary:
          return '💼';
        case IncomeCategory.freelance:
          return '💻';
        case IncomeCategory.business:
          return '🏪';
        case IncomeCategory.investment:
          return '📈';
        case IncomeCategory.rental:
          return '🏠';
        case IncomeCategory.bonus:
          return '🎯';
        case IncomeCategory.commission:
          return '🤝';
        case IncomeCategory.refund:
          return '↩️';
        case IncomeCategory.gift:
          return '🎁';
        case IncomeCategory.extra:
          return '⭐';
        case IncomeCategory.other:
          return '💰';
        default:
          return '💵';
      }
    } else {
      // Si hay categoría personalizada seleccionada, usar su emoji
      if (_selectedCustomCategoryId != null && _selectedCustomCategoryEmoji != null) {
        return _selectedCustomCategoryEmoji!;
      }
      switch (_selectedExpenseCategory) {
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
        default:
          return '💸';
      }
    }
  }

  String _getSelectedCategoryName() {
    if (_selectedType == TransactionType.income) {
      switch (_selectedIncomeCategory) {
        case IncomeCategory.salary:
          return 'Salario';
        case IncomeCategory.freelance:
          return 'Freelance';
        case IncomeCategory.business:
          return 'Negocio';
        case IncomeCategory.investment:
          return 'Inversiones';
        case IncomeCategory.rental:
          return 'Alquiler';
        case IncomeCategory.bonus:
          return 'Bonificación';
        case IncomeCategory.commission:
          return 'Comisión';
        case IncomeCategory.refund:
          return 'Reembolso';
        case IncomeCategory.gift:
          return 'Regalo';
        case IncomeCategory.extra:
          return 'Ingreso Extra';
        case IncomeCategory.other:
          return 'Otros Ingresos';
        default:
          return 'Ingreso';
      }
    } else {
      // Si hay categoría personalizada seleccionada, usar su nombre
      if (_selectedCustomCategoryId != null && _selectedCustomCategoryName != null) {
        return _selectedCustomCategoryName!;
      }
      switch (_selectedExpenseCategory) {
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
          return 'Otros Gastos';
        default:
          return 'Gasto';
      }
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedType == TransactionType.income &&
        _selectedIncomeCategory == null) {
      _showErrorMessage('Por favor selecciona una categoría de ingreso');
      return;
    }

    // Para gastos: debe tener categoría del sistema O categoría personalizada
    if (_selectedType == TransactionType.expense &&
        _selectedExpenseCategory == null &&
        _selectedCustomCategoryId == null) {
      _showErrorMessage('Por favor selecciona una categoría de gasto');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.tryParse(_amountController.text) ?? 0;

      if (amount <= 0) {
        _showErrorMessage('Por favor ingresa un monto válido');
        return;
      }

      final transaction = Transaction(
        id:
            widget.transactionToEdit?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        amount: amount,
        type: _selectedType,
        description: _descriptionController.text,
        date: _selectedDate,
        expenseCategory: _selectedExpenseCategory,
        incomeCategory: _selectedIncomeCategory,
        customCategoryId: _selectedCustomCategoryId,
        customCategoryName: _selectedCustomCategoryName,
        customCategoryEmoji: _selectedCustomCategoryEmoji,
        accountId: _accountService.resolveAccountId(
          widget.transactionToEdit?.accountId,
        ),
      );

      // Si estamos editando, actualizar; si no, agregar nueva transacción
      if (widget.transactionToEdit != null) {
        await _transactionService.updateTransaction(transaction);
      } else {
        await _transactionService.addTransaction(transaction);
      }

      if (mounted) {
        // Navegar a la pantalla de éxito en lugar de solo hacer pop
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionSuccessScreen(
              transaction: transaction,
              isEdit: widget.transactionToEdit != null, // Indicar si es edición
            ),
          ),
        );

        // La pantalla de éxito hará pop automáticamente con true
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage(
          'Error al ${widget.transactionToEdit != null ? 'actualizar' : 'guardar'} la transacción: ${e.toString()}',
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
                  color: primaryRed.withOpacity(0.1),
                  border: Border.all(
                    color: primaryRed.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.error_rounded,
                  color: primaryRed,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Error',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primaryRed,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
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
                    color: primaryRed,
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
  // Agregar esta clase al final de tu archivo AddTransactionScreen, antes del último }
}

class _AmountInputFormatter extends TextInputFormatter {
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
    if (amount != null && amount > 999999999.99) {
      return oldValue;
    }

    return newValue;
  }
}
