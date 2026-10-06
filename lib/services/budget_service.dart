import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import 'transaction_service.dart';
import 'account_service.dart';
import '../utils/app_log.dart';
import '../utils/format_utils.dart';

/// Último aviso dado a un presupuesto en su período actual (se persiste para
/// no repetir el mismo aviso al reabrir la app).
class _AlertMark {
  final DateTime periodStart;
  final BudgetAlertLevel level;

  const _AlertMark(this.periodStart, this.level);

  Map<String, dynamic> toJson() => {
    'periodStart': periodStart.toIso8601String(),
    'level': level.name,
  };

  static _AlertMark? fromJson(Object? json) {
    if (json is! Map) return null;
    final start = DateTime.tryParse('${json['periodStart']}');
    final level = BudgetAlertLevel.values
        .where((l) => l.name == json['level'])
        .firstOrNull;
    if (start == null || level == null) return null;
    return _AlertMark(start, level);
  }
}

class BudgetService {
  static const String _budgetsKey = 'budgets';
  static const String _alertMarksKey = 'budget_alert_marks';
  static const int _maxActiveBudgets =
      15; // NUEVO: Límite máximo de presupuestos

  // Singleton (misma instancia en memoria que TransactionService)
  static final BudgetService _instance = BudgetService._internal();
  factory BudgetService() => _instance;
  BudgetService._internal() {
    // Lo gastado sale de las transacciones: cada vez que una se crea, edita o
    // elimina (en cualquier pantalla, o por un gasto automático) se revisa si
    // algún presupuesto cruzó su porcentaje de alerta o su límite.
    _transactionService.addListener(_checkAlerts);
  }

  List<Budget> _budgets = [];
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  // true cuando _budgets refleja lo guardado (se puede revisar alertas).
  bool _isLoaded = false;

  // Clave: id del presupuesto.
  Map<String, _AlertMark> _alertMarks = {};
  bool _alertMarksLoaded = false;

  final StreamController<BudgetAlert> _alertsController =
      StreamController<BudgetAlert>.broadcast();

  /// Avisos de presupuesto a mostrar al usuario (uno por cada vez que un
  /// presupuesto llega a su porcentaje de alerta o a su límite). Solo se
  /// emiten si el presupuesto tiene las alertas activadas.
  Stream<BudgetAlert> get alerts => _alertsController.stream;

  // Getter para TODOS los presupuestos (sin filtro de cuenta)
  List<Budget> get allBudgets => _budgets;

  // Getter para presupuestos de la cuenta activa
  List<Budget> get budgets => _budgets
      .where((b) => b.accountId == _accountService.activeAccountId)
      .toList();

  // CORREGIDO: Mostrar todos los presupuestos activos de la cuenta activa
  List<Budget> get activeBudgets => budgets.where((b) => b.isActive).toList();

  // NUEVO: Getter para presupuestos que están en su período actual de la cuenta activa
  List<Budget> get currentPeriodBudgets =>
      budgets.where((b) => b.isActive && b.isCurrentlyActive).toList();

  // Cargar presupuestos desde almacenamiento local
  Future<void> loadBudgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetsJson = prefs.getString(_budgetsKey);

      if (budgetsJson != null) {
        final List<dynamic> budgetsList = json.decode(budgetsJson);
        _budgets = budgetsList.map((json) => Budget.fromJson(json)).toList();

        // Migración: reasignar presupuestos con accountId vacío o huérfano
        bool necesitaGuardar = false;
        for (int i = 0; i < _budgets.length; i++) {
          final resolved = _accountService.resolveAccountId(
            _budgets[i].accountId,
          );
          if (resolved != _budgets[i].accountId) {
            _budgets[i] = _budgets[i].copyWith(accountId: resolved);
            necesitaGuardar = true;
          }
        }
        if (necesitaGuardar) {
          await _saveBudgets();
        }

        // Ordenar por fecha de creación (más recientes primero)
        _budgets.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // NUEVO: Procesar reinicios automáticos después de cargar
        await processAutomaticResets();
      } else {
        _budgets = [];
      }

      // Las marcas de aviso se leen del disco solo la primera vez: después la
      // memoria siempre está al día (cada cambio se guarda) y releerlas en
      // medio de un guardado podría devolver una versión vieja y repetir un
      // aviso.
      if (!_alertMarksLoaded) {
        _alertMarks = _decodeAlertMarks(prefs.getString(_alertMarksKey));
        _alertMarksLoaded = true;
      }
      _isLoaded = true;
    } catch (e) {
      AppLog.error('Error cargando presupuestos', e);
      _budgets = [];
      _isLoaded = false;
    }
  }

  // Reemplaza TODOS los presupuestos (usado al restaurar una copia de
  // seguridad). El llamador es responsable de validar los datos antes.
  Future<void> replaceAllForRestore(List<Budget> budgets) async {
    _budgets = List.of(budgets)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveBudgets();
    await processAutomaticResets();
    // Los avisos de los presupuestos restaurados empiezan desde su estado
    // actual (no se avisa de golpe por todo lo que ya estaba gastado).
    _alertMarks = {};
    _alertMarksLoaded = true;
    for (final budget in _budgets) {
      _markCurrentLevel(budget);
    }
    await _saveAlertMarks();
    _isLoaded = true;
  }

  // NUEVO: Procesar reinicios automáticos de presupuestos
  Future<void> processAutomaticResets() async {
    bool hasChanges = false;

    for (int i = 0; i < _budgets.length; i++) {
      final budget = _budgets[i];

      // Solo procesar presupuestos activos
      if (!budget.isActive) continue;

      if (budget.needsReset) {
        // Obtener el nuevo rango de fechas
        final newRange = budget.getNextPeriodRange();

        // Actualizar el presupuesto con las nuevas fechas y marcar el reinicio
        _budgets[i] = budget.copyWith(
          startDate: newRange.start,
          endDate: newRange.end,
          lastResetDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        hasChanges = true;
      }
    }

    // Solo guardar si hubo cambios
    if (hasChanges) {
      await _saveBudgets();
    }
  }

  // Guardar presupuestos en almacenamiento local
  Future<void> _saveBudgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetsJson = json.encode(_budgets.map((b) => b.toJson()).toList());
      await prefs.setString(_budgetsKey, budgetsJson);
    } catch (e) {
      AppLog.error('Error guardando presupuestos', e);
      throw Exception('No se pudo guardar el presupuesto');
    }
  }

  // ───────────────────────── Alertas ─────────────────────────

  static Map<String, _AlertMark> _decodeAlertMarks(String? raw) {
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) return {};
      return {
        for (final entry in decoded.entries)
          if (_AlertMark.fromJson(entry.value) case final mark?)
            '${entry.key}': mark,
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveAlertMarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _alertMarksKey,
        json.encode({
          for (final entry in _alertMarks.entries)
            entry.key: entry.value.toJson(),
        }),
      );
    } catch (e) {
      AppLog.error('Error guardando avisos de presupuestos', e);
    }
  }

  /// Simula reabrir la app en pruebas: la próxima carga vuelve a leer del
  /// disco los avisos ya dados.
  @visibleForTesting
  void forgetAlertMarksForTesting() {
    _alertMarks = {};
    _alertMarksLoaded = false;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Nivel de aviso según lo gastado. Sin alertas activadas, siempre "none".
  BudgetAlertLevel _levelFor(Budget budget, double spentAmount) {
    if (!budget.alertsEnabled || budget.amount <= 0) {
      return BudgetAlertLevel.none;
    }
    if (spentAmount >= budget.amount) return BudgetAlertLevel.exceeded;
    if (budget.isAlertReached(spentAmount)) return BudgetAlertLevel.threshold;
    return BudgetAlertLevel.none;
  }

  /// Toma el estado actual del presupuesto como punto de partida, sin avisar.
  /// Se usa al crearlo o editarlo: si el usuario mismo deja el presupuesto
  /// por encima de su alerta (p. ej. baja el monto), ya lo está viendo.
  void _markCurrentLevel(Budget budget) {
    final id = budget.id;
    if (id == null) return;
    _alertMarks[id] = _AlertMark(
      budget.startDate,
      _levelFor(budget, getBudgetProgress(budget).spentAmount),
    );
  }

  /// Revisa todos los presupuestos en curso y avisa de los que SUBIERON de
  /// nivel (llegaron a su alerta o a su límite) desde la última revisión de
  /// su período. Cada aviso se da una sola vez por período; si lo gastado
  /// vuelve a bajar (se editó o eliminó un gasto), se puede volver a avisar
  /// cuando suba de nuevo.
  void _checkAlerts() {
    if (!_isLoaded || !_transactionService.isLoaded) return;

    final fired = <BudgetAlert>[];
    var changed = false;

    for (final budget in _budgets) {
      final id = budget.id;
      if (id == null || !budget.isActive || !budget.isCurrentlyActive) {
        continue;
      }

      final spent = getBudgetProgress(budget).spentAmount;
      final level = _levelFor(budget, spent);
      final mark = _alertMarks[id];

      if (mark == null) {
        // Presupuesto que todavía no se había revisado (p. ej. los que ya
        // existían al actualizar la app): su estado actual es el punto de
        // partida, sin avisar por lo ya gastado.
        _alertMarks[id] = _AlertMark(budget.startDate, level);
        changed = true;
        continue;
      }

      // Período nuevo (reinicio automático): se empieza desde cero.
      final previous = _sameDay(mark.periodStart, budget.startDate)
          ? mark.level
          : BudgetAlertLevel.none;

      if (level.index > previous.index) {
        fired.add(BudgetAlert(budget: budget, level: level, spentAmount: spent));
      }
      if (level != mark.level || !_sameDay(mark.periodStart, budget.startDate)) {
        _alertMarks[id] = _AlertMark(budget.startDate, level);
        changed = true;
      }
    }

    if (changed) unawaited(_saveAlertMarks());
    for (final alert in fired) {
      _alertsController.add(alert);
    }
  }

  // ─────────────────────────────────────────────────────────────

  // NUEVO: Verificar si se puede crear un nuevo presupuesto
  bool canCreateBudget() {
    return activeBudgets.length < _maxActiveBudgets;
  }

  // NUEVO: Obtener el número de presupuestos disponibles
  int get remainingBudgetsSlots => _maxActiveBudgets - activeBudgets.length;

  // CORREGIDO: Agregar nuevo presupuesto con validación mejorada
  Future<void> addBudget(Budget budget) async {
    // 1. Validar límite máximo de presupuestos activos
    if (!canCreateBudget()) {
      throw Exception(
        'Has alcanzado el límite máximo de $_maxActiveBudgets presupuestos activos',
      );
    }

    // 2. CORREGIDO: Validación más específica - solo bloquear duplicados EXACTOS
    final duplicateBudgets = _budgets.where((b) {
      // Primero verificar período y estado activo
      if (b.period != budget.period || !b.isActive) return false;
      if (!_isSamePeriodExact(b, budget)) return false;

      // Verificar categoría (sistema o personalizada)
      if (budget.hasCustomCategory) {
        // Nuevo presupuesto tiene categoría personalizada
        return b.customCategoryId == budget.customCategoryId;
      } else {
        // Nuevo presupuesto tiene categoría del sistema
        return b.category == budget.category && b.customCategoryId == null;
      }
    }).toList();

    if (duplicateBudgets.isNotEmpty) {
      throw Exception(
        'Ya existe un presupuesto ${budget.periodName.toLowerCase()} de ${budget.categoryName} para este mismo período',
      );
    }

    // 3. Crear nuevo presupuesto
    final newBudget = budget.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      accountId: _accountService.resolveAccountId(budget.accountId),
    );

    _budgets.add(newBudget);

    // CORREGIDO: Ordenar por fecha de creación (más recientes primero)
    _budgets.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await _saveBudgets();
    _markCurrentLevel(newBudget);
    await _saveAlertMarks();
  }

  // NUEVO: Función mejorada para detectar períodos exactamente iguales
  bool _isSamePeriodExact(Budget existing, Budget newBudget) {
    switch (newBudget.period) {
      case BudgetPeriod.weekly:
        // Para semanal: mismo lunes de inicio
        final existingMonday = _getMondayOfWeek(existing.startDate);
        final newMonday = _getMondayOfWeek(newBudget.startDate);
        return existingMonday.isAtSameMomentAs(newMonday);

      case BudgetPeriod.monthly:
        // Para mensual: mismo mes y año
        return existing.startDate.year == newBudget.startDate.year &&
            existing.startDate.month == newBudget.startDate.month;

      case BudgetPeriod.yearly:
        // Para anual: mismo año
        return existing.startDate.year == newBudget.startDate.year;
    }
  }

  // NUEVO: Obtener el lunes de una semana específica (a medianoche: con la
  // hora incluida, dos presupuestos de la misma semana creados a distinta
  // hora no se reconocían como duplicados).
  DateTime _getMondayOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday - 1));
  }

  // Actualizar presupuesto existente
  Future<void> updateBudget(Budget budget) async {
    final index = _budgets.indexWhere((b) => b.id == budget.id);
    if (index == -1) {
      throw Exception('Presupuesto no encontrado');
    }

    // Validar que no haya conflictos con otros presupuestos al actualizar
    final conflictingBudgets = _budgets.where((b) {
      // Excluir el presupuesto actual
      if (b.id == budget.id) return false;
      // Solo presupuestos activos con mismo período exacto
      if (b.period != budget.period || !b.isActive) return false;
      if (!_isSamePeriodExact(b, budget)) return false;

      // Verificar categoría (sistema o personalizada)
      if (budget.hasCustomCategory) {
        return b.customCategoryId == budget.customCategoryId;
      } else {
        return b.category == budget.category && b.customCategoryId == null;
      }
    }).toList();

    if (conflictingBudgets.isNotEmpty) {
      throw Exception(
        'Ya existe otro presupuesto ${budget.periodName.toLowerCase()} de ${budget.categoryName} para este período',
      );
    }

    final existing = _budgets[index];
    final rawAccountId = budget.accountId.isNotEmpty
        ? budget.accountId
        : existing.accountId;
    final accountId = _accountService.resolveAccountId(rawAccountId);

    _budgets[index] = budget.copyWith(
      accountId: accountId,
      updatedAt: DateTime.now(),
    );
    await _saveBudgets();
    // Con el monto o el porcentaje de alerta nuevos se parte del estado
    // actual (el usuario lo está viendo; no hace falta avisarle).
    _markCurrentLevel(_budgets[index]);
    await _saveAlertMarks();
  }

  // Eliminar presupuesto
  Future<void> deleteBudget(String budgetId) async {
    final initialLength = _budgets.length;
    _budgets.removeWhere((b) => b.id == budgetId);

    if (_budgets.length == initialLength) {
      throw Exception('Presupuesto no encontrado');
    }

    await _saveBudgets();
    if (_alertMarks.remove(budgetId) != null) await _saveAlertMarks();
  }

  /// Elimina todos los presupuestos que pertenecen a [accountId].
  /// Se usa al eliminar una cuenta por completo.
  Future<void> clearBudgetsForAccount(String accountId) async {
    final removedIds = _budgets
        .where((b) => b.accountId == accountId)
        .map((b) => b.id)
        .toSet();
    _budgets.removeWhere((b) => b.accountId == accountId);
    await _saveBudgets();
    _alertMarks.removeWhere((id, _) => removedIds.contains(id));
    await _saveAlertMarks();
  }

  // Activar/desactivar presupuesto
  Future<void> toggleBudget(String budgetId) async {
    final index = _budgets.indexWhere((b) => b.id == budgetId);
    if (index == -1) {
      throw Exception('Presupuesto no encontrado');
    }

    final currentBudget = _budgets[index];
    final newActiveState = !currentBudget.isActive;

    // Si se está activando, verificar límite
    if (newActiveState && !canCreateBudget()) {
      throw Exception(
        'No puedes activar más presupuestos. Límite máximo: $_maxActiveBudgets',
      );
    }

    _budgets[index] = _budgets[index].copyWith(
      isActive: newActiveState,
      updatedAt: DateTime.now(),
    );
    await _saveBudgets();
    if (newActiveState) {
      // Al reanudarlo no se avisa por lo gastado mientras estuvo pausado.
      _markCurrentLevel(_budgets[index]);
      await _saveAlertMarks();
    }
  }

  // Obtener presupuesto por ID
  Budget? getBudgetById(String budgetId) {
    try {
      return _budgets.firstWhere((b) => b.id == budgetId);
    } catch (e) {
      return null;
    }
  }

  // Obtener progreso de un presupuesto específico
  BudgetProgress getBudgetProgress(Budget budget) {
    // Las transacciones de la cuenta del presupuesto (igual a la cuenta
    // activa en pantalla; para las demás cuentas, las alertas también usan
    // sus propios gastos).
    final transactions = _transactionService.transactionsForAccount(
      budget.accountId,
    );

    // Período por días completos: desde las 00:00 del primer día hasta el
    // final del último. Antes el inicio era "después de (inicio - 1 día)", así
    // que también contaba lo gastado el último día del período anterior
    // (p. ej. el 30 de septiembre entraba en el presupuesto de octubre).
    final periodStart = DateTime(
      budget.startDate.year,
      budget.startDate.month,
      budget.startDate.day,
    );
    final periodEnd = DateTime(
      budget.endDate.year,
      budget.endDate.month,
      budget.endDate.day + 1,
    );

    // Filtrar transacciones del período y categoría del presupuesto
    final budgetTransactions = transactions.where((transaction) {
      // Debe ser un gasto
      if (transaction.type != TransactionType.expense) return false;

      // Verificar que esté dentro del período
      if (transaction.date.isBefore(periodStart) ||
          !transaction.date.isBefore(periodEnd)) {
        return false;
      }

      // Verificar categoría
      if (budget.hasCustomCategory) {
        // Presupuesto con categoría personalizada
        return transaction.customCategoryId == budget.customCategoryId;
      } else {
        // Presupuesto con categoría del sistema
        return transaction.expenseCategory == budget.category &&
            transaction.customCategoryId == null;
      }
    }).toList();

    // Calcular monto gastado, redondeado a centavos: sumar muchos decimales
    // (100 × 0,01 = 1,0000000000000007) marcaba "excedido" un presupuesto
    // gastado exactamente.
    final spentAmount =
        (budgetTransactions.fold(0.0, (sum, t) => sum + t.amount) * 100)
            .round() /
        100;

    return BudgetProgress(
      budget: budget,
      spentAmount: spentAmount,
      transactions: budgetTransactions,
    );
  }

  // Obtener progreso de todos los presupuestos activos
  List<BudgetProgress> getAllBudgetProgress() {
    return activeBudgets.map((budget) => getBudgetProgress(budget)).toList();
  }

  // Obtener presupuestos por categoría
  List<Budget> getBudgetsByCategory(ExpenseCategory category) {
    return _budgets.where((b) => b.category == category).toList();
  }

  // Obtener presupuestos que necesitan atención (cerca del límite o excedidos)
  List<BudgetProgress> getBudgetsNeedingAttention() {
    return getAllBudgetProgress()
        .where(
          (progress) =>
              progress.status == BudgetStatus.warning ||
              progress.status == BudgetStatus.danger ||
              progress.status == BudgetStatus.exceeded,
        )
        .toList();
  }

  // Verificar si se puede realizar un gasto (para alertas en tiempo real)
  BudgetCheckResult checkExpenseAgainstBudgets(
    double amount,
    ExpenseCategory category,
  ) {
    final relevantBudgets = activeBudgets
        .where((b) => b.category == category)
        .toList();

    if (relevantBudgets.isEmpty) {
      return BudgetCheckResult(
        canSpend: true,
        message: 'Sin restricciones de presupuesto',
        affectedBudgets: [],
      );
    }

    List<BudgetProgress> affectedBudgets = [];
    List<String> warnings = [];
    bool canSpend = true;

    for (var budget in relevantBudgets) {
      final progress = getBudgetProgress(budget);
      final newSpentAmount = progress.spentAmount + amount;
      final newStatus = budget.getStatus(newSpentAmount);

      affectedBudgets.add(
        BudgetProgress(
          budget: budget,
          spentAmount: newSpentAmount,
          transactions: progress.transactions,
        ),
      );

      if (newStatus == BudgetStatus.exceeded) {
        final excess = newSpentAmount - budget.amount;
        warnings.add(
          'Excederías el presupuesto de ${budget.categoryName} por ${FormatUtils.formatMoney(excess)}',
        );
        canSpend = false;
      } else if (newStatus == BudgetStatus.danger) {
        warnings.add(
          'Te acercarías al límite del presupuesto de ${budget.categoryName}',
        );
      } else if (newStatus == BudgetStatus.warning) {
        warnings.add(
          'Estarías usando el ${((newSpentAmount / budget.amount) * 100).toStringAsFixed(0)}% de tu presupuesto de ${budget.categoryName}',
        );
      }
    }

    return BudgetCheckResult(
      canSpend: canSpend,
      message: warnings.isEmpty
          ? 'Gasto dentro del presupuesto'
          : warnings.join('\n'),
      affectedBudgets: affectedBudgets,
    );
  }

  // MEJORADO: Obtener resumen de todos los presupuestos con información del límite
  BudgetSummary getBudgetSummary() {
    final allProgress = getAllBudgetProgress();

    double totalBudgeted = 0;
    double totalSpent = 0;
    int onTrackCount = 0;
    int warningCount = 0;
    int exceededCount = 0;

    for (var progress in allProgress) {
      totalBudgeted += progress.budget.amount;
      totalSpent += progress.spentAmount;

      switch (progress.status) {
        case BudgetStatus.safe:
          onTrackCount++;
          break;
        case BudgetStatus.warning:
          warningCount++;
          break;
        case BudgetStatus.danger:
        case BudgetStatus.exceeded:
          exceededCount++;
          break;
      }
    }

    return BudgetSummary(
      totalBudgets: allProgress.length,
      totalBudgeted: totalBudgeted,
      totalSpent: totalSpent,
      onTrackCount: onTrackCount,
      warningCount: warningCount,
      exceededCount: exceededCount,
      budgetProgress: allProgress,
      maxBudgets: _maxActiveBudgets, // NUEVO
      remainingSlots: remainingBudgetsSlots, // NUEVO
    );
  }

  // Generar fechas automáticas para presupuestos según el período
  static Map<String, DateTime> generateBudgetDates(
    BudgetPeriod period,
    DateTime? startDate,
  ) {
    final start = startDate ?? DateTime.now();
    DateTime end;

    switch (period) {
      case BudgetPeriod.weekly:
        // Comenzar el lunes de la semana actual, a medianoche (igual que los
        // períodos mensual/anual y que el reinicio automático).
        final mondayOfWeek = DateTime(
          start.year,
          start.month,
          start.day - (start.weekday - 1),
        );
        end = DateTime(
          mondayOfWeek.year,
          mondayOfWeek.month,
          mondayOfWeek.day + 6,
        );
        return {'start': mondayOfWeek, 'end': end};

      case BudgetPeriod.monthly:
        // Primer día del mes actual
        final firstDayOfMonth = DateTime(start.year, start.month, 1);
        final lastDayOfMonth = DateTime(start.year, start.month + 1, 0);
        return {'start': firstDayOfMonth, 'end': lastDayOfMonth};

      case BudgetPeriod.yearly:
        // Primer día del año actual
        final firstDayOfYear = DateTime(start.year, 1, 1);
        final lastDayOfYear = DateTime(start.year, 12, 31);
        return {'start': firstDayOfYear, 'end': lastDayOfYear};
    }
  }
}

// Clase para el resultado de verificación de gastos
class BudgetCheckResult {
  final bool canSpend;
  final String message;
  final List<BudgetProgress> affectedBudgets;

  BudgetCheckResult({
    required this.canSpend,
    required this.message,
    required this.affectedBudgets,
  });
}

// ACTUALIZADA: Clase para el resumen general de presupuestos
class BudgetSummary {
  final int totalBudgets;
  final double totalBudgeted;
  final double totalSpent;
  final int onTrackCount;
  final int warningCount;
  final int exceededCount;
  final List<BudgetProgress> budgetProgress;
  final int maxBudgets; // NUEVO
  final int remainingSlots; // NUEVO

  BudgetSummary({
    required this.totalBudgets,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.onTrackCount,
    required this.warningCount,
    required this.exceededCount,
    required this.budgetProgress,
    required this.maxBudgets, // NUEVO
    required this.remainingSlots, // NUEVO
  });

  double get remainingBudget =>
      (totalBudgeted - totalSpent).clamp(0.0, double.infinity);
  double get spentPercentage =>
      totalBudgeted > 0 ? (totalSpent / totalBudgeted) : 0.0;
  bool get overallHealthy =>
      exceededCount == 0 && warningCount <= (totalBudgets * 0.3);
  bool get isNearLimit =>
      remainingSlots <= 3; // NUEVO: Alerta cuando quedan pocos slots
}
