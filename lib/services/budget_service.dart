import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import 'transaction_service.dart';

class BudgetService {
  static const String _budgetsKey = 'budgets';

  List<Budget> _budgets = [];
  final TransactionService _transactionService = TransactionService();

  List<Budget> get budgets => _budgets;
  List<Budget> get activeBudgets => _budgets.where((b) => b.isCurrentlyActive).toList();

  // Cargar presupuestos desde almacenamiento local
  Future<void> loadBudgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetsJson = prefs.getString(_budgetsKey);

      if (budgetsJson != null) {
        final List<dynamic> budgetsList = json.decode(budgetsJson);
        _budgets = budgetsList.map((json) => Budget.fromJson(json)).toList();

        // Ordenar por fecha de creación (más recientes primero)
        _budgets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _budgets = [];
      }
    } catch (e) {
      print('Error loading budgets: $e');
      _budgets = [];
    }
  }

  // Guardar presupuestos en almacenamiento local
  Future<void> _saveBudgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetsJson = json.encode(_budgets.map((b) => b.toJson()).toList());
      await prefs.setString(_budgetsKey, budgetsJson);
    } catch (e) {
      print('Error saving budgets: $e');
      throw Exception('No se pudo guardar el presupuesto');
    }
  }

  // Agregar nuevo presupuesto
  Future<void> addBudget(Budget budget) async {
    // Validar que no exista un presupuesto activo para la misma categoría y período
    final existingBudget = _budgets.firstWhere(
          (b) => b.category == budget.category &&
          b.period == budget.period &&
          b.isCurrentlyActive &&
          _periodsOverlap(b, budget),
      orElse: () => Budget(
        name: '',
        amount: 0,
        period: budget.period,
        category: budget.category,
        startDate: DateTime.now(),
        endDate: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );

    if (existingBudget.name.isNotEmpty) {
      throw Exception('Ya existe un presupuesto activo para ${budget.categoryName} en este período');
    }

    final newBudget = budget.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    _budgets.add(newBudget);
    await _saveBudgets();
  }

  // Verificar si dos presupuestos se superponen en tiempo
  bool _periodsOverlap(Budget existing, Budget newBudget) {
    return newBudget.startDate.isBefore(existing.endDate) &&
        newBudget.endDate.isAfter(existing.startDate);
  }

  // Actualizar presupuesto existente
  Future<void> updateBudget(Budget budget) async {
    final index = _budgets.indexWhere((b) => b.id == budget.id);
    if (index == -1) {
      throw Exception('Presupuesto no encontrado');
    }

    _budgets[index] = budget.copyWith(updatedAt: DateTime.now());
    await _saveBudgets();
  }

  // Eliminar presupuesto
  Future<void> deleteBudget(String budgetId) async {
    final initialLength = _budgets.length;
    _budgets.removeWhere((b) => b.id == budgetId);

    if (_budgets.length == initialLength) {
      throw Exception('Presupuesto no encontrado');
    }

    await _saveBudgets();
  }

  // Activar/desactivar presupuesto
  Future<void> toggleBudget(String budgetId) async {
    final index = _budgets.indexWhere((b) => b.id == budgetId);
    if (index == -1) {
      throw Exception('Presupuesto no encontrado');
    }

    _budgets[index] = _budgets[index].copyWith(
      isActive: !_budgets[index].isActive,
      updatedAt: DateTime.now(),
    );
    await _saveBudgets();
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
    // Asegurar que las transacciones estén cargadas
    final transactions = _transactionService.transactions;

    // Filtrar transacciones del período y categoría del presupuesto
    final budgetTransactions = transactions.where((transaction) =>
    transaction.type == TransactionType.expense &&
        transaction.expenseCategory == budget.category &&
        transaction.date.isAfter(budget.startDate.subtract(const Duration(days: 1))) &&
        transaction.date.isBefore(budget.endDate.add(const Duration(days: 1)))
    ).toList();

    // Calcular monto gastado
    final spentAmount = budgetTransactions.fold(0.0, (sum, t) => sum + t.amount);

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
    return getAllBudgetProgress().where((progress) =>
    progress.status == BudgetStatus.warning ||
        progress.status == BudgetStatus.danger ||
        progress.status == BudgetStatus.exceeded
    ).toList();
  }

  // Verificar si se puede realizar un gasto (para alertas en tiempo real)
  BudgetCheckResult checkExpenseAgainstBudgets(double amount, ExpenseCategory category) {
    final relevantBudgets = activeBudgets.where((b) => b.category == category).toList();

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

      affectedBudgets.add(BudgetProgress(
        budget: budget,
        spentAmount: newSpentAmount,
        transactions: progress.transactions,
      ));

      if (newStatus == BudgetStatus.exceeded) {
        final excess = newSpentAmount - budget.amount;
        warnings.add('Excederías el presupuesto de ${budget.categoryName} por \$${excess.toStringAsFixed(0)}');
        canSpend = false;
      } else if (newStatus == BudgetStatus.danger) {
        warnings.add('Te acercarías al límite del presupuesto de ${budget.categoryName}');
      } else if (newStatus == BudgetStatus.warning) {
        warnings.add('Estarías usando el ${((newSpentAmount / budget.amount) * 100).toStringAsFixed(0)}% de tu presupuesto de ${budget.categoryName}');
      }
    }

    return BudgetCheckResult(
      canSpend: canSpend,
      message: warnings.isEmpty ? 'Gasto dentro del presupuesto' : warnings.join('\n'),
      affectedBudgets: affectedBudgets,
    );
  }

  // Obtener resumen de todos los presupuestos
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
    );
  }

  // Generar fechas automáticas para presupuestos según el período
  static Map<String, DateTime> generateBudgetDates(BudgetPeriod period, DateTime? startDate) {
    final start = startDate ?? DateTime.now();
    DateTime end;

    switch (period) {
      case BudgetPeriod.weekly:
      // Comenzar el lunes de la semana actual
        final mondayOfWeek = start.subtract(Duration(days: start.weekday - 1));
        end = mondayOfWeek.add(const Duration(days: 6));
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

// Clase para el resumen general de presupuestos
class BudgetSummary {
  final int totalBudgets;
  final double totalBudgeted;
  final double totalSpent;
  final int onTrackCount;
  final int warningCount;
  final int exceededCount;
  final List<BudgetProgress> budgetProgress;

  BudgetSummary({
    required this.totalBudgets,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.onTrackCount,
    required this.warningCount,
    required this.exceededCount,
    required this.budgetProgress,
  });

  double get remainingBudget => (totalBudgeted - totalSpent).clamp(0.0, double.infinity);
  double get spentPercentage => totalBudgeted > 0 ? (totalSpent / totalBudgeted) : 0.0;
  bool get overallHealthy => exceededCount == 0 && warningCount <= (totalBudgets * 0.3);
}