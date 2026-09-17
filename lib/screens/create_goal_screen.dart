import 'package:ahorro_app/screens/goal_success_screen.dart';
import 'package:flutter/material.dart';
import '../models/financial_goal.dart';
import '../services/account_service.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final GoalService _goalService = GoalService();
  final AccountService _accountService = AccountService();

  GoalType _selectedType = GoalType.purchase;
  GoalPriority _selectedPriority = GoalPriority.medium;
  String _selectedEmoji = '🎯';
  late DateTime _targetDate;
  bool _isLoading = false;
  bool _isEditMode = false;

  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color purpleAccent = Color(0xFF7C3AED);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundCard = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFE5E7EB);

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

    _targetDate = _minimumTargetDate;
    _loadGoalData();
    _targetAmountController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  DateTime get _minimumTargetDate => _addMonths(_today, 1);

  DateTime get _maximumTargetDate => _addYears(_today, 20);

  DateTime _addMonths(DateTime date, int months) {
    final totalMonths = date.year * 12 + (date.month - 1) + months;
    final year = totalMonths ~/ 12;
    final month = (totalMonths % 12) + 1;
    final lastDay = DateUtils.getDaysInMonth(year, month);
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }

  DateTime _addYears(DateTime date, int years) {
    final year = date.year + years;
    final lastDay = DateUtils.getDaysInMonth(year, date.month);
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, date.month, day);
  }

  DateTime _clampTargetDate(DateTime date) {
    final normalized = DateUtils.dateOnly(date);
    if (normalized.isBefore(_minimumTargetDate)) return _minimumTargetDate;
    if (normalized.isAfter(_maximumTargetDate)) return _maximumTargetDate;
    return normalized;
  }

  void _loadGoalData() {
    if (_isEditMode && widget.goalToEdit != null) {
      final goal = widget.goalToEdit!;
      _nameController.text = goal.name;
      _descriptionController.text = goal.description;
      _targetAmountController.text = _formatNumber(goal.targetAmount);
      _selectedType = goal.type;
      _selectedPriority = goal.priority;
      _selectedEmoji = goal.emoji;
      _targetDate = goal.targetDate;
    } else {
      _nameController.text = _getDefaultName(_selectedType);
      _descriptionController.text = _getDefaultDescription(_selectedType);
      _targetDate = _minimumTargetDate;
    }
  }

  double _parseNumber(String text) {
    if (text.isEmpty) return 0.0;
    return double.tryParse(text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(2);
  }

  GoalContributionSuggestion _buildSuggestion() {
    final targetAmount = _parseNumber(_targetAmountController.text);
    final currentAmount = _isEditMode && widget.goalToEdit != null
        ? widget.goalToEdit!.currentAmount
        : 0.0;

    return FinancialGoal.calculateSuggestedContribution(
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: _targetDate,
    );
  }

  String get _screenTitle => _isEditMode ? 'Editar meta' : 'Crear meta';

  String get _screenSubtitle => _isEditMode
      ? 'Ajusta tu meta en unos pocos pasos, sin complicarte.'
      : 'Define tu meta y recibe una guía simple para saber cuánto conviene ahorrar.';

  String get _dateHelpText =>
      'Elige una fecha entre 1 mes y 20 años desde hoy.';

  String get _amountHelpText =>
      'Escribe el total que quieres reunir. La guía se actualizará sola si cambias la fecha o haces aportes.';

  String get _nameHint => 'Ej. Viaje a Cartagena';

  String get _descriptionHint => 'Ej. Ahorrar para mis vacaciones';

  String get _amountHint => 'Ej. 1500000';

  String _goalStatusMessage(double targetAmount, double currentAmount) {
    if (targetAmount <= 0) {
      return 'Escribe un monto para ver tu guía automática.';
    }

    final remainingAmount = (targetAmount - currentAmount).clamp(0.0, double.infinity);
    if (remainingAmount <= 0) {
      return '¡Meta alcanzada! Ya reuniste lo necesario.';
    }

    final progress = (currentAmount / targetAmount).clamp(0.0, 1.0);
    if (progress >= 0.85) {
      return 'Ya casi lo logras. Te falta muy poco para completar tu meta.';
    }

    final elapsedDays = DateTime.now().difference(_isEditMode && widget.goalToEdit != null
            ? widget.goalToEdit!.startDate
            : DateTime.now())
        .inDays;
    final totalDays = _targetDate.difference(_isEditMode && widget.goalToEdit != null
            ? widget.goalToEdit!.startDate
            : DateTime.now())
        .inDays;

    if (currentAmount > 0 && totalDays > 0) {
      final expectedProgress = elapsedDays / totalDays;
      if (progress >= expectedProgress) {
        return 'Vas bien. Con tus aportes actuales, tu meta sigue dentro de lo planeado.';
      }
      return 'Todavía puedes llegar, pero necesitas aportar un poco más para cumplir a tiempo.';
    }

    return 'Esta guía te ayudará a empezar con claridad y sin presión.';
  }

  Color _goalStatusColor(double targetAmount, double currentAmount) {
    if (targetAmount <= 0 || currentAmount <= 0) {
      return primaryBlue;
    }

    final remainingAmount = (targetAmount - currentAmount).clamp(0.0, double.infinity);
    if (remainingAmount <= 0) return successGreen;

    final progress = (currentAmount / targetAmount).clamp(0.0, 1.0);
    if (progress >= 0.85) return successGreen;

    final elapsedDays = DateTime.now().difference(_isEditMode && widget.goalToEdit != null
            ? widget.goalToEdit!.startDate
            : DateTime.now())
        .inDays;
    final totalDays = _targetDate.difference(_isEditMode && widget.goalToEdit != null
            ? widget.goalToEdit!.startDate
            : DateTime.now())
        .inDays;
    if (currentAmount > 0 && totalDays > 0) {
      final expectedProgress = elapsedDays / totalDays;
      if (progress >= expectedProgress) {
        return successGreen;
      }
    }

    return warningYellow;
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

  bool get _canSubmit {
    return _nameController.text.trim().isNotEmpty &&
        _parseNumber(_targetAmountController.text) > 0 &&
        !_isLoading;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestion = _buildSuggestion();
    final targetAmount = _parseNumber(_targetAmountController.text);
    final currentAmount = _isEditMode && widget.goalToEdit != null
        ? widget.goalToEdit!.currentAmount
        : 0.0;

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
                    _buildTargetDateSection(),
                    const SizedBox(height: 16),
                    _buildTargetAmountSection(),
                    const SizedBox(height: 16),
                    _buildSuggestionCard(suggestion, targetAmount, currentAmount),
                    const SizedBox(height: 16),
                    _buildTypeSelector(),
                    const SizedBox(height: 16),
                    _buildPrioritySelector(),
                    const SizedBox(height: 16),
                    _buildEmojiSelector(),
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
      expandedHeight: 150,
      floating: false,
      pinned: true,
      backgroundColor: backgroundLight,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: textDark),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _screenTitle,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _screenSubtitle,
                  style: const TextStyle(
                    color: textMedium,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
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
              hintText: _nameHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Escribe un nombre para reconocer esta meta.';
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
              hintText: _descriptionHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetDateSection() {
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
            'Fecha objetivo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _dateHelpText,
            style: const TextStyle(fontSize: 13, color: textMedium),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _clampTargetDate(_targetDate),
                firstDate: _minimumTargetDate,
                lastDate: _maximumTargetDate,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(primary: primaryBlue),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null) {
                setState(() {
                  _targetDate = _clampTargetDate(picked);
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
                          _targetDate.difference(_today).inDays <= 365
                              ? 'Meta a corto plazo'
                              : 'Meta a largo plazo',
                          style: const TextStyle(
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

  Widget _buildTargetAmountSection() {
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
            'Monto objetivo',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _targetAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto total a alcanzar',
              hintText: _amountHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
              helperText: _amountHelpText,
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.savings_outlined, color: primaryBlue),
            ),
            validator: (value) {
              final amount = _parseNumber(value ?? '');
              if (amount <= 0) {
                return 'Escribe un monto mayor que 0.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(
    GoalContributionSuggestion suggestion,
    double targetAmount,
    double currentAmount,
  ) {
    final remainingAmount = (targetAmount - currentAmount).clamp(0.0, double.infinity);
    final progress = targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;
    final statusColor = _goalStatusColor(targetAmount, currentAmount);
    final statusMessage = _goalStatusMessage(targetAmount, currentAmount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryBlue.withOpacity(0.14),
            purpleAccent.withOpacity(0.12),
          ],
        ),
        border: Border.all(color: primaryBlue.withOpacity(0.18)),
      ),
      child: targetAmount <= 0 || suggestion.amount <= 0
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: primaryBlue,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Escribe un monto objetivo y te mostraremos una guía automática.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textDark,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_graph_rounded,
                        color: primaryBlue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Contribución sugerida',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  suggestion.cadence == GoalContributionCadence.weekly
                      ? 'Necesitas ahorrar aproximadamente'
                      : 'Necesitas ahorrar aproximadamente',
                  style: TextStyle(
                    fontSize: 13,
                    color: textDark.withOpacity(0.75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${FormatUtils.formatMoney(suggestion.amount)} por ${suggestion.cadenceLabel}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'durante ${suggestion.periodsRemaining} ${suggestion.cadenceLabelPlural}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.7),
                    valueColor: const AlwaysStoppedAnimation<Color>(primaryBlue),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Avance actual: ${FormatUtils.formatMoney(currentAmount)} de ${FormatUtils.formatMoney(targetAmount)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textDark.withOpacity(0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        remainingAmount <= 0
                            ? Icons.check_circle_outline_rounded
                            : progress >= 0.85
                                ? Icons.celebration_rounded
                                : statusColor == successGreen
                                    ? Icons.trending_up_rounded
                                    : Icons.arrow_upward_rounded,
                        size: 18,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusMessage,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Es solo una guía. No necesitas aportar exactamente esa cantidad.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: textDark.withOpacity(0.72),
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
                    if (_nameController.text == _getDefaultName(_selectedType) ||
                        _nameController.text.isEmpty) {
                      _nameController.text = _getDefaultName(type);
                    }
                    if (_descriptionController.text ==
                            _getDefaultDescription(_selectedType) ||
                        _descriptionController.text.isEmpty) {
                      _descriptionController.text = _getDefaultDescription(type);
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
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
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
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        targetAmount: _parseNumber(_targetAmountController.text),
        currentAmount: _isEditMode ? widget.goalToEdit!.currentAmount : 0.0,
        startDate: _isEditMode ? widget.goalToEdit!.startDate : DateTime.now(),
        targetDate: _targetDate,
        type: _selectedType,
        priority: _selectedPriority,
        emoji: _selectedEmoji,
        autoSaveAmount: _isEditMode ? widget.goalToEdit!.autoSaveAmount : 0.0,
        autoSave: _isEditMode ? widget.goalToEdit!.autoSave : false,
        autoSaveFrequency: _isEditMode
            ? widget.goalToEdit!.autoSaveFrequency
            : AutoSaveFrequency.monthly,
        createdAt: _isEditMode ? widget.goalToEdit!.createdAt : DateTime.now(),
        accountId: _accountService.resolveAccountId(
          widget.goalToEdit?.accountId,
        ),
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
            builder: (context) => GoalSuccessScreen(goal: goal, isEdit: _isEditMode),
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