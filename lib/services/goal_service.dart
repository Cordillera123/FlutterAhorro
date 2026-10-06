import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/financial_goal.dart';
import '../models/transaction.dart';
import '../utils/app_log.dart';
import 'transaction_service.dart';
import 'account_service.dart';

class GoalService extends ChangeNotifier {
  static const String _goalsKey = 'financial_goals';
  static const String _contributionsKey = 'goal_contributions';

  /// Marca de la migración única que enlaza los aportes creados antes de que
  /// existiera [GoalContribution.transactionId] con su transacción.
  static const String _legacyLinkKey = 'goal_contributions_linked_v1';

  /// Margen para reconocer la transacción de un aporte antiguo: ambos
  /// registros se creaban en la misma operación, con milisegundos de
  /// diferencia.
  static const Duration _legacyLinkWindow = Duration(minutes: 2);

  // Singleton
  static final GoalService _instance = GoalService._internal();
  factory GoalService() => _instance;
  GoalService._internal() {
    // Cada aporte es también una transacción del historial (el gasto
    // "Aporte a …"). Cuando esa transacción se edita o se elimina desde
    // cualquier pantalla, la meta se actualiza sola.
    _transactionService.addListener(_onTransactionsChanged);
  }

  List<FinancialGoal> _goals = [];
  List<GoalContribution> _contributions = [];
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  // true cuando _goals/_contributions reflejan lo guardado.
  bool _isLoaded = false;

  // Getter para TODAS las metas (sin filtro de cuenta)
  List<FinancialGoal> get allGoals => _goals;

  // Getter para metas de la cuenta activa
  List<FinancialGoal> get goals => _goals
      .where((g) => g.accountId == _accountService.activeAccountId)
      .toList();
  List<FinancialGoal> get activeGoals =>
      goals.where((g) => g.status == GoalStatus.active).toList();
  List<FinancialGoal> get pausedGoals =>
      goals.where((g) => g.status == GoalStatus.paused).toList();
  List<FinancialGoal> get completedGoals =>
      goals.where((g) => g.status == GoalStatus.completed).toList();
  List<GoalContribution> get contributions => _contributions
      .where((c) => c.accountId == _accountService.activeAccountId)
      .toList();

  // Getter para TODAS las contribuciones (sin filtro de cuenta)
  List<GoalContribution> get allContributions =>
      List.unmodifiable(_contributions);

  // Validar si se pueden crear más metas en la cuenta activa
  // Solo cuentan las metas activas/pausadas (igual que el contador que ve el
  // usuario) — las completadas/canceladas no ocupan cupo.
  bool get canCreateMoreGoals => activeGoals.length + pausedGoals.length < 15;

  // Cargar metas desde almacenamiento local
  Future<void> loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cargar metas
      final goalsJson = prefs.getString(_goalsKey);
      if (goalsJson != null) {
        final List<dynamic> goalsList = json.decode(goalsJson);
        _goals = goalsList.map((json) => FinancialGoal.fromJson(json)).toList();

        // Migración: reasignar metas con accountId vacío o huérfano
        bool goalsNeedSave = false;
        for (int i = 0; i < _goals.length; i++) {
          final resolved = _accountService.resolveAccountId(
            _goals[i].accountId,
          );
          if (resolved != _goals[i].accountId) {
            _goals[i] = _goals[i].copyWith(accountId: resolved);
            goalsNeedSave = true;
          }
        }
        if (goalsNeedSave) {
          await _saveGoals();
        }

        _sortGoals(_goals);
      } else {
        // Sin nada guardado no debe quedar nada en memoria (antes se
        // conservaba lo de una carga anterior).
        _goals = [];
      }

      // Cargar contribuciones
      final contributionsJson = prefs.getString(_contributionsKey);
      if (contributionsJson != null) {
        final List<dynamic> contributionsList = json.decode(contributionsJson);
        _contributions = contributionsList
            .map((json) => GoalContribution.fromJson(json))
            .toList();

        // Migración: reasignar contribuciones con accountId vacío o huérfano
        bool contributionsNeedSave = false;
        for (int i = 0; i < _contributions.length; i++) {
          final resolved = _accountService.resolveAccountId(
            _contributions[i].accountId,
          );
          if (resolved != _contributions[i].accountId) {
            _contributions[i] = _contributions[i].copyWith(
              accountId: resolved,
            );
            contributionsNeedSave = true;
          }
        }
        if (contributionsNeedSave) {
          await _saveContributions();
        }

        // Ordenar por fecha (más recientes primero)
        _contributions.sort((a, b) => b.date.compareTo(a.date));
      } else {
        _contributions = [];
      }

      // Los aportes siguen a sus transacciones (pudieron editarse o borrarse
      // mientras las metas no estaban cargadas).
      var contributionsChanged = false;
      if (_transactionService.isLoaded) {
        if (prefs.getBool(_legacyLinkKey) != true) {
          contributionsChanged = _linkLegacyContributions();
          await prefs.setBool(_legacyLinkKey, true);
        }
        contributionsChanged =
            _syncContributionsWithTransactions() || contributionsChanged;
      }

      // El monto acumulado de cada meta se calcula SIEMPRE a partir de sus
      // aportes (nunca se confía en el currentAmount guardado).
      final statusChanged = _recomputeGoalAmounts();

      if (contributionsChanged) await _saveContributions();
      if (contributionsChanged || statusChanged) await _saveGoals();
      _isLoaded = true;
    } catch (e) {
      AppLog.error('Error cargando metas', e);
      _goals = [];
      _contributions = [];
      _isLoaded = false;
    }
  }

  void _sortGoals(List<FinancialGoal> goals) {
    goals.sort((a, b) {
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

  static double _roundToCents(double value) => (value * 100).round() / 100;

  /// Recalcula el monto ahorrado de cada meta como la suma de sus aportes y
  /// ajusta su estado: se completa al llegar al objetivo y, si una meta
  /// completada vuelve a quedar por debajo (se editó o eliminó un aporte, o
  /// se subió el objetivo), vuelve a estar activa.
  ///
  /// Devuelve `true` si cambió el estado de alguna meta.
  bool _recomputeGoalAmounts() {
    var statusChanged = false;
    final now = DateTime.now();

    for (var i = 0; i < _goals.length; i++) {
      final goal = _goals[i];
      if (goal.id == null) continue;

      // Redondeado a centavos: sumar muchos decimales (0,1 + 0,2…) no debe
      // dejar una meta en 99,99999 % ni impedir que se complete.
      final total = _roundToCents(
        _contributions
            .where((c) => c.goalId == goal.id)
            .fold(0.0, (sum, c) => sum + c.amount),
      );
      final reached = total >= goal.targetAmount;

      var updated = goal.copyWith(
        currentAmount: total,
        updatedAt: goal.updatedAt,
      );
      if (reached && goal.status != GoalStatus.completed) {
        updated = updated.copyWith(
          status: GoalStatus.completed,
          completedAt: now,
        );
        statusChanged = true;
      } else if (!reached && goal.status == GoalStatus.completed) {
        updated = updated.copyWith(
          status: GoalStatus.active,
          clearCompletedAt: true,
        );
        statusChanged = true;
      }
      _goals[i] = updated;
    }

    return statusChanged;
  }

  /// ¿La transacción [t] puede representar el aporte (gasto) o el retiro
  /// (ingreso) [c]?
  static bool _isSameKind(GoalContribution c, Transaction t) =>
      c.isWithdrawal
      ? t.type == TransactionType.income
      : t.type == TransactionType.expense;

  /// Pone cada aporte enlazado al día con su transacción, que es la fuente de
  /// verdad: mismo monto, fecha y cuenta. Si la transacción ya no existe (o
  /// dejó de ser un gasto/ingreso), el aporte se quita de la meta.
  ///
  /// Devuelve `true` si cambió algún aporte.
  bool _syncContributionsWithTransactions() {
    if (!_transactionService.isLoaded) return false;

    final byId = {for (final t in _transactionService.allTransactions) t.id: t};
    final seen = <String>{};
    final result = <GoalContribution>[];
    var changed = false;

    for (final c in _contributions) {
      final transactionId = c.transactionId;
      if (transactionId == null) {
        result.add(c); // aporte antiguo sin enlazar: se conserva tal cual
        continue;
      }

      final t = byId[transactionId];
      // seen.add == false: dos aportes apuntando a la misma transacción
      // contarían el dinero dos veces; solo vale el primero.
      if (t == null || !seen.add(transactionId) || !_isSameKind(c, t)) {
        changed = true;
        continue;
      }

      final amount = c.isWithdrawal ? -t.amount : t.amount;
      if (amount != c.amount ||
          t.date != c.date ||
          t.accountId != c.accountId) {
        result.add(
          c.copyWith(amount: amount, date: t.date, accountId: t.accountId),
        );
        changed = true;
      } else {
        result.add(c);
      }
    }

    if (changed) {
      _contributions = result..sort((a, b) => b.date.compareTo(a.date));
    }
    return changed;
  }

  /// Migración única: los aportes creados antes de existir el enlace se
  /// asocian a su transacción, que se creó en la misma operación (mismo
  /// monto/categoría "Ahorros e Inversión", misma cuenta, segundos de
  /// diferencia) o, si se le cambió la fecha, por su descripción. Lo que no
  /// se puede reconocer con seguridad se deja como estaba.
  bool _linkLegacyContributions() {
    final transactions = _transactionService.allTransactions;
    final used = <String>{
      for (final c in _contributions)
        if (c.transactionId != null) c.transactionId!,
    };
    var changed = false;

    bool looksLikeContribution(GoalContribution c, Transaction t) {
      if (used.contains(t.id) || t.accountId != c.accountId) return false;
      if (t.hasCustomCategory) return false;
      return c.isWithdrawal
          ? t.type == TransactionType.income &&
                t.incomeCategory == IncomeCategory.other
          : t.type == TransactionType.expense &&
                t.expenseCategory == ExpenseCategory.savings;
    }

    void linkBest(int index, bool Function(Transaction) accept) {
      final c = _contributions[index];
      Transaction? best;
      Duration? bestGap;
      for (final t in transactions) {
        if (!looksLikeContribution(c, t) || !accept(t)) continue;
        final gap = t.date.difference(c.date).abs();
        if (bestGap == null || gap < bestGap) {
          best = t;
          bestGap = gap;
        }
      }
      if (best != null) {
        _contributions[index] = c.copyWith(transactionId: best.id);
        used.add(best.id);
        changed = true;
      }
    }

    // 1) Por cercanía en el tiempo.
    for (var i = 0; i < _contributions.length; i++) {
      if (_contributions[i].transactionId != null) continue;
      final c = _contributions[i];
      linkBest(
        i,
        (t) => t.date.difference(c.date).abs() <= _legacyLinkWindow,
      );
    }

    // 2) Por la descripción con que se creó ("Aporte a …", "Retiro de …" o
    //    la nota), por si se le cambió la fecha a la transacción.
    for (var i = 0; i < _contributions.length; i++) {
      if (_contributions[i].transactionId != null) continue;
      final c = _contributions[i];
      final goalName = getGoalById(c.goalId)?.name;
      final expected =
          c.note ??
          (c.isWithdrawal ? 'Retiro de $goalName' : 'Aporte a $goalName');
      if (goalName == null && c.note == null) continue;
      linkBest(i, (t) => t.description == expected);
    }

    return changed;
  }

  /// Una transacción cambió (se creó, editó o eliminó) en cualquier pantalla.
  void _onTransactionsChanged() {
    if (!_isLoaded || !_transactionService.isLoaded) return;
    if (!_syncContributionsWithTransactions()) return;
    _recomputeGoalAmounts();
    unawaited(_persistAndNotify());
  }

  Future<void> _persistAndNotify() async {
    try {
      await _saveContributions();
      await _saveGoals();
    } catch (e) {
      AppLog.error('Error guardando metas sincronizadas', e);
    }
    notifyListeners();
  }

  /// Aporte de la meta que corresponde a la transacción [transactionId], o
  /// `null` si esa transacción no es un aporte/retiro de ninguna meta.
  GoalContribution? contributionForTransaction(String transactionId) {
    for (final c in _contributions) {
      if (c.transactionId == transactionId) return c;
    }
    return null;
  }

  /// Nombre de la meta a la que pertenece la transacción [transactionId], o
  /// `null` si no es un aporte/retiro de ninguna meta.
  String? goalNameForTransaction(String transactionId) {
    final contribution = contributionForTransaction(transactionId);
    if (contribution == null) return null;
    return getGoalById(contribution.goalId)?.name;
  }

  // Guardar metas en almacenamiento local
  Future<void> _saveGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final goalsJson = json.encode(_goals.map((g) => g.toJson()).toList());
      await prefs.setString(_goalsKey, goalsJson);
    } catch (e) {
      AppLog.error('Error guardando metas', e);
      throw Exception('No se pudo guardar la meta');
    }
  }

  // Guardar contribuciones en almacenamiento local
  Future<void> _saveContributions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contributionsJson = json.encode(
        _contributions.map((c) => c.toJson()).toList(),
      );
      await prefs.setString(_contributionsKey, contributionsJson);
    } catch (e) {
      AppLog.error('Error guardando aportes', e);
      throw Exception('No se pudo guardar la contribución');
    }
  }

  // Reemplaza TODAS las metas y contribuciones (usado al restaurar una
  // copia de seguridad). El llamador es responsable de validar los datos
  // antes. Las transacciones deben restaurarse ANTES, para poder enlazar los
  // aportes de copias antiguas con sus transacciones.
  Future<void> replaceAllForRestore(
    List<FinancialGoal> goals,
    List<GoalContribution> contributions,
  ) async {
    _goals = List.of(goals);
    _sortGoals(_goals);
    _contributions = List.of(contributions);

    if (_transactionService.isLoaded) {
      _linkLegacyContributions();
      _syncContributionsWithTransactions();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_legacyLinkKey, true);
    }
    _recomputeGoalAmounts();
    _isLoaded = true;

    await _saveGoals();
    await _saveContributions();
    notifyListeners();
  }

  // Agregar nueva meta
  Future<void> addGoal(FinancialGoal goal) async {
    // Validar límite máximo de metas activas/pausadas de la cuenta activa
    // (mismo criterio que canCreateMoreGoals y el contador visible al usuario)
    if (!canCreateMoreGoals) {
      throw Exception(
        'Has alcanzado el límite máximo de 15 metas. Elimina o completa algunas metas para crear nuevas.',
      );
    }

    final newGoal = goal.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: _accountService.resolveAccountId(goal.accountId),
    );

    _goals.add(newGoal);
    await _saveGoals();
    notifyListeners();
  }

  // Actualizar meta existente
  Future<void> updateGoal(FinancialGoal goal) async {
    final index = _goals.indexWhere((g) => g.id == goal.id);
    if (index == -1) {
      throw Exception('Meta no encontrada');
    }

    final existing = _goals[index];
    final rawAccountId = goal.accountId.isNotEmpty
        ? goal.accountId
        : existing.accountId;
    final accountId = _accountService.resolveAccountId(rawAccountId);

    _goals[index] = goal.copyWith(
      accountId: accountId,
      updatedAt: DateTime.now(),
    );
    // El ahorro acumulado sale de los aportes; si cambió el objetivo, la meta
    // puede pasar a completada o volver a activa.
    _recomputeGoalAmounts();
    await _saveGoals();
    notifyListeners();
  }

  // Eliminar meta
  Future<void> deleteGoal(String goalId) async {
    final initialLength = _goals.length;
    _goals.removeWhere((g) => g.id == goalId);

    if (_goals.length == initialLength) {
      throw Exception('Meta no encontrada');
    }

    // También eliminar todas las contribuciones de esta meta. Sus
    // transacciones ("Aporte a …") se conservan en el historial: el dinero
    // ya salió del saldo disponible cuando se aportó.
    _contributions.removeWhere((c) => c.goalId == goalId);

    await _saveGoals();
    await _saveContributions();
    notifyListeners();
  }

  /// Elimina todas las metas (y sus contribuciones) que pertenecen a [accountId].
  /// Se usa al eliminar una cuenta por completo.
  Future<void> clearGoalsForAccount(String accountId) async {
    final goalIds = _goals
        .where((g) => g.accountId == accountId)
        .map((g) => g.id)
        .toSet();
    if (goalIds.isEmpty) return;

    _goals.removeWhere((g) => g.accountId == accountId);
    _contributions.removeWhere((c) => goalIds.contains(c.goalId));

    await _saveGoals();
    await _saveContributions();
    notifyListeners();
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
    notifyListeners();
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
  //
  // El aporte se registra también como un gasto de "Ahorros e Inversión" en
  // el historial (sale del saldo disponible) y ambos quedan enlazados: esa
  // transacción es la que manda si luego se edita o elimina.
  Future<void> addContribution(
    String goalId,
    double amount, {
    String? note,
    bool isAutomatic = false,
  }) async {
    final goal = getGoalById(goalId);
    if (goal == null) {
      throw Exception('Meta no encontrada');
    }

    if (!amount.isFinite || amount <= 0) {
      throw Exception('El monto debe ser mayor a cero');
    }

    final now = DateTime.now();
    final accountId = _accountService.activeAccountId;

    // Primero la transacción: así, mientras se guarda, ningún aporte apunta a
    // una transacción que todavía no existe.
    final transaction = Transaction(
      id: _transactionService.generateId(),
      amount: amount,
      type: TransactionType.expense,
      description: note ?? 'Aporte a ${goal.name}',
      date: now,
      expenseCategory: ExpenseCategory.savings,
      incomeCategory: null,
      accountId: accountId,
    );
    await _transactionService.addTransaction(transaction);

    final contribution = GoalContribution(
      id: now.millisecondsSinceEpoch.toString(),
      goalId: goalId,
      amount: amount,
      date: transaction.date,
      note: note,
      isAutomatic: isAutomatic,
      accountId: transaction.accountId,
      transactionId: transaction.id,
    );
    await _addLinkedContribution(contribution, transaction.id);
  }

  // Retirar dinero de una meta (reducir contribución)
  Future<void> withdrawFromGoal(
    String goalId,
    double amount, {
    String? note,
  }) async {
    final goal = getGoalById(goalId);
    if (goal == null) {
      throw Exception('Meta no encontrada');
    }

    if (!amount.isFinite || amount <= 0) {
      throw Exception('El monto debe ser mayor a cero');
    }

    if (amount > goal.currentAmount) {
      throw Exception('No puedes retirar más dinero del que tienes ahorrado');
    }

    final now = DateTime.now();
    final accountId = _accountService.activeAccountId;

    // El retiro vuelve al saldo como un ingreso, enlazado igual que un aporte.
    final transaction = Transaction(
      id: _transactionService.generateId(),
      amount: amount,
      type: TransactionType.income,
      description: note ?? 'Retiro de ${goal.name}',
      date: now,
      expenseCategory: null,
      incomeCategory: IncomeCategory.other,
      accountId: accountId,
    );
    await _transactionService.addTransaction(transaction);

    final withdrawal = GoalContribution(
      id: now.millisecondsSinceEpoch.toString(),
      goalId: goalId,
      amount: -amount,
      date: transaction.date,
      note: note ?? 'Retiro',
      isAutomatic: false,
      accountId: transaction.accountId,
      transactionId: transaction.id,
    );
    await _addLinkedContribution(withdrawal, transaction.id);
  }

  Future<void> _addLinkedContribution(
    GoalContribution contribution,
    String transactionId,
  ) async {
    _contributions.insert(0, contribution);
    _recomputeGoalAmounts();
    try {
      await _saveContributions();
      await _saveGoals();
    } catch (e) {
      // Sin aporte guardado no debe quedar un gasto "Aporte a …" suelto.
      _contributions.remove(contribution);
      _recomputeGoalAmounts();
      await _transactionService.deleteTransaction(transactionId);
      rethrow;
    }
    notifyListeners();
  }

  // ───── Aportes antiguos sin transacción enlazada ─────
  // Los aportes enlazados se editan/eliminan a través de su transacción
  // (fuente de verdad). Los antiguos que no se pudieron enlazar no tienen
  // transacción, así que se corrigen aquí directamente.

  int _indexOfUnlinked(GoalContribution c) => _contributions.indexWhere(
    (x) =>
        x.transactionId == null &&
        x.id == c.id &&
        x.goalId == c.goalId &&
        x.date == c.date,
  );

  /// Cambia el monto de un aporte antiguo sin transacción. [amount] es
  /// siempre positivo; un retiro conserva su signo.
  Future<void> updateUnlinkedContribution(
    GoalContribution contribution,
    double amount,
  ) async {
    if (!amount.isFinite || amount <= 0) {
      throw Exception('El monto debe ser mayor a cero');
    }
    final index = _indexOfUnlinked(contribution);
    if (index == -1) throw Exception('Aporte no encontrado');

    final current = _contributions[index];
    _contributions[index] = current.copyWith(
      amount: current.isWithdrawal ? -amount : amount,
    );
    _recomputeGoalAmounts();
    await _saveContributions();
    await _saveGoals();
    notifyListeners();
  }

  /// Quita de la meta un aporte antiguo sin transacción.
  Future<void> deleteUnlinkedContribution(GoalContribution contribution) async {
    final index = _indexOfUnlinked(contribution);
    if (index == -1) throw Exception('Aporte no encontrado');

    _contributions.removeAt(index);
    _recomputeGoalAmounts();
    await _saveContributions();
    await _saveGoals();
    notifyListeners();
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
    return activeGoals
        .where(
          (goal) =>
              goal.isOverdue ||
              !goal.isOnTrack ||
              (goal.daysRemaining <= 30 && goal.progressPercentage < 0.7) ||
              (now.difference(goal.startDate).inDays > 30 &&
                  goal.progressPercentage < 0.1),
        )
        .toList();
  }

  // Procesar contribuciones automáticas
  Future<int> processAutomaticContributions() async {
    int processedCount = 0;
    final today = DateTime.now();

    for (var goal in activeGoals) {
      if (goal.autoSave && goal.autoSaveAmount > 0) {
        bool shouldProcess = false;
        String note = '';

        switch (goal.autoSaveFrequency) {
          case AutoSaveFrequency.daily:
            // Verificar si ya se procesó hoy
            final lastContribution = _contributions
                .where((c) => c.goalId == goal.id && c.isAutomatic)
                .where(
                  (c) =>
                      c.date.year == today.year &&
                      c.date.month == today.month &&
                      c.date.day == today.day,
                )
                .isNotEmpty;
            shouldProcess = !lastContribution;
            note = 'Contribución automática diaria';
            break;

          case AutoSaveFrequency.weekly:
            // Verificar si ya se procesó esta semana (lunes)
            final mondayOfWeek = today.subtract(
              Duration(days: today.weekday - 1),
            );
            final lastContribution = _contributions
                .where((c) => c.goalId == goal.id && c.isAutomatic)
                .where(
                  (c) => c.date.isAfter(
                    mondayOfWeek.subtract(const Duration(days: 1)),
                  ),
                )
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
            shouldProcess =
                !lastContribution && today.day == 1; // Primer día del mes
            note = 'Contribución automática mensual';
            break;
        }

        if (shouldProcess) {
          try {
            await addContribution(
              goal.id!,
              goal.autoSaveAmount,
              note: note,
              isAutomatic: true,
            );
            processedCount++;
          } catch (e) {
            AppLog.error('Error en un aporte automático', e);
          }
        }
      }
    }

    if (processedCount > 0) {
      notifyListeners();
    }

    return processedCount;
  }

  // Obtener resumen de las metas de la cuenta activa (antes sumaba las de
  // TODAS las cuentas mientras los contadores eran solo de la activa).
  GoalSummary getGoalSummary() {
    double totalTargetAmount = 0;
    double totalCurrentAmount = 0;
    double totalMonthlyContributions = 0;
    int urgentGoals = 0;
    int onTrackGoals = 0;
    int completedThisMonth = 0;

    final thisMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final accountGoals = goals;

    for (var goal in accountGoals) {
      totalTargetAmount += goal.targetAmount;
      totalCurrentAmount += goal.currentAmount;
      totalMonthlyContributions += goal.autoSaveAmount;

      if (goal.priority == GoalPriority.urgent &&
          goal.status == GoalStatus.active) {
        urgentGoals++;
      }

      if (goal.isOnTrack && goal.status == GoalStatus.active) {
        onTrackGoals++;
      }

      if (goal.completedAt != null &&
          DateTime(goal.completedAt!.year, goal.completedAt!.month) ==
              thisMonth) {
        completedThisMonth++;
      }
    }

    return GoalSummary(
      totalGoals: accountGoals.length,
      activeGoals: activeGoals.length,
      completedGoals: completedGoals.length,
      totalTargetAmount: totalTargetAmount,
      totalCurrentAmount: totalCurrentAmount,
      totalMonthlyContributions: totalMonthlyContributions,
      urgentGoals: urgentGoals,
      onTrackGoals: onTrackGoals,
      completedThisMonth: completedThisMonth,
      overallProgress: totalTargetAmount > 0
          ? totalCurrentAmount / totalTargetAmount
          : 0.0,
    );
  }

  // Obtener estadísticas de contribuciones de la cuenta activa
  ContributionStats getContributionStats() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final thisMonth = DateTime(now.year, now.month);
    final accountContributions = contributions;

    final thisMonthContributions = accountContributions
        .where(
          (c) =>
              DateTime(c.date.year, c.date.month) == thisMonth && c.amount > 0,
        )
        .toList();

    final lastMonthContributions = accountContributions
        .where(
          (c) =>
              DateTime(c.date.year, c.date.month) == lastMonth && c.amount > 0,
        )
        .toList();

    final thisMonthTotal = thisMonthContributions.fold(
      0.0,
      (sum, c) => sum + c.amount,
    );
    final lastMonthTotal = lastMonthContributions.fold(
      0.0,
      (sum, c) => sum + c.amount,
    );

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

  double get remainingAmount =>
      (totalTargetAmount - totalCurrentAmount).clamp(0.0, double.infinity);
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
  String get growthText => isGrowing
      ? '+${growthPercentage.toStringAsFixed(1)}%'
      : '${growthPercentage.toStringAsFixed(1)}%';
}
