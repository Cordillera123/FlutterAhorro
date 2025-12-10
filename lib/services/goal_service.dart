import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/financial_goal.dart';
import '../models/transaction.dart';
import 'transaction_service.dart';

class GoalService {
  static const String _goalsKey = 'financial_goals';
  static const String _contributionsKey = 'goal_contributions';

  List<FinancialGoal> _goals = [];
  List<GoalContribution> _contributions = [];
  final TransactionService _transactionService = TransactionService();

  List<FinancialGoal> get goals => _goals;
  List<FinancialGoal> get activeGoals => _goals.where((g) => g.status == GoalStatus.active).toList();
  List<FinancialGoal> get pausedGoals => _goals.where((g) => g.status == GoalStatus.paused).toList();
  List<FinancialGoal> get completedGoals => _goals.where((g) => g.status == GoalStatus.completed).toList();
  List<GoalContribution> get contributions => _contributions;
  
  // Validar si se pueden crear más metas
  bool get canCreateMoreGoals => _goals.length < 15;

  // Cargar metas desde almacenamiento local
  Future<void> loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cargar metas
      final goalsJson = prefs.getString(_goalsKey);
      if (goalsJson != null) {
        final List<dynamic> goalsList = json.decode(goalsJson);
        _goals = goalsList.map((json) => FinancialGoal.fromJson(json)).toList();

        // Ordenar por prioridad y fecha de creación
        _goals.sort((a, b) {
          // Primero por status (activas primero)
          if (a.status != b.status) {
            if (a.status == GoalStatus.active) return -1;
            if (b.status == GoalStatus.active) return 1;
          }
          // Luego por prioridad
          if (a.priority != b.priority) {
            return b.priority.index.compareTo(a.priority.index);
          }
          // Finalmente por fecha de creación
          return b.createdAt.compareTo(a.createdAt);
        });
      }

      // Cargar contribuciones
      final contributionsJson = prefs.getString(_contributionsKey);
      if (contributionsJson != null) {
        final List<dynamic> contributionsList = json.decode(contributionsJson);
        _contributions = contributionsList.map((json) => GoalContribution.fromJson(json)).toList();

        // Ordenar por fecha (más recientes primero)
        _contributions.sort((a, b) => b.date.compareTo(a.date));
      }

      // Actualizar el currentAmount de cada meta basado en las contribuciones
      _updateGoalAmounts();

    } catch (e) {
      print('Error loading goals: $e');
      _goals = [];
      _contributions = [];
    }
  }

  // Actualizar montos actuales de las metas basado en contribuciones
  void _updateGoalAmounts() {
    for (var goal in _goals) {
      if (goal.id != null) {
        final goalContributions = _contributions.where((c) => c.goalId == goal.id).toList();
        final totalContributed = goalContributions.fold(0.0, (sum, c) => sum + c.amount);

        // Actualizar el monto actual
        final index = _goals.indexWhere((g) => g.id == goal.id);
        if (index != -1) {
          _goals[index] = goal.copyWith(currentAmount: totalContributed);

          // Si la meta se completó, actualizar status
          if (totalContributed >= goal.targetAmount && goal.status != GoalStatus.completed) {
            _goals[index] = _goals[index].copyWith(
              status: GoalStatus.completed,
              completedAt: DateTime.now(),
            );
          }
        }
      }
    }
  }

  // Guardar metas en almacenamiento local
  Future<void> _saveGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = json.encode(_goals.map((g) => g.toJson()).toList());
      await prefs.setString(_goalsKey, goalsJson);
    } catch (e) {
      print('Error saving goals: $e');
      throw Exception('No se pudo guardar la meta');
    }
  }

  // Guardar contribuciones en almacenamiento local
  Future<void> _saveContributions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contributionsJson = json.encode(_contributions.map((c) => c.toJson()).toList());
      await prefs.setString(_contributionsKey, contributionsJson);
    } catch (e) {
      print('Error saving contributions: $e');
      throw Exception('No se pudo guardar la contribución');
    }
  }

  // Agregar nueva meta
  Future<void> addGoal(FinancialGoal goal) async {
    // Validar límite máximo de metas
    if (_goals.length >= 15) {
      throw Exception('Has alcanzado el límite máximo de 15 metas. Elimina o completa algunas metas para crear nuevas.');
    }

    // Calcular contribución sugerida automáticamente
    final suggestedContribution = goal.calculateSuggestedContribution();
    
    final newGoal = goal.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      suggestedContribution: suggestedContribution,
      monthlyContribution: goal.monthlyContribution > 0 ? goal.monthlyContribution : suggestedContribution,
    );

    _goals.add(newGoal);
    await _saveGoals();
  }

  // Actualizar meta existente
  Future<void> updateGoal(FinancialGoal goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index == -1) {
      throw Exception('Meta no encontrada');
    }

    _goals[index] = goal.copyWith(updatedAt: DateTime.now());
    await _saveGoals();
  }

  // Eliminar meta
  Future<void> deleteGoal(String goalId) async {
    final initialLength = _goals.length;
    _goals.removeWhere((g) => g.id == goalId);

    if (_goals.length == initialLength) {
      throw Exception('Meta no encontrada');
    }

    // También eliminar todas las contribuciones de esta meta
    _contributions.removeWhere((c) => c.goalId == goalId);

    await _saveGoals();
    await _saveContributions();
  }

  // Cambiar estado de una meta (pausar/activar/cancelar)
  Future<void> changeGoalStatus(String goalId, GoalStatus newStatus) async {
    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) {
      throw Exception('Meta no encontrada');
    }

    DateTime? completedAt;
    if (newStatus == GoalStatus.completed) {
      completedAt = DateTime.now();
    }

    _goals[index] = _goals[index].copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
      completedAt: completedAt,
    );

    await _saveGoals();
  }

  // Pausar meta específicamente
  Future<void> pauseGoal(String goalId) async {
    await changeGoalStatus(goalId, GoalStatus.paused);
  }

  // Reactivar meta pausada
  Future<void> resumeGoal(String goalId) async {
    await changeGoalStatus(goalId, GoalStatus.active);
  }

  // Validar contribución
  bool validateContribution(String goalId, double contribution) {
    final goal = getGoalById(goalId);
    if (goal == null) return false;
    return goal.isContributionValid(contribution);
  }

  // Agregar contribución a una meta
  Future<void> addContribution(String goalId, double amount, {String? note, bool isAutomatic = false}) async {
    final goal = getGoalById(goalId);
    if (goal == null) {
      throw Exception('Meta no encontrada');
    }

    if (amount <= 0) {
      throw Exception('El monto debe ser mayor a cero');
    }

    final contribution = GoalContribution(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      goalId: goalId,
      amount: amount,
      date: DateTime.now(),
      note: note,
      isAutomatic: isAutomatic,
    );

    _contributions.add(contribution);
    await _saveContributions();

    // NUEVO: Crear transacción de gasto (categoría: ahorros)
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      type: TransactionType.expense,
      description: note ?? 'Aporte a ${goal.name}',
      date: DateTime.now(),
      expenseCategory: ExpenseCategory.savings,
      incomeCategory: null,
    );
    await _transactionService.addTransaction(transaction);

    // Actualizar el monto actual de la meta
    final updatedAmount = goal.currentAmount + amount;
    final updatedGoal = goal.copyWith(
      currentAmount: updatedAmount,
      updatedAt: DateTime.now(),
    );

    // Si se alcanzó la meta, marcarla como completada
    if (updatedAmount >= goal.targetAmount && goal.status == GoalStatus.active) {
      final completedGoal = updatedGoal.copyWith(
        status: GoalStatus.completed,
        completedAt: DateTime.now(),
      );
      await updateGoal(completedGoal);
    } else {
      await updateGoal(updatedGoal);
    }
  }

  // Retirar dinero de una meta (reducir contribución)
  Future<void> withdrawFromGoal(String goalId, double amount, {String? note}) async {
    final goal = getGoalById(goalId);
    if (goal == null) {
      throw Exception('Meta no encontrada');
    }

    if (amount <= 0) {
      throw Exception('El monto debe ser mayor a cero');
    }

    if (amount > goal.currentAmount) {
      throw Exception('No puedes retirar más dinero del que tienes ahorrado');
    }

    // Agregar contribución negativa
    final withdrawal = GoalContribution(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      goalId: goalId,
      amount: -amount,
      date: DateTime.now(),
      note: note ?? 'Retiro',
      isAutomatic: false,
    );

    _contributions.add(withdrawal);
    await _saveContributions();

    // NUEVO: Crear transacción de ingreso cuando se retira de una meta
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      amount: amount,
      type: TransactionType.income,
      description: note ?? 'Retiro de ${goal.name}',
      date: DateTime.now(),
      expenseCategory: null,
      incomeCategory: IncomeCategory.other,
    );
    await _transactionService.addTransaction(transaction);

    // Actualizar el monto actual de la meta
    final updatedGoal = goal.copyWith(
      currentAmount: goal.currentAmount - amount,
      updatedAt: DateTime.now(),
    );

    // Si estaba completada y ahora no, cambiar status
    if (goal.status == GoalStatus.completed && updatedGoal.currentAmount < goal.targetAmount) {
      final reactivatedGoal = updatedGoal.copyWith(
        status: GoalStatus.active,
        completedAt: null,
      );
      await updateGoal(reactivatedGoal);
    } else {
      await updateGoal(updatedGoal);
    }
  }

  // Obtener meta por ID
  FinancialGoal? getGoalById(String goalId) {
    try {
      return _goals.firstWhere((g) => g.id == goalId);
    } catch (e) {
      return null;
    }
  }

  // Obtener contribuciones de una meta específica
  List<GoalContribution> getGoalContributions(String goalId) {
    return _contributions.where((c) => c.goalId == goalId).toList();
  }

  // Obtener metas por tipo
  List<FinancialGoal> getGoalsByType(GoalType type) {
    return _goals.where((g) => g.type == type).toList();
  }

  // Obtener metas por prioridad
  List<FinancialGoal> getGoalsByPriority(GoalPriority priority) {
    return _goals.where((g) => g.priority == priority).toList();
  }

  // Obtener metas que necesitan atención (atrasadas, sin progreso, etc.)
  List<FinancialGoal> getGoalsNeedingAttention() {
    final now = DateTime.now();
    return activeGoals.where((goal) =>
    goal.isOverdue ||
        !goal.isOnTrack ||
        (goal.daysRemaining <= 30 && goal.progressPercentage < 0.7) ||
        (now.difference(goal.startDate).inDays > 30 && goal.progressPercentage < 0.1)
    ).toList();
  }

  // Procesar contribuciones automáticas
  Future<int> processAutomaticContributions() async {
    int processedCount = 0;
    final today = DateTime.now();

    for (var goal in activeGoals) {
      if (goal.autoSave && goal.monthlyContribution > 0) {
        bool shouldProcess = false;
        String note = '';
        
        switch (goal.autoSaveFrequency) {
          case AutoSaveFrequency.daily:
            // Verificar si ya se procesó hoy
            final lastContribution = _contributions
                .where((c) => c.goalId == goal.id && c.isAutomatic)
                .where((c) => 
                    c.date.year == today.year && 
                    c.date.month == today.month && 
                    c.date.day == today.day)
                .isNotEmpty;
            shouldProcess = !lastContribution;
            note = 'Contribución automática diaria';
            break;
            
          case AutoSaveFrequency.weekly:
            // Verificar si ya se procesó esta semana (lunes)
            final mondayOfWeek = today.subtract(Duration(days: today.weekday - 1));
            final lastContribution = _contributions
                .where((c) => c.goalId == goal.id && c.isAutomatic)
                .where((c) => c.date.isAfter(mondayOfWeek.subtract(const Duration(days: 1))))
                .isNotEmpty;
            shouldProcess = !lastContribution && today.weekday == 1; // Lunes
            note = 'Contribución automática semanal';
            break;
            
          case AutoSaveFrequency.monthly:
            // Verificar si ya se procesó este mes
            final thisMonth = DateTime(today.year, today.month);
            final lastContribution = _contributions
                .where((c) => c.goalId == goal.id && c.isAutomatic)
                .where((c) => DateTime(c.date.year, c.date.month) == thisMonth)
                .isNotEmpty;
            shouldProcess = !lastContribution && today.day == 1; // Primer día del mes
            note = 'Contribución automática mensual';
            break;
        }

        if (shouldProcess) {
          try {
            await addContribution(
              goal.id!,
              goal.monthlyContribution,
              note: note,
              isAutomatic: true,
            );
            processedCount++;
          } catch (e) {
            print('Error processing automatic contribution for goal ${goal.name}: $e');
          }
        }
      }
    }

    return processedCount;
  }

  // Obtener resumen de todas las metas
  GoalSummary getGoalSummary() {
    double totalTargetAmount = 0;
    double totalCurrentAmount = 0;
    double totalMonthlyContributions = 0;
    int urgentGoals = 0;
    int onTrackGoals = 0;
    int completedThisMonth = 0;

    final thisMonth = DateTime(DateTime.now().year, DateTime.now().month);

    for (var goal in _goals) {
      totalTargetAmount += goal.targetAmount;
      totalCurrentAmount += goal.currentAmount;
      totalMonthlyContributions += goal.monthlyContribution;

      if (goal.priority == GoalPriority.urgent && goal.status == GoalStatus.active) {
        urgentGoals++;
      }

      if (goal.isOnTrack && goal.status == GoalStatus.active) {
        onTrackGoals++;
      }

      if (goal.completedAt != null &&
          DateTime(goal.completedAt!.year, goal.completedAt!.month) == thisMonth) {
        completedThisMonth++;
      }
    }

    return GoalSummary(
      totalGoals: _goals.length,
      activeGoals: activeGoals.length,
      completedGoals: completedGoals.length,
      totalTargetAmount: totalTargetAmount,
      totalCurrentAmount: totalCurrentAmount,
      totalMonthlyContributions: totalMonthlyContributions,
      urgentGoals: urgentGoals,
      onTrackGoals: onTrackGoals,
      completedThisMonth: completedThisMonth,
      overallProgress: totalTargetAmount > 0 ? totalCurrentAmount / totalTargetAmount : 0.0,
    );
  }

  // Obtener estadísticas de contribuciones
  ContributionStats getContributionStats() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final thisMonth = DateTime(now.year, now.month);

    final thisMonthContributions = _contributions.where((c) =>
    DateTime(c.date.year, c.date.month) == thisMonth && c.amount > 0
    ).toList();

    final lastMonthContributions = _contributions.where((c) =>
    DateTime(c.date.year, c.date.month) == lastMonth && c.amount > 0
    ).toList();

    final thisMonthTotal = thisMonthContributions.fold(0.0, (sum, c) => sum + c.amount);
    final lastMonthTotal = lastMonthContributions.fold(0.0, (sum, c) => sum + c.amount);

    return ContributionStats(
      thisMonthTotal: thisMonthTotal,
      lastMonthTotal: lastMonthTotal,
      thisMonthCount: thisMonthContributions.length,
      averageContribution: thisMonthContributions.isNotEmpty
          ? thisMonthTotal / thisMonthContributions.length
          : 0.0,
      growthPercentage: lastMonthTotal > 0
          ? ((thisMonthTotal - lastMonthTotal) / lastMonthTotal) * 100
          : 0.0,
    );
  }
}

// Clase para el resumen general de metas
class GoalSummary {
  final int totalGoals;
  final int activeGoals;
  final int completedGoals;
  final double totalTargetAmount;
  final double totalCurrentAmount;
  final double totalMonthlyContributions;
  final int urgentGoals;
  final int onTrackGoals;
  final int completedThisMonth;
  final double overallProgress;

  GoalSummary({
    required this.totalGoals,
    required this.activeGoals,
    required this.completedGoals,
    required this.totalTargetAmount,
    required this.totalCurrentAmount,
    required this.totalMonthlyContributions,
    required this.urgentGoals,
    required this.onTrackGoals,
    required this.completedThisMonth,
    required this.overallProgress,
  });

  double get remainingAmount => (totalTargetAmount - totalCurrentAmount).clamp(0.0, double.infinity);
  bool get isHealthy => onTrackGoals >= (activeGoals * 0.7);
}

// Clase para estadísticas de contribuciones
class ContributionStats {
  final double thisMonthTotal;
  final double lastMonthTotal;
  final int thisMonthCount;
  final double averageContribution;
  final double growthPercentage;

  ContributionStats({
    required this.thisMonthTotal,
    required this.lastMonthTotal,
    required this.thisMonthCount,
    required this.averageContribution,
    required this.growthPercentage,
  });

  bool get isGrowing => growthPercentage > 0;
  String get growthText => isGrowing ? '+${growthPercentage.toStringAsFixed(1)}%' : '${growthPercentage.toStringAsFixed(1)}%';
}