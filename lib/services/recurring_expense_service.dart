import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recurring_expense.dart';
import '../models/transaction.dart';
import '../utils/app_log.dart';
import 'transaction_service.dart';
import 'budget_service.dart';
import 'account_service.dart';

class RecurringExpenseService {
  static const String _recurringExpensesKey = 'recurring_expenses';

  // Instancia única del servicio (Singleton)
  static final RecurringExpenseService _instance =
      RecurringExpenseService._internal();
  factory RecurringExpenseService() => _instance;
  RecurringExpenseService._internal();

  final AccountService _accountService = AccountService();

  // Lista en memoria de gastos recurrentes
  List<RecurringExpense> _recurringExpenses = [];

  // Getter para TODOS los gastos recurrentes (sin filtro de cuenta)
  List<RecurringExpense> get allRecurringExpenses =>
      List.unmodifiable(_recurringExpenses);

  // Getter para obtener gastos recurrentes de la cuenta activa
  List<RecurringExpense> get recurringExpenses => List.unmodifiable(
    _recurringExpenses
        .where((e) => e.accountId == _accountService.activeAccountId)
        .toList(),
  );

  // Getter para obtener solo los gastos activos de la cuenta activa
  List<RecurringExpense> get activeRecurringExpenses =>
      recurringExpenses.where((expense) => expense.isActive).toList();

  // Cargar gastos recurrentes desde el almacenamiento local
  Future<void> loadRecurringExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recurringExpensesJson = prefs.getString(_recurringExpensesKey);

      if (recurringExpensesJson != null) {
        final List<dynamic> expensesList = json.decode(recurringExpensesJson);
        _recurringExpenses = expensesList
            .map((json) => RecurringExpense.fromJson(json))
            .toList();

        // Migración: reasignar gastos recurrentes con accountId vacío o huérfano
        bool necesitaGuardar = false;
        for (int i = 0; i < _recurringExpenses.length; i++) {
          final resolved = _accountService.resolveAccountId(
            _recurringExpenses[i].accountId,
          );
          if (resolved != _recurringExpenses[i].accountId) {
            _recurringExpenses[i] = _recurringExpenses[i].copyWith(
              accountId: resolved,
            );
            necesitaGuardar = true;
          }
        }
        if (necesitaGuardar) {
          await _saveRecurringExpenses();
        }

        // Ordenar por fecha de creación (más reciente primero)
        _recurringExpenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _recurringExpenses = [];
      }
    } catch (e) {
      AppLog.error('Error cargando gastos automáticos', e);
      _recurringExpenses = [];
    }
  }

  // Guardar gastos recurrentes en el almacenamiento local
  Future<void> _saveRecurringExpenses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recurringExpensesJson = json.encode(
        _recurringExpenses.map((expense) => expense.toJson()).toList(),
      );
      await prefs.setString(_recurringExpensesKey, recurringExpensesJson);
    } catch (e) {
      AppLog.error('Error guardando gastos automáticos', e);
    }
  }

  // Reemplaza TODOS los gastos recurrentes (usado al restaurar una copia de
  // seguridad). El llamador es responsable de validar los datos antes.
  Future<void> replaceAllForRestore(List<RecurringExpense> expenses) async {
    _recurringExpenses = List.of(expenses)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveRecurringExpenses();
  }

  // Agregar un nuevo gasto recurrente
  Future<void> addRecurringExpense(RecurringExpense expense) async {
    // Asignar cuenta activa si no tiene
    final expenseWithAccount = expense.copyWith(
      accountId: _accountService.resolveAccountId(expense.accountId),
    );
    _recurringExpenses.add(expenseWithAccount);
    // Mantener ordenado por fecha de creación
    _recurringExpenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveRecurringExpenses();
  }

  // Actualizar un gasto recurrente
  Future<void> updateRecurringExpense(RecurringExpense updatedExpense) async {
    final index = _recurringExpenses.indexWhere(
      (expense) => expense.id == updatedExpense.id,
    );
    if (index != -1) {
      final existing = _recurringExpenses[index];
      final rawAccountId = updatedExpense.accountId.isNotEmpty
          ? updatedExpense.accountId
          : existing.accountId;
      final accountId = _accountService.resolveAccountId(rawAccountId);

      _recurringExpenses[index] = updatedExpense.copyWith(accountId: accountId);
      await _saveRecurringExpenses();
    }
  }

  // Eliminar un gasto recurrente
  Future<void> deleteRecurringExpense(String id) async {
    _recurringExpenses.removeWhere((expense) => expense.id == id);
    await _saveRecurringExpenses();
  }

  /// Elimina los gastos automáticos de [accountId]. Se usa al eliminar una
  /// cuenta: si quedaban, al cargarlos se reasignaban a la cuenta principal y
  /// seguían registrando gastos allí.
  ///
  /// Debe llamarse ANTES de quitar la cuenta: recarga la lista guardada (por
  /// si aún no estaba en memoria) y esa carga reasigna los gastos de cuentas
  /// que ya no existen.
  Future<void> clearRecurringExpensesForAccount(String accountId) async {
    await loadRecurringExpenses();
    final before = _recurringExpenses.length;
    _recurringExpenses.removeWhere((e) => e.accountId == accountId);
    if (_recurringExpenses.length != before) {
      await _saveRecurringExpenses();
    }
  }

  // Activar/Desactivar un gasto recurrente
  Future<void> toggleRecurringExpense(String id) async {
    final index = _recurringExpenses.indexWhere((expense) => expense.id == id);
    if (index != -1) {
      final expense = _recurringExpenses[index];
      _recurringExpenses[index] = expense.copyWith(isActive: !expense.isActive);
      await _saveRecurringExpenses();
    }
  }

  // Procesamiento en curso: Inicio lo dispara cada vez que se abre y también
  // el botón "Procesar". Dos ejecuciones a la vez veían el mismo gasto como
  // pendiente (aún sin lastProcessed) y lo registraban dos veces.
  Future<List<Transaction>>? _processing;

  // ACTUALIZADO: Procesar gastos recurrentes del día actual con integración de presupuestos
  Future<List<Transaction>> processRecurringExpensesForToday() {
    return _processing ??= _processRecurringExpensesForToday().whenComplete(
      () => _processing = null,
    );
  }

  Future<List<Transaction>> _processRecurringExpensesForToday() async {
    final transactionService = TransactionService();
    final createdTransactions = <Transaction>[];

    // Presupuestos en memoria antes de registrar: si un gasto automático hace
    // que un presupuesto llegue a su alerta o a su límite, se avisa al
    // usuario (BudgetService revisa cada transacción nueva).
    await BudgetService().loadBudgets();

    // Se recorre una copia: loadRecurringExpenses() puede reemplazar la
    // lista mientras se espera a guardar cada transacción.
    for (final expense in List.of(_recurringExpenses)) {
      if (expense.shouldRunToday()) {
        try {
          // Crear la transacción
          final transaction = expense.createTransaction();
          await transactionService.addTransaction(transaction);
          createdTransactions.add(transaction);

          // Marcar y guardar de inmediato (antes se guardaba al final del
          // recorrido): si la app se cierra a mitad, el gasto no se vuelve a
          // registrar al abrirla.
          final index = _recurringExpenses.indexWhere(
            (e) => e.id == expense.id,
          );
          if (index != -1) {
            _recurringExpenses[index] = _recurringExpenses[index].copyWith(
              lastProcessed: DateTime.now(),
            );
            await _saveRecurringExpenses();
          }
        } catch (e) {
          AppLog.error('Error procesando un gasto automático', e);
          // Continuar con el siguiente gasto en caso de error
        }
      }
    }

    return createdTransactions;
  }

  // Método alias para procesar gastos recurrentes
  Future<List<Transaction>> processRecurringExpenses() async {
    return await processRecurringExpensesForToday();
  }

  // Obtener gastos que se ejecutarán hoy
  List<RecurringExpense> getExpensesForToday() {
    return _recurringExpenses
        .where((expense) => expense.shouldRunToday())
        .toList();
  }

  // Obtener resumen de gastos recurrentes
  Map<String, dynamic> getRecurringExpensesSummary() {
    final activeExpenses = activeRecurringExpenses;

    double dailyTotal = 0;
    double weeklyTotal = 0;
    double monthlyTotal = 0;

    for (final expense in activeExpenses) {
      switch (expense.frequency) {
        case RecurrenceFrequency.daily:
          dailyTotal += expense.amount;
          weeklyTotal += expense.amount * 7;
          monthlyTotal += expense.amount * 30;
          break;
        case RecurrenceFrequency.weekly:
          final daysPerWeek = expense.weekDays?.length ?? 7;
          // Para gastos semanales:
          // - amount representa el gasto total semanal
          // - valor diario = amount / días seleccionados
          // - valor semanal = amount (tal como está)
          // - valor mensual = amount * 4 semanas
          final dailyAmount = expense.amount / daysPerWeek;
          dailyTotal += dailyAmount;
          weeklyTotal += expense.amount;
          monthlyTotal += expense.amount * 4;
          break;
        case RecurrenceFrequency.monthly:
          monthlyTotal += expense.amount;
          weeklyTotal += expense.amount / 4;
          dailyTotal += expense.amount / 30;
          break;
        case RecurrenceFrequency.custom:
          if (expense.customDays != null) {
            final timesPerMonth = 30 / expense.customDays!;
            monthlyTotal += expense.amount * timesPerMonth;
            weeklyTotal += expense.amount * (7 / expense.customDays!);
            dailyTotal += expense.amount / expense.customDays!;
          }
          break;
      }
    }

    return {
      'totalActive': activeExpenses.length,
      'totalInactive': _recurringExpenses.length - activeExpenses.length,
      'estimatedDaily': dailyTotal,
      'estimatedWeekly': weeklyTotal,
      'estimatedMonthly': monthlyTotal,
    };
  }

  // NUEVO: Obtener impacto de gastos recurrentes en presupuestos
  Future<Map<String, dynamic>> getBudgetImpactSummary() async {
    final budgetService = BudgetService();
    await budgetService.loadBudgets();

    final activeExpenses = activeRecurringExpenses;
    final activeBudgets = budgetService.currentPeriodBudgets;

    Map<ExpenseCategory, double> categoryImpact = {};
    Map<ExpenseCategory, List<String>> affectedBudgets = {};

    // Calcular impacto por categoría (convertir todo a impacto mensual)
    for (final expense in activeExpenses) {
      double monthlyImpact = 0;

      switch (expense.frequency) {
        case RecurrenceFrequency.daily:
          monthlyImpact = expense.amount * 30;
          break;
        case RecurrenceFrequency.weekly:
          monthlyImpact = expense.amount * 4;
          break;
        case RecurrenceFrequency.monthly:
          monthlyImpact = expense.amount;
          break;
        case RecurrenceFrequency.custom:
          if (expense.customDays != null) {
            monthlyImpact = expense.amount * (30 / expense.customDays!);
          }
          break;
      }

      categoryImpact[expense.category] =
          (categoryImpact[expense.category] ?? 0) + monthlyImpact;
    }

    // Encontrar presupuestos afectados (se excluyen los de categoría
    // personalizada, ya que los gastos recurrentes no tienen ese concepto)
    for (final budget in activeBudgets) {
      if (!budget.hasCustomCategory &&
          categoryImpact.containsKey(budget.category)) {
        affectedBudgets[budget.category] ??= [];
        affectedBudgets[budget.category]!.add(budget.name);
      }
    }

    return {
      'categoriesWithImpact': categoryImpact.length,
      'affectedBudgets': affectedBudgets.values.expand((list) => list).length,
      'categoryImpact': categoryImpact,
      'affectedBudgetsByCategory': affectedBudgets,
      'totalEstimatedImpact': categoryImpact.values.fold(
        0.0,
        (sum, amount) => sum + amount,
      ),
    };
  }

  // Obtener gastos por categoría
  Map<ExpenseCategory, List<RecurringExpense>> getExpensesByCategory() {
    final Map<ExpenseCategory, List<RecurringExpense>> categorized = {};

    for (final expense in activeRecurringExpenses) {
      if (categorized[expense.category] == null) {
        categorized[expense.category] = [];
      }
      categorized[expense.category]!.add(expense);
    }

    return categorized;
  }

  // Limpiar todos los gastos recurrentes (útil para desarrollo)
  Future<void> clearAllRecurringExpenses() async {
    _recurringExpenses.clear();
    await _saveRecurringExpenses();
  }

  // Verificar si hay gastos vencidos (que debieron ejecutarse pero no se ejecutaron)
  List<RecurringExpense> getOverdueExpenses() {
    final today = DateTime.now();
    final overdueExpenses = <RecurringExpense>[];

    for (final expense in activeRecurringExpenses) {
      if (expense.lastProcessed != null) {
        final daysSinceLastProcessed = today
            .difference(expense.lastProcessed!)
            .inDays;

        switch (expense.frequency) {
          case RecurrenceFrequency.daily:
            if (daysSinceLastProcessed > 1) {
              overdueExpenses.add(expense);
            }
            break;
          case RecurrenceFrequency.weekly:
            if (daysSinceLastProcessed > 7) {
              overdueExpenses.add(expense);
            }
            break;
          case RecurrenceFrequency.monthly:
            if (daysSinceLastProcessed > 31) {
              overdueExpenses.add(expense);
            }
            break;
          case RecurrenceFrequency.custom:
            if (expense.customDays != null &&
                daysSinceLastProcessed > expense.customDays!) {
              overdueExpenses.add(expense);
            }
            break;
        }
      }
    }

    return overdueExpenses;
  }
}
