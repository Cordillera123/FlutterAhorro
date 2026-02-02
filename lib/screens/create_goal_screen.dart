import 'package:ahorro_app/screens/goal_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/financial_goal.dart';
import '../services/goal_service.dart';
import '../utils/format_utils.dart';

class CreateGoalScreen extends StatefulWidget {
  final FinancialGoal? goalToEdit;
  final GoalType? preselectedType;

  const CreateGoalScreen({super.key, this.goalToEdit, this.preselectedType});

  @override
  State<CreateGoalScreen> createState() => _CreateGoalScreenState();
}

class _CreateGoalScreenState extends State<CreateGoalScreen> {
  // Controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _contributionController = TextEditingController();
  final _goalService = GoalService();

  // Estado simple y claro
  GoalType _selectedType = GoalType.purchase;
  GoalPriority _selectedPriority = GoalPriority.medium;
  String _selectedEmoji = '🎯';
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  bool _isLoading = false;
  bool _isEditMode = false;
  bool _contributionConfirmed = false;

  // Colores
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color purpleAccent = Color(0xFF7C3AED);
  static const Color infoBlue = Color(0xFF0EA5E9);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundCard = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Emojis por tipo
  final Map<GoalType, List<String>> _emojisByType = {
    GoalType.purchase: ['🛒', '💻', '📱', '🚗', '🏠', '👕', '⌚', '🎮'],
    GoalType.savings: ['💰', '🏦', '💎', '📈', '💸', '🪙', '💴', '💵'],
    GoalType.emergency: ['🚨', '🆘', '🛡️', '⛑️', '🔒', '🛟', '🔐', '⚠️'],
    GoalType.vacation: ['✈️', '🏝️', '🏖️', '🎒', '🌴', '🗺️', '📸', '🌅'],
    GoalType.education: ['📚', '🎓', '✏️', '🧠', '💡', '📖', '🔬', '💻'],
    GoalType.custom: ['🎯', '⭐', '🏆', '🎊', '🌟', '💫', '🔥', '✨'],
  };

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.goalToEdit != null;

    if (widget.preselectedType != null) {
      _selectedType = widget.preselectedType!;
      _selectedEmoji = _emojisByType[_selectedType]!.first;
    }

    _loadGoalData();
    _setupListeners();
  }

  void _setupListeners() {
    // Listener para calcular contribución sugerida cuando cambia el monto objetivo
    _targetAmountController.addListener(() {
      if (!_contributionConfirmed) {
        _updateSuggestedContribution();
      }
    });

    // Listener para detectar cuando el usuario empieza a editar la contribución
    _contributionController.addListener(() {
      if (!_contributionConfirmed) {
        setState(() {}); // Actualizar UI para mostrar validaciones
      }
    });
  }

  void _loadGoalData() {
    if (_isEditMode && widget.goalToEdit != null) {
      final goal = widget.goalToEdit!;
      _nameController.text = goal.name;
      _descriptionController.text = goal.description;
      _targetAmountController.text = _formatNumber(goal.targetAmount);
      _contributionController.text = _formatNumber(goal.monthlyContribution);
      _selectedType = goal.type;
      _selectedPriority = goal.priority;
      _selectedEmoji = goal.emoji;
      _targetDate = goal.targetDate;
      _contributionConfirmed = true; // En modo edición ya está confirmado
    } else {
      _nameController.text = _getDefaultName(_selectedType);
      _descriptionController.text = _getDefaultDescription(_selectedType);
    }
  }

  void _updateSuggestedContribution() {
    final targetAmount = _parseNumber(_targetAmountController.text);
    if (targetAmount <= 0) {
      if (_contributionController.text.isNotEmpty) {
        setState(() {
          _contributionController.text = '';
        });
      }
      return;
    }

    final now = DateTime.now();
    final months =
        ((_targetDate.year - now.year) * 12 + _targetDate.month - now.month)
            .clamp(1, 365);
    final suggested = targetAmount / months;

    // Solo actualizar si el campo está vacío o si el usuario no lo ha editado manualmente
    setState(() {
      _contributionController.text = _formatNumber(suggested);
    });
  }

  double _parseNumber(String text) {
    if (text.isEmpty) return 0.0;
    return double.tryParse(text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(2);
  }

  String? _getContributionError(double targetAmount, double contribution) {
    if (targetAmount <= 0) return 'Primero ingresa el monto objetivo';
    if (contribution <= 0) return 'Ingresa una contribución mayor a cero';
    if (contribution > targetAmount)
      return 'La contribución no puede exceder el monto objetivo';

    final now = DateTime.now();
    final totalMonths =
        ((_targetDate.year - now.year) * 12 + _targetDate.month - now.month)
            .clamp(1, 365);
    final monthsNeeded = (targetAmount / contribution).ceil();

    // Si se necesitan más del triple de meses de lo planeado
    if (monthsNeeded > totalMonths * 3) {
      return 'Con \$${_formatNumber(contribution)}/mes tardarás ${monthsNeeded} meses (muy largo)';
    }

    return null;
  }

  bool get _canConfirmContribution {
    final targetAmount = _parseNumber(_targetAmountController.text);
    final contribution = _parseNumber(_contributionController.text);
    return targetAmount > 0 &&
        contribution > 0 &&
        _getContributionError(targetAmount, contribution) == null;
  }

  bool get _canSubmit {
    return _nameController.text.isNotEmpty &&
        _contributionConfirmed &&
        !_isLoading;
  }

  void _resetContributionAndSelections() {
    setState(() {
      _contributionConfirmed = false;
      // Resetear a valores por defecto
      _selectedType = GoalType.purchase;
      _selectedPriority = GoalPriority.medium;
      _selectedEmoji = _emojisByType[GoalType.purchase]!.first;
      _targetDate = DateTime.now().add(const Duration(days: 365));
    });

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Puedes editar los montos nuevamente'),
        backgroundColor: primaryBlue,
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _getDefaultName(GoalType type) {
    switch (type) {
      case GoalType.purchase:
        return 'Mi nueva compra';
      case GoalType.savings:
        return 'Fondo de ahorro';
      case GoalType.emergency:
        return 'Fondo de emergencia';
      case GoalType.vacation:
        return 'Vacaciones soñadas';
      case GoalType.education:
        return 'Inversión en educación';
      case GoalType.custom:
        return 'Meta personalizada';
    }
  }

  String _getDefaultDescription(GoalType type) {
    switch (type) {
      case GoalType.purchase:
        return 'Ahorrando para comprar algo especial';
      case GoalType.savings:
        return 'Construyendo mi patrimonio personal';
      case GoalType.emergency:
        return 'Preparándome para imprevistos';
      case GoalType.vacation:
        return 'Mi próxima aventura inolvidable';
      case GoalType.education:
        return 'Invirtiendo en mi futuro profesional';
      case GoalType.custom:
        return 'Una meta importante para mí';
    }
  }

  String _getTypeName(GoalType type) {
    switch (type) {
      case GoalType.purchase:
        return 'Compra';
      case GoalType.savings:
        return 'Ahorro';
      case GoalType.emergency:
        return 'Emergencia';
      case GoalType.vacation:
        return 'Viaje';
      case GoalType.education:
        return 'Educación';
      case GoalType.custom:
        return 'Personalizada';
    }
  }

  String _getPriorityName(GoalPriority priority) {
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

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low:
        return successGreen;
      case GoalPriority.medium:
        return primaryBlue;
      case GoalPriority.high:
        return warningYellow;
      case GoalPriority.urgent:
        return dangerRed;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    _contributionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: Form(
        key: _formKey,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildBasicInfo(),
                    const SizedBox(height: 16),
                    _buildAmounts(),
                    if (_contributionConfirmed) ...[
                      const SizedBox(height: 16),
                      _buildTypeSelector(),
                      const SizedBox(height: 16),
                      _buildPrioritySelector(),
                      const SizedBox(height: 16),
                      _buildEmojiSelector(),
                      const SizedBox(height: 16),
                      _buildDatePicker(),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: backgroundLight,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: textDark),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _isEditMode ? 'Editar Meta' : 'Nueva Meta',
          style: const TextStyle(color: textDark, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Información Básica',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nombre de la meta',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ingresa un nombre';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Descripción',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmounts() {
    final targetAmount = _parseNumber(_targetAmountController.text);
    final contribution = _parseNumber(_contributionController.text);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _contributionConfirmed
              ? successGreen.withOpacity(0.3)
              : borderLight,
          width: _contributionConfirmed ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Montos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textDark,
                ),
              ),
              const Spacer(),
              if (_contributionConfirmed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: successGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: successGreen, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Confirmado',
                        style: TextStyle(
                          color: successGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // PASO 1: Monto Objetivo
          TextFormField(
            controller: _targetAmountController,
            enabled: !_contributionConfirmed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '1. Monto objetivo',
              prefixText: '\$ ',
              hintText: '0.00',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: _contributionConfirmed ? backgroundCard : Colors.white,
              suffixIcon: _contributionConfirmed
                  ? const Icon(Icons.lock, color: successGreen, size: 20)
                  : const Icon(
                      Icons.flag_outlined,
                      color: primaryBlue,
                      size: 20,
                    ),
            ),
            validator: (value) {
              final amount = _parseNumber(value ?? '');
              if (amount <= 0) {
                return 'Ingresa un monto mayor a cero';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // PASO 2: Contribución Mensual (con cálculo automático)
          TextFormField(
            controller: _contributionController,
            enabled: targetAmount > 0 && !_contributionConfirmed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '2. Contribución mensual',
              prefixText: '\$ ',
              hintText: targetAmount > 0
                  ? 'Editable'
                  : 'Calculada automáticamente',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: _contributionConfirmed
                  ? backgroundCard
                  : (targetAmount > 0 ? Colors.white : backgroundCard),
              helperText: _contributionConfirmed
                  ? null
                  : (targetAmount > 0
                        ? '✏️ Sugerencia: \$${_formatNumber(targetAmount / ((_targetDate.year - DateTime.now().year) * 12 + _targetDate.month - DateTime.now().month).clamp(1, 365))}/mes'
                        : null),
              helperMaxLines: 2,
              errorText: _contributionConfirmed
                  ? null
                  : _getContributionError(targetAmount, contribution),
              errorMaxLines: 2,
              suffixIcon: _contributionConfirmed
                  ? const Icon(Icons.lock, color: successGreen, size: 20)
                  : (targetAmount > 0
                        ? const Icon(
                            Icons.edit_outlined,
                            color: primaryBlue,
                            size: 20,
                          )
                        : const Icon(
                            Icons.calculate_outlined,
                            color: textMedium,
                            size: 20,
                          )),
            ),
          ),

          // Información del progreso estimado
          if (targetAmount > 0 &&
              contribution > 0 &&
              !_contributionConfirmed) ...[
            const SizedBox(height: 16),
            _buildContributionInfo(targetAmount, contribution),
          ],

          // Botón de confirmar/editar
          if (targetAmount > 0) ...[
            const SizedBox(height: 16),
            _buildConfirmButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    final canConfirm = _canConfirmContribution;

    if (_contributionConfirmed) {
      // Mostrar botón de editar cuando está confirmado
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _resetContributionAndSelections,
          icon: const Icon(Icons.edit_outlined),
          label: const Text(
            'Editar Montos',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: warningYellow,
            side: const BorderSide(color: warningYellow, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    // Mostrar botón de confirmar cuando no está confirmado
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: canConfirm
            ? () {
                setState(() {
                  _contributionConfirmed = true;
                });
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Contribución confirmada\nAhora configura el tipo, prioridad y fecha',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: successGreen,
                    duration: Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            : null,
        icon: Icon(
          canConfirm ? Icons.arrow_forward : Icons.block,
          color: Colors.white,
        ),
        label: const Text(
          'Confirmar y Continuar',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canConfirm ? primaryBlue : Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canConfirm ? 4 : 0,
        ),
      ),
    );
  }

  Widget _buildContributionInfo(double targetAmount, double contribution) {
    final now = DateTime.now();
    final totalMonths =
        ((_targetDate.year - now.year) * 12 + _targetDate.month - now.month)
            .clamp(1, 365);
    final monthsNeeded = (targetAmount / contribution).ceil();

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (monthsNeeded > totalMonths + 2) {
      statusColor = dangerRed;
      statusText =
          'Tardarás $monthsNeeded meses (${monthsNeeded - totalMonths} meses extra)';
      statusIcon = Icons.warning_amber_rounded;
    } else if (monthsNeeded > totalMonths) {
      statusColor = warningYellow;
      statusText =
          'Tardarás $monthsNeeded meses (+${monthsNeeded - totalMonths} extra)';
      statusIcon = Icons.info_outline_rounded;
    } else {
      statusColor = successGreen;
      statusText = '¡Perfecto! Alcanzarás tu meta en $monthsNeeded meses';
      statusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total a ahorrar: ${FormatUtils.formatMoney(targetAmount)}',
                  style: TextStyle(
                    color: statusColor.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tipo de Meta',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: GoalType.values.length,
            itemBuilder: (context, index) {
              final type = GoalType.values[index];
              final isSelected = _selectedType == type;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedType = type;
                    _selectedEmoji = _emojisByType[type]!.first;
                    if (_nameController.text ==
                            _getDefaultName(_selectedType) ||
                        _nameController.text.isEmpty) {
                      _nameController.text = _getDefaultName(type);
                    }
                    if (_descriptionController.text ==
                            _getDefaultDescription(_selectedType) ||
                        _descriptionController.text.isEmpty) {
                      _descriptionController.text = _getDefaultDescription(
                        type,
                      );
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryBlue.withOpacity(0.1)
                        : backgroundCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? primaryBlue : borderLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _emojisByType[type]!.first,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _getTypeName(type),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isSelected ? primaryBlue : textDark,
                          ),
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

  Widget _buildPrioritySelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prioridad',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GoalPriority.values.map((priority) {
              final isSelected = _selectedPriority == priority;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedPriority = priority;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _getPriorityColor(priority).withOpacity(0.2)
                        : backgroundCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? _getPriorityColor(priority)
                          : borderLight,
                    ),
                  ),
                  child: Text(
                    _getPriorityName(priority),
                    style: TextStyle(
                      color: isSelected
                          ? _getPriorityColor(priority)
                          : textDark,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emoji',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojisByType[_selectedType]!.map((emoji) {
              final isSelected = _selectedEmoji == emoji;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedEmoji = emoji;
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryBlue.withOpacity(0.2)
                        : backgroundCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? primaryBlue : borderLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    final now = DateTime.now();
    final monthsUntilTarget =
        ((_targetDate.year - now.year) * 12 + _targetDate.month - now.month)
            .clamp(1, 365);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fecha Objetivo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Define cuándo quieres alcanzar tu meta',
            style: TextStyle(fontSize: 13, color: textMedium),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate,
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: primaryBlue,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (picked != null && picked != _targetDate) {
                setState(() {
                  _targetDate = picked;
                  // Recalcular contribución sugerida con la nueva fecha
                  if (!_contributionConfirmed) {
                    _updateSuggestedContribution();
                  }
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: backgroundCard,
                border: Border.all(
                  color: primaryBlue.withOpacity(0.3),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FormatUtils.formatDateFull(_targetDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'En $monthsUntilTarget ${monthsUntilTarget == 1 ? 'mes' : 'meses'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: primaryBlue,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _canSubmit ? _saveGoal : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _canSubmit ? primaryBlue : Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: _canSubmit ? 8 : 0,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                _isEditMode ? 'Guardar Cambios' : 'Crear Meta',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final goal = FinancialGoal(
        id: _isEditMode ? widget.goalToEdit!.id : null,
        name: _nameController.text,
        description: _descriptionController.text,
        targetAmount: _parseNumber(_targetAmountController.text),
        currentAmount: _isEditMode ? widget.goalToEdit!.currentAmount : 0.0,
        startDate: _isEditMode ? widget.goalToEdit!.startDate : DateTime.now(),
        targetDate: _targetDate,
        type: _selectedType,
        priority: _selectedPriority,
        emoji: _selectedEmoji,
        monthlyContribution: _parseNumber(_contributionController.text),
        suggestedContribution: _parseNumber(_contributionController.text),
        autoSave: false,
        autoSaveFrequency: AutoSaveFrequency.monthly,
        createdAt: _isEditMode ? widget.goalToEdit!.createdAt : DateTime.now(),
      );

      if (_isEditMode) {
        await _goalService.updateGoal(goal);
      } else {
        await _goalService.addGoal(goal);
      }

      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                GoalSuccessScreen(goal: goal, isEdit: _isEditMode),
          ),
        );
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: dangerRed),
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
