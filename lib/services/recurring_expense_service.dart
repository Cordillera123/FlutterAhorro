import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recurring_expense.dart';
import '../models/transaction.dart';
import 'transaction_service.dart';

class RecurringExpenseService {
  static const String _recurringExpensesKey = 'recurring_expenses';

  // Instancia única del servicio (Singleton)
  static final RecurringExpenseService _instance = RecurringExpenseService._internal();
  factory RecurringExpenseService() => _instance;
  RecurringExpenseService._internal();

  // Lista en memoria de gastos recurrentes
  List<RecurringExpense> _recurringExpenses = [];

  // Getter para obtener todos los gastos recurrentes
  List<RecurringExpense> get recurringExpenses => List.unmodifiable(_recurringExpenses);

  // Getter para obtener solo los gastos activos
  List<RecurringExpense> get activeRecurringExpenses =>
      _recurringExpenses.where((expense) => expense.isActive).toList();

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

        // Ordenar por fecha de creación (más reciente primero)
        _recurringExpenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (e) {
      print('Error cargando gastos recurrentes: $e');
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
      print('Error guardando gastos recurrentes: $e');
    }
  }

  // Agregar un nuevo gasto recurrente
  Future<void> addRecurringExpense(RecurringExpense expense) async {
    _recurringExpenses.add(expense);
    // Mantener ordenado por fecha de creación
    _recurringExpenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveRecurringExpenses();
  }

  // Actualizar un gasto recurrente
  Future<void> updateRecurringExpense(RecurringExpense updatedExpense) async {
    final index = _recurringExpenses.indexWhere((expense) => expense.id == updatedExpense.id);
    if (index != -1) {
      _recurringExpenses[index] = updatedExpense;
      await _saveRecurringExpenses();
    }
  }

  // Eliminar un gasto recurrente
  Future<void> deleteRecurringExpense(String id) async {
    _recurringExpenses.removeWhere((expense) => expense.id == id);
    await _saveRecurringExpenses();
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

  // Procesar gastos recurrentes del día actual
  Future<List<Transaction>> processRecurringExpensesForToday() async {
    final transactionService = TransactionService();
    final createdTransactions = <Transaction>[];

    for (int i = 0; i < _recurringExpenses.length; i++) {
      final expense = _recurringExpenses[i];

      if (expense.shouldRunToday()) {
        // Crear la transacción
        final transaction = expense.createTransaction();
        await transactionService.addTransaction(transaction);
        createdTransactions.add(transaction);

        // Actualizar la fecha de último procesamiento
        _recurringExpenses[i] = expense.copyWith(
          lastProcessed: DateTime.now(),
        );
      }
    }

    // Guardar los cambios si se procesaron gastos
    if (createdTransactions.isNotEmpty) {
      await _saveRecurringExpenses();
    }

    return createdTransactions;
  }

  // Método alias para procesar gastos recurrentes
  Future<List<Transaction>> processRecurringExpenses() async {
    return await processRecurringExpensesForToday();
  }

  // Obtener gastos que se ejecutarán hoy
  List<RecurringExpense> getExpensesForToday() {
    return _recurringExpenses.where((expense) => expense.shouldRunToday()).toList();
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
          final daysPerWeek = expense.weekDays?.length ?? 1;
          weeklyTotal += expense.amount * daysPerWeek;
          monthlyTotal += expense.amount * daysPerWeek * 4;
          break;
        case RecurrenceFrequency.monthly:
          monthlyTotal += expense.amount;
          break;
        case RecurrenceFrequency.custom:
          if (expense.customDays != null) {
            final timesPerMonth = 30 / expense.customDays!;
            monthlyTotal += expense.amount * timesPerMonth;
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
        final daysSinceLastProcessed = today.difference(expense.lastProcessed!).inDays;

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
            if (expense.customDays != null && daysSinceLastProcessed > expense.customDays!) {
              overdueExpenses.add(expense);
            }
            break;
        }
      }
    }

    return overdueExpenses;
  }
}