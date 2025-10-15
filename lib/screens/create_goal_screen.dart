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

  class _CreateGoalScreenState extends State<CreateGoalScreen> with TickerProviderStateMixin {
    // Form controllers and services
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _descriptionController = TextEditingController();
    final _targetAmountController = TextEditingController();
    final _monthlyContributionController = TextEditingController();
    final GoalService _goalService = GoalService();

    // State variables
    GoalType _selectedType = GoalType.purchase;
    GoalPriority _selectedPriority = GoalPriority.medium;
    String _selectedEmoji = '🎯';
    DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
    bool _autoSave = false;
    AutoSaveFrequency _autoSaveFrequency = AutoSaveFrequency.monthly;
    bool _isLoading = false;
    bool _isEditMode = false;
    double _suggestedContribution = 0.0;
    bool _isContributionEditable = false;
    bool _userHasEditedContribution = false;

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

      _initAnimations();
      _loadGoalData();
      _setupListeners();
    }

    void _setupListeners() {
      _targetAmountController.addListener(() {
        if (!_userHasEditedContribution) {
          _calculateSuggestedContribution();
        }
      });

      // Listener para detectar cuando el usuario modifica manualmente la contribución
      _monthlyContributionController.addListener(() {
        if (_isContributionEditable && _monthlyContributionController.text.isNotEmpty) {
          _userHasEditedContribution = true;
        }
      });
    }

    // Función para actualizar cuando cambie el estado del ahorro automático
    void _onAutoSaveChanged(bool value) {
      setState(() {
        _autoSave = value;
        // Recalcular sugerencia si no ha sido editada manualmente
        if (!_userHasEditedContribution) {
          _calculateSuggestedContribution();
        }
      });
    }

    @override
    void dispose() {
      _nameController.dispose();
      _descriptionController.dispose();
      _targetAmountController.dispose();
      _monthlyContributionController.dispose();
      _animationController.dispose();
      super.dispose();
    }

    // Initialization methods
    void _initAnimations() {
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      );

      _fadeInAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ));

      _slideAnimation = Tween<double>(
        begin: 20.0,
        end: 0.0,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ));

      _animationController.forward();
    }

    void _loadGoalData() {
      if (_isEditMode && widget.goalToEdit != null) {
        final goal = widget.goalToEdit!;
        _nameController.text = goal.name;
        _descriptionController.text = goal.description;
        _targetAmountController.text = FormatUtils.formatMoney(goal.targetAmount);
        _monthlyContributionController.text = FormatUtils.formatMoney(goal.monthlyContribution);
        _selectedType = goal.type;
        _selectedPriority = goal.priority;
        _selectedEmoji = goal.emoji;
        _targetDate = goal.targetDate;
        _autoSave = goal.autoSave;
        _autoSaveFrequency = goal.autoSaveFrequency;
        _suggestedContribution = goal.suggestedContribution;

        // En modo edición, marcar como editado por el usuario
        _userHasEditedContribution = true;
        _isContributionEditable = false; // Empezar como solo lectura
      } else {
        // Configurar valores por defecto para nueva meta
        _nameController.text = _getDefaultName(_selectedType);
        _descriptionController.text = _getDefaultDescription(_selectedType);
        // Los campos de monto empiezan vacíos para mejor UX
        _targetAmountController.clear();
        _monthlyContributionController.clear();
        _suggestedContribution = 0.0;

        // Para nuevas metas, empezar en modo automático
        _userHasEditedContribution = false;
        _isContributionEditable = false;
      }
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

    void _setDefaultAmount() {
      // Los campos empiezan vacíos para mejor experiencia del usuario
      _targetAmountController.text = '';
      _monthlyContributionController.text = '';
      _suggestedContribution = 0.0;
    }



    void _calculateSuggestedContribution() {
      final targetAmount = _parseAmount(_targetAmountController.text);
      if (targetAmount <= 0) {
        _suggestedContribution = 0.0;
        // Solo limpiar el campo si el usuario no ha editado manualmente
        if (!_userHasEditedContribution && !_isContributionEditable) {
          _monthlyContributionController.text = '';
        }
        if (mounted) setState(() {});
        return;
      }

      final now = DateTime.now();
      final totalDays = _targetDate.difference(now).inDays;

      if (totalDays <= 0) {
        _suggestedContribution = targetAmount;
        if (!_userHasEditedContribution) {
          _updateSuggestedContributionField(targetAmount);
        }
        return;
      }

      double suggested = 0.0;
      switch (_autoSaveFrequency) {
        case AutoSaveFrequency.daily:
          suggested = targetAmount / totalDays;
          break;
        case AutoSaveFrequency.weekly:
          final totalWeeks = totalDays / 7;
          suggested = totalWeeks > 0 ? targetAmount / totalWeeks : targetAmount;
          break;
        case AutoSaveFrequency.monthly:
          final totalMonths = ((_targetDate.year - now.year) * 12 + _targetDate.month - now.month);
          suggested = totalMonths > 0 ? targetAmount / totalMonths : targetAmount;
          break;
      }

      _suggestedContribution = suggested;
      // Solo actualizar automáticamente si el usuario no ha editado manualmente
      if (!_userHasEditedContribution) {
        _updateSuggestedContributionField(suggested);
      } else {
        // Solo actualizar el estado para refrescar la UI
        if (mounted) setState(() {});
      }
    }

    void _updateSuggestedContributionField(double suggested) {
      // Solo actualizar automáticamente si NO está siendo editado por el usuario
      if (!_isContributionEditable && !_userHasEditedContribution) {
        _monthlyContributionController.text = suggested > 0 
            ? FormatUtils.formatMoney(suggested) 
            : '';
      }

      if (mounted) {
        setState(() {});
      }
    }

    double _parseAmount(String text) {
      if (text.isEmpty) return 0.0;
      String cleanText = text.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleanText) ?? 0.0;
    }


    void _resetToSuggestedContribution() {
      setState(() {
        _monthlyContributionController.text = FormatUtils.formatMoney(_suggestedContribution);
        _userHasEditedContribution = false;
      });
    }

    void _toggleContributionEditMode() {
      setState(() {
        _isContributionEditable = !_isContributionEditable;
        
        if (_isContributionEditable) {
          // Al activar edición, si el campo está vacío, usar la sugerencia
          if (_monthlyContributionController.text.isEmpty && _suggestedContribution > 0) {
            _monthlyContributionController.text = FormatUtils.formatMoney(_suggestedContribution);
          }
        } else {
          // Al desactivar edición, confirmar el valor editado
          if (_monthlyContributionController.text.isNotEmpty) {
            _userHasEditedContribution = true;
          }
        }
      });
    }

    String? _validateContribution(String? value) {
      // Si no está en modo editable, no validar (campo automático)
      if (!_isContributionEditable) return null;

      // Si el ahorro automático no está activado, la contribución es opcional
      if (!_autoSave) {
        // Validar solo si hay valor ingresado
        if (value != null && value.isNotEmpty) {
          final contribution = _parseAmount(value);
          if (contribution > 0) {
            final targetAmount = _parseAmount(_targetAmountController.text);
            if (targetAmount > 0 && contribution > targetAmount) {
              return 'No puede ser mayor al monto objetivo';
            }
            if (contribution > 999999.99) {
              return 'El monto máximo es \$999,999.99';
            }
          }
        }
        return null; // No es requerida si no hay ahorro automático
      }

      // Si el ahorro automático está activado, validar más estrictamente
      // Permitir campo vacío si hay sugerencia automática
      if ((value == null || value.isEmpty) && _suggestedContribution <= 0) {
        return 'La contribución es requerida para ahorro automático';
      }

      // Si hay valor, validarlo
      if (value != null && value.isNotEmpty) {
        final contribution = _parseAmount(value);
        final targetAmount = _parseAmount(_targetAmountController.text);

        if (contribution <= 0) {
          return 'La contribución debe ser mayor a \$0';
        }

        if (contribution < 1000) {
          return 'La contribución mínima es \$1,000';
        }

        if (targetAmount > 0 && contribution > targetAmount) {
          return 'No puede ser mayor al monto objetivo';
        }

        if (contribution > 999999.99) {
          return 'El monto máximo es \$999,999.99';
        }

        // Validación de tiempo razonable
        if (targetAmount > 0 && contribution > 0) {
          final now = DateTime.now();
          final totalMonths = ((_targetDate.year - now.year) * 12 + _targetDate.month - now.month);
          if (totalMonths > 0) {
            final monthsNeeded = (targetAmount / contribution).ceil();
            if (monthsNeeded > totalMonths * 2) {
              return 'Con esta contribución tomarás ${monthsNeeded} meses';
            }
          }
        }
      }

      return null;
    }

    Widget _buildContributionField() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo principal con estado condicional
          TextFormField(
            controller: _monthlyContributionController,
            enabled: _isContributionEditable,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              LengthLimitingTextInputFormatter(10),
              _GoalAmountInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: _isContributionEditable
                  ? (_autoSave ? 'Contribución automática (editando)' : 'Contribución sugerida (editando)')
                  : (_autoSave ? 'Contribución automática' : 'Contribución sugerida'),
              labelStyle: TextStyle(
                color: _isContributionEditable ? primaryBlue : textMedium,
                fontWeight: _isContributionEditable ? FontWeight.w600 : FontWeight.normal,
              ),
              hintText: _isContributionEditable ? 'Ingresa el monto' : 'Calculado automáticamente',
              hintStyle: TextStyle(
                color: _isContributionEditable ? textMedium : textMedium.withOpacity(0.7),
                fontStyle: _isContributionEditable ? FontStyle.normal : FontStyle.italic,
              ),
              suffixIcon: _buildContributionSuffixIcon(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _isContributionEditable ? primaryBlue : borderLight,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _isContributionEditable ? primaryBlue.withOpacity(0.5) : borderLight,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderLight.withOpacity(0.5)),
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
              fillColor: _isContributionEditable ? backgroundCard : backgroundLight.withOpacity(0.5),
            ),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _isContributionEditable ? textDark : textMedium,
            ),
            validator: _validateContribution,
          ),

          // Información contextual
          const SizedBox(height: 8),
          if (!_isContributionEditable) _buildSuggestionInfo(),
          if (_isContributionEditable) _buildEditingControls(),
        ],
      );
    }

    Widget _buildContributionSuffixIcon() {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isContributionEditable && _suggestedContribution > 0) ...[
            // Botón para resetear a sugerido
            IconButton(
              onPressed: _resetToSuggestedContribution,
              icon: const Icon(Icons.refresh_rounded),
              color: primaryBlue,
              tooltip: 'Usar sugerencia',
            ),
          ],
          // Botón para activar/desactivar edición
          Container(
            decoration: BoxDecoration(
              color: _isContributionEditable 
                  ? successGreen.withOpacity(0.1) 
                  : primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: _toggleContributionEditMode,
              icon: Icon(_isContributionEditable ? Icons.check_rounded : Icons.edit_rounded),
              color: _isContributionEditable ? successGreen : primaryBlue,
              tooltip: _isContributionEditable ? 'Confirmar edición' : 'Editar contribución',
            ),
          ),
        ],
      );
    }

    Widget _buildSuggestionInfo() {
      if (_suggestedContribution <= 0) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: infoBlue.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: infoBlue.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _autoSave ? Icons.savings_outlined : Icons.lightbulb_outline_rounded,
              color: infoBlue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Contribución calculada: ${FormatUtils.formatMoney(_suggestedContribution)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: infoBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _autoSave
                        ? 'Con ahorro automático activo, se descontará ${FormatUtils.formatMoney(_suggestedContribution)} ${_getFrequencyTextShort()}. Toca el lápiz para personalizar.'
                        : 'Contribución sugerida ${_getFrequencyTextShort()} para alcanzar tu meta a tiempo. Es solo una referencia.',
                    style: TextStyle(
                      fontSize: 11,
                      color: infoBlue.withOpacity(0.8),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildEditingControls() {
      final targetAmount = _parseAmount(_targetAmountController.text);
      final contribution = _parseAmount(_monthlyContributionController.text);

      if (targetAmount <= 0 || contribution <= 0) {
        return const SizedBox.shrink();
      }

      // Calcular tiempo estimado
      final now = DateTime.now();
      final totalMonths = ((_targetDate.year - now.year) * 12 + _targetDate.month - now.month);
      final monthsNeeded = (targetAmount / contribution).ceil();

      Color statusColor = successGreen;
      String statusText = 'Tiempo estimado: ${monthsNeeded} meses';

      if (monthsNeeded > totalMonths) {
        statusColor = warningYellow;
        statusText = 'Atención: Tomarás ${monthsNeeded} meses (${monthsNeeded - totalMonths} meses extra)';
      } else if (monthsNeeded < totalMonths * 0.5) {
        statusColor = infoBlue;
        statusText = 'Excelente: Alcanzarás tu meta en ${monthsNeeded} meses';
      }

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: statusColor.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              monthsNeeded > totalMonths ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
              color: statusColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
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
                              _buildBasicInfoSection(),
                              const SizedBox(height: 24),
                              _buildAmountSection(),
                              const SizedBox(height: 24),
                              _buildTypeSelector(),
                              const SizedBox(height: 24),
                              _buildPrioritySelector(),
                              const SizedBox(height: 24),
                              _buildEmojiSelector(),
                              const SizedBox(height: 24),
                              _buildDateSelector(),
                              const SizedBox(height: 24),
                              _buildAutoSaveSettings(),
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
                                _isEditMode ? 'Editar Meta' : 'Nueva Meta',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Define tus objetivos financieros',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 15,
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
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Icon(
          _isEditMode ? Icons.edit_rounded : Icons.flag_rounded,
          color: Colors.white,
          size: 24,
        ),
      );
    }

    Widget _buildBasicInfoSection() {
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
          border: Border.all(
            color: borderLight,
            width: 1,
          ),
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
                    Icons.info_rounded,
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
                        'Información Básica',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Nombre y descripción de tu meta',
                        style: TextStyle(
                          color: textMedium,
                          fontSize: 14,
                        ),
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
                labelText: 'Nombre de la meta',
                hintText: 'Ej: Nueva laptop',
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Descripción',
                hintText: 'Describe tu meta y por qué es importante para ti',
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
                contentPadding: const EdgeInsets.all(20),
                filled: true,
                fillColor: backgroundCard,
              ),
              style: const TextStyle(
                fontSize: 14,
                color: textDark,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildAmountSection() {
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
          border: Border.all(
            color: borderLight,
            width: 1,
          ),
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
                    Icons.monetization_on_rounded,
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
                        'Configuración Financiera',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Montos objetivo y contribución mensual',
                        style: TextStyle(
                          color: textMedium,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _targetAmountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                LengthLimitingTextInputFormatter(10),
                _GoalAmountInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Monto objetivo',
                hintText: '\$0.00',
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: successGreen,
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
            const SizedBox(height: 16),
            _buildContributionField(),
          ],
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
          border: Border.all(
            color: borderLight,
            width: 1,
          ),
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
                        'Tipo de Meta',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Selecciona la categoría que mejor describe tu meta',
                        style: TextStyle(
                          color: textMedium,
                          fontSize: 14,
                        ),
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
                childAspectRatio: 2.5,
              ),
              itemCount: GoalType.values.length,
              itemBuilder: (context, index) {
                final type = GoalType.values[index];
                final isSelected = _selectedType == type;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedType = type;
                      _selectedEmoji = _emojisByType[type]!.first;
                      _nameController.text = _getDefaultName(type);
                      _descriptionController.text = _getDefaultDescription(type);
                      _setDefaultAmount();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? infoBlue.withOpacity(0.1) : backgroundCard,
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

    Widget _buildPrioritySelector() {
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
          border: Border.all(
            color: borderLight,
            width: 1,
          ),
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
                    Icons.priority_high_rounded,
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
                        'Prioridad',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '¿Qué tan importante es esta meta para ti?',
                        style: TextStyle(
                          color: textMedium,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: GoalPriority.values.map((priority) {
                final isSelected = _selectedPriority == priority;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedPriority = priority;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(
                        right: priority != GoalPriority.values.last ? 8 : 0,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? _getPriorityColor(priority).withOpacity(0.1) : backgroundCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? _getPriorityColor(priority) : borderLight,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _getPriorityIcon(priority),
                            color: isSelected ? _getPriorityColor(priority) : textMedium,
                            size: 20,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _getPriorityName(priority),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: isSelected ? _getPriorityColor(priority) : textDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
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
          border: Border.all(
            color: borderLight,
            width: 1,
          ),
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
                    color: purpleAccent.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.emoji_emotions_rounded,
                    color: purpleAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emoji Representativo',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Elige un emoji que represente tu meta',
                        style: TextStyle(
                          color: textMedium,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojisByType[_selectedType]!.map((emoji) {
                final isSelected = _selectedEmoji == emoji;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedEmoji = emoji;
                    });
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSelected ? purpleAccent.withOpacity(0.1) : backgroundCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? purpleAccent : borderLight,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 20),
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
          border: Border.all(
            color: borderLight,
            width: 1,
          ),
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
                    Icons.calendar_today_rounded,
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
                        'Fecha Objetivo',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '¿Cuándo quieres alcanzar tu meta?',
                        style: TextStyle(
                          color: textMedium,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                final selectedDate = await showDatePicker(
                  context: context,
                  initialDate: _targetDate,
                  firstDate: DateTime.now(),
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

                if (selectedDate != null) {
                  setState(() {
                    _targetDate = selectedDate;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: backgroundCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_rounded,
                      color: dangerRed,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FormatUtils.formatDate(_targetDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_targetDate.difference(DateTime.now()).inDays} días restantes',
                            style: const TextStyle(
                              fontSize: 14,
                              color: textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: textMedium,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildAutoSaveSettings() {
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
          border: Border.all(
            color: borderLight,
            width: 1,
          ),
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
                    Icons.auto_awesome_rounded,
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
                        'Ahorro Automático',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Configura contribuciones automáticas',
                        style: TextStyle(
                          color: textMedium,
                          fontSize: 14,
                        ),
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
                    'Activar ahorro automático',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: _autoSave,
                  onChanged: _onAutoSaveChanged,
                  activeColor: successGreen,
                ),
              ],
            ),
            if (_autoSave) ...[
              const SizedBox(height: 20),
              const Text(
                'Frecuencia de ahorro',
                style: TextStyle(
                  color: textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFrequencyCard(
                      AutoSaveFrequency.daily,
                      'Diario',
                      Icons.today,
                      'Todos los días',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFrequencyCard(
                      AutoSaveFrequency.weekly,
                      'Semanal',
                      Icons.date_range,
                      'Cada semana',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFrequencyCard(
                      AutoSaveFrequency.monthly,
                      'Mensual',
                      Icons.calendar_month,
                      'Cada mes',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: successGreen.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contribución sugerida: ${FormatUtils.formatMoney(_suggestedContribution)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: successGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Se descontará automáticamente ${_getFrequencyText()} para alcanzar tu meta.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: successGreen,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget _buildFrequencyCard(AutoSaveFrequency frequency, String title, IconData icon, String subtitle) {
      final isSelected = _autoSaveFrequency == frequency;

      return GestureDetector(
        onTap: () {
          setState(() {
            _autoSaveFrequency = frequency;
            _calculateSuggestedContribution();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? primaryBlue.withOpacity(0.1) : backgroundCard,
            border: Border.all(
              color: isSelected ? primaryBlue : borderLight,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? primaryBlue : textMedium,
                size: 20,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? primaryBlue : textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: textMedium,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    String _getFrequencyText() {
      final amount = FormatUtils.formatMoney(FormatUtils.parseAmount(_monthlyContributionController.text));
      switch (_autoSaveFrequency) {
        case AutoSaveFrequency.daily:
          return '$amount diariamente';
        case AutoSaveFrequency.weekly:
          return '$amount semanalmente';
        case AutoSaveFrequency.monthly:
          return '$amount mensualmente';
      }
    }

    String _getFrequencyTextShort() {
      switch (_autoSaveFrequency) {
        case AutoSaveFrequency.daily:
          return 'por día';
        case AutoSaveFrequency.weekly:
          return 'por semana';
        case AutoSaveFrequency.monthly:
          return 'por mes';
      }
    }

    Widget _buildPreview() {
      if (_targetAmountController.text.isEmpty) return const SizedBox.shrink();

      final targetAmount = FormatUtils.parseAmount(_targetAmountController.text);
      final name = _nameController.text;

      // CORREGIR: Lógica mejorada para obtener la contribución
      double monthlyAmount = 0.0;
      
      if (_isContributionEditable && _monthlyContributionController.text.isNotEmpty) {
        // Si está en modo edición y tiene valor, usar ese valor
        monthlyAmount = FormatUtils.parseAmount(_monthlyContributionController.text);
      } else if (_userHasEditedContribution && _monthlyContributionController.text.isNotEmpty) {
        // Si el usuario ya editó anteriormente, usar ese valor
        monthlyAmount = FormatUtils.parseAmount(_monthlyContributionController.text);
      } else {
        // Usar la sugerencia automática
        monthlyAmount = _suggestedContribution;
      }

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
          border: Border.all(
            color: primaryBlue.withOpacity(0.2),
            width: 1,
          ),
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
                        'Así se verá tu meta',
                        style: TextStyle(
                          color: textMedium,
                          fontSize: 14,
                        ),
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
                border: Border.all(
                  color: primaryBlue.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _getPriorityColor(_selectedPriority).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(
                            _selectedEmoji,
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
                              '${_getTypeName(_selectedType)} • ${_getPriorityName(_selectedPriority)}',
                              style: TextStyle(
                                color: _getPriorityColor(_selectedPriority),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$0',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textMedium,
                            ),
                          ),
                          Text(
                            'de ${FormatUtils.formatMoney(targetAmount)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: textMedium,
                            ),
                          ),
                        ],
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
                      widthFactor: 0.0, // Sin progreso por ser nueva
                      child: Container(
                        decoration: BoxDecoration(
                          color: _getPriorityColor(_selectedPriority),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _autoSave && monthlyAmount > 0
                        ? 'Ahorro automático: ${FormatUtils.formatMoney(monthlyAmount)}/${_getFrequencyTextShort()}'
                        : monthlyAmount > 0
                            ? 'Contribución sugerida: ${FormatUtils.formatMoney(monthlyAmount)}/${_getFrequencyTextShort()}'
                            : 'Sin contribución configurada',
                    style: TextStyle(
                      fontSize: 12,
                      color: _autoSave && monthlyAmount > 0
                          ? successGreen
                          : monthlyAmount > 0
                              ? infoBlue
                              : Colors.grey[600],
                      fontWeight: monthlyAmount > 0 ? FontWeight.w600 : FontWeight.normal,
                      fontStyle: monthlyAmount > 0 ? FontStyle.normal : FontStyle.italic,
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
          gradient: const LinearGradient(
            colors: [primaryBlue, darkBlue],
          ),
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
            onTap: _isLoading ? null : () {
              HapticFeedback.mediumImpact();
              _saveGoal();
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
                    _isEditMode ? Icons.save_rounded : Icons.flag_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                const SizedBox(width: 10),
                Text(
                  _isLoading
                      ? 'Guardando...'
                      : _isEditMode
                      ? 'Guardar Cambios'
                      : 'Crear Meta',
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

    IconData _getPriorityIcon(GoalPriority priority) {
      switch (priority) {
        case GoalPriority.low:
          return Icons.trending_down_rounded;
        case GoalPriority.medium:
          return Icons.trending_flat_rounded;
        case GoalPriority.high:
          return Icons.trending_up_rounded;
        case GoalPriority.urgent:
          return Icons.priority_high_rounded;
      }
    }

    // Action methods
    Future<void> _saveGoal() async {
      if (!_formKey.currentState!.validate()) return;

      setState(() {
        _isLoading = true;
      });

      try {
        final targetAmount = _parseAmount(_targetAmountController.text);

        if (targetAmount <= 0) {
          _showErrorMessage('Por favor ingresa un monto objetivo válido');
          return;
        }

        // MEJORAR: Lógica de determinación de contribución mensual
        double monthlyContribution = 0.0;

        if (_autoSave) {
          // Para ahorro automático, la contribución es requerida
          if (_isContributionEditable && _monthlyContributionController.text.isNotEmpty) {
            monthlyContribution = _parseAmount(_monthlyContributionController.text);
          } else if (_userHasEditedContribution && _monthlyContributionController.text.isNotEmpty) {
            monthlyContribution = _parseAmount(_monthlyContributionController.text);
          } else if (_suggestedContribution > 0) {
            monthlyContribution = _suggestedContribution;
          } else {
            _showErrorMessage('No se pudo calcular la contribución automática. Verifica el monto objetivo y la fecha.');
            return;
          }

          // Validaciones para ahorro automático
          if (monthlyContribution <= 0) {
            _showErrorMessage('La contribución es requerida para el ahorro automático');
            return;
          }

          if (monthlyContribution < 1000) {
            _showErrorMessage('La contribución mínima es de \$1,000');
            return;
          }
        } else {
          // Sin ahorro automático, usar valor editado o sugerencia
          if (_isContributionEditable && _monthlyContributionController.text.isNotEmpty) {
            monthlyContribution = _parseAmount(_monthlyContributionController.text);
          } else if (_userHasEditedContribution && _monthlyContributionController.text.isNotEmpty) {
            monthlyContribution = _parseAmount(_monthlyContributionController.text);
          } else {
            monthlyContribution = _suggestedContribution;
          }
        }

        // Validación común: contribución no puede exceder monto objetivo
        if (monthlyContribution > targetAmount) {
          _showErrorMessage('La contribución mensual no puede ser mayor al monto objetivo');
          return;
        }

        final goal = FinancialGoal(
          id: _isEditMode ? widget.goalToEdit!.id : null,
          name: _nameController.text,
          description: _descriptionController.text,
          targetAmount: targetAmount,
          currentAmount: _isEditMode ? widget.goalToEdit!.currentAmount : 0.0,
          startDate: _isEditMode ? widget.goalToEdit!.startDate : DateTime.now(),
          targetDate: _targetDate,
          type: _selectedType,
          priority: _selectedPriority,
          emoji: _selectedEmoji,
          monthlyContribution: monthlyContribution,
          suggestedContribution: _suggestedContribution,
          autoSave: _autoSave,
          autoSaveFrequency: _autoSaveFrequency,
          createdAt: _isEditMode ? widget.goalToEdit!.createdAt : DateTime.now(),
        );

        if (_isEditMode) {
          await _goalService.updateGoal(goal);
        } else {
          await _goalService.addGoal(goal);
        }

        if (mounted) {
          // Navegar a la pantalla de éxito
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalSuccessScreen(
                goal: goal,
                isEdit: _isEditMode,
              ),
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
                  _isEditMode ? 'Meta actualizada' : 'Meta creada',
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
                      : '¡Tu nueva meta está lista! Comienza a ahorrar para alcanzarla.',
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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
                  'No se pudo guardar la meta. Inténtalo de nuevo.',
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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
  class _GoalAmountInputFormatter extends TextInputFormatter {
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
