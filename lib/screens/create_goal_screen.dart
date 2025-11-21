import 'package:ahorro_app/screens/goal_success_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/financial_goal.dart';
import '../services/goal_service.dart';
import '../utils/format_utils.dart';

class CreateGoalScreen extends StatefulWidget {
  final FinancialGoal? goalToEdit;
  final GoalType? preselectedType;

  const CreateGoalScreen({
    super.key,
    this.goalToEdit,
    this.preselectedType,
  });

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
    if (targetAmount <= 0) return;

    final now = DateTime.now();
    final months = ((_targetDate.year - now.year) * 12 + _targetDate.month - now.month).clamp(1, 365);
    final suggested = targetAmount / months;

    if (_contributionController.text.isEmpty) {
      setState(() {
        _contributionController.text = _formatNumber(suggested);
      });
    }
  }

  double _parseNumber(String text) {
    if (text.isEmpty) return 0.0;
    return double.tryParse(text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(2);
  }

  String? _getContributionError(double targetAmount, double contribution) {
    if (targetAmount <= 0) return null;
    if (contribution <= 0) return 'Ingresa una contribución válida';
    if (contribution > targetAmount) return 'No puede exceder el monto objetivo';
    
    final now = DateTime.now();
    final totalMonths = ((_targetDate.year - now.year) * 12 + _targetDate.month - now.month).clamp(1, 365);
    final monthsNeeded = (targetAmount / contribution).ceil();
    
    if (monthsNeeded > totalMonths * 3) {
      return 'Con esa contribución tardarás demasiado tiempo';
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
      case GoalType.purchase: return 'Mi nueva compra';
      case GoalType.savings: return 'Fondo de ahorro';
      case GoalType.emergency: return 'Fondo de emergencia';
      case GoalType.vacation: return 'Vacaciones soñadas';
      case GoalType.education: return 'Inversión en educación';
      case GoalType.custom: return 'Meta personalizada';
    }
  }

  String _getDefaultDescription(GoalType type) {
    switch (type) {
      case GoalType.purchase: return 'Ahorrando para comprar algo especial';
      case GoalType.savings: return 'Construyendo mi patrimonio personal';
      case GoalType.emergency: return 'Preparándome para imprevistos';
      case GoalType.vacation: return 'Mi próxima aventura inolvidable';
      case GoalType.education: return 'Invirtiendo en mi futuro profesional';
      case GoalType.custom: return 'Una meta importante para mí';
    }
  }

  String _getTypeName(GoalType type) {
    switch (type) {
      case GoalType.purchase: return 'Compra';
      case GoalType.savings: return 'Ahorro';
      case GoalType.emergency: return 'Emergencia';
      case GoalType.vacation: return 'Viaje';
      case GoalType.education: return 'Educación';
      case GoalType.custom: return 'Personalizada';
    }
  }

  String _getPriorityName(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low: return 'Baja';
      case GoalPriority.medium: return 'Media';
      case GoalPriority.high: return 'Alta';
      case GoalPriority.urgent: return 'Urgente';
    }
  }

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low: return successGreen;
      case GoalPriority.medium: return primaryBlue;
      case GoalPriority.high: return warningYellow;
      case GoalPriority.urgent: return dangerRed;
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
          style: const TextStyle(
            color: textDark,
            fontWeight: FontWeight.bold,
          ),
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
              fontSize: 18,
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Montos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _targetAmountController,
            enabled: !_contributionConfirmed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto objetivo',
              prefixText: '\$ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              suffixIcon: _contributionConfirmed 
                  ? const Icon(Icons.lock, color: successGreen)
                  : null,
            ),
            validator: (value) {
              if (value == null || value.isEmpty || _parseNumber(value) <= 0) {
                return 'Ingresa un monto válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contributionController,
            enabled: targetAmount > 0 && !_contributionConfirmed,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              // Validación en tiempo real
              setState(() {});
            },
            decoration: InputDecoration(
              labelText: 'Contribución mensual',
              prefixText: '\$ ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: _contributionConfirmed
                  ? 'Montos confirmados y bloqueados'
                  : (targetAmount > 0 
                      ? 'Editable - ajusta según tu capacidad'
                      : 'Primero ingresa el monto objetivo'),
              errorText: _contributionConfirmed ? null : _getContributionError(targetAmount, contribution),
              suffixIcon: _contributionConfirmed 
                  ? const Icon(Icons.lock, color: successGreen)
                  : null,
            ),
            validator: (value) {
              final error = _getContributionError(targetAmount, _parseNumber(value ?? ''));
              return error;
            },
          ),
          if (targetAmount > 0 && contribution > 0) ...[
            const SizedBox(height: 12),
            _buildContributionInfo(targetAmount, contribution),
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
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _resetContributionAndSelections,
          icon: const Icon(
            Icons.edit,
            color: Colors.white,
          ),
          label: const Text(
            'Editar Montos',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: warningYellow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
        ),
      );
    }
    
    // Mostrar botón de confirmar cuando no está confirmado
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: canConfirm
            ? () {
                setState(() {
                  _contributionConfirmed = true;
                });
                HapticFeedback.mediumImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Contribución confirmada - Continúa configurando tu meta'),
                    backgroundColor: successGreen,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            : null,
        icon: const Icon(
          Icons.verified,
          color: Colors.white,
        ),
        label: const Text(
          'Confirmar Contribución Mensual',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canConfirm ? primaryBlue : Colors.grey,
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
    final totalMonths = ((_targetDate.year - now.year) * 12 + _targetDate.month - now.month).clamp(1, 365);
    final monthsNeeded = (targetAmount / contribution).ceil();
    
    Color statusColor;
    String statusText;
    
    if (monthsNeeded > totalMonths + 2) {
      statusColor = dangerRed;
      statusText = '❌ Tardarás $monthsNeeded meses (+${monthsNeeded - totalMonths} extra)';
    } else if (monthsNeeded > totalMonths) {
      statusColor = warningYellow;
      statusText = '⚠️ Tardarás $monthsNeeded meses (+${monthsNeeded - totalMonths} extra)';
    } else {
      statusColor = successGreen;
      statusText = '✓ Alcanzarás tu meta en $monthsNeeded meses';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
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
              fontSize: 18,
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
                    if (_nameController.text == _getDefaultName(_selectedType) || _nameController.text.isEmpty) {
                      _nameController.text = _getDefaultName(type);
                    }
                    if (_descriptionController.text == _getDefaultDescription(_selectedType) || _descriptionController.text.isEmpty) {
                      _descriptionController.text = _getDefaultDescription(type);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryBlue.withOpacity(0.1) : backgroundCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? primaryBlue : borderLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_emojisByType[type]!.first, style: const TextStyle(fontSize: 20)),
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
              fontSize: 18,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _getPriorityColor(priority).withOpacity(0.2) : backgroundCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? _getPriorityColor(priority) : borderLight,
                    ),
                  ),
                  child: Text(
                    _getPriorityName(priority),
                    style: TextStyle(
                      color: isSelected ? _getPriorityColor(priority) : textDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
              fontSize: 18,
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
                    color: isSelected ? primaryBlue.withOpacity(0.2) : backgroundCard,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _targetDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
              );
              if (picked != null) {
                setState(() {
                  _targetDate = picked;
                  _updateSuggestedContribution();
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: borderLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: primaryBlue),
                  const SizedBox(width: 12),
                  Text(
                    FormatUtils.formatDateFull(_targetDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
            builder: (context) => GoalSuccessScreen(
              goal: goal,
              isEdit: _isEditMode,
            ),
          ),
        );
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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
