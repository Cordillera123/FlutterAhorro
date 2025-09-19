import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recurring_expense.dart';
import '../models/transaction.dart';
import 'transaction_service.dart';
import 'budget_service.dart'; // NUEVO: Importar BudgetService

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

  // ACTUALIZADO: Procesar gastos recurrentes del día actual con integración de presupuestos
  Future<List<Transaction>> processRecurringExpensesForToday() async {
    final transactionService = TransactionService();
    final budgetService = BudgetService(); // NUEVO: Instancia del BudgetService
    final createdTransactions = <Transaction>[];

    // NUEVO: Cargar presupuestos para poder trabajar con ellos
    await budgetService.loadBudgets();

    for (int i = 0; i < _recurringExpenses.length; i++) {
      final expense = _recurringExpenses[i];

      if (expense.shouldRunToday()) {
        try {
          // Crear la transacción
          final transaction = expense.createTransaction();
          await transactionService.addTransaction(transaction);
          createdTransactions.add(transaction);

          // NUEVO: Verificar si hay presupuestos activos para esta categoría
          final activeBudgets = budgetService.currentPeriodBudgets
              .where((budget) => budget.category == expense.category)
              .toList();

          if (activeBudgets.isNotEmpty) {
            print('💰 Gasto recurrente procesado: ${expense.name} (\$${expense.amount})');
            print('📊 Encontrados ${activeBudgets.length} presupuesto(s) activo(s) para categoría ${expense.categoryName}');
            
            // Los presupuestos se actualizarán automáticamente cuando se consulten
            // porque el BudgetService calcula los gastos basándose en las transacciones
            for (final budget in activeBudgets) {
              print('   - Presupuesto: ${budget.name} (\$${budget.amount})');
            }
          } else {
            print('⚠️ No hay presupuestos activos para la categoría ${expense.categoryName}');
          }

          // Actualizar la fecha de último procesamiento
          _recurringExpenses[i] = expense.copyWith(
            lastProcessed: DateTime.now(),
          );

        } catch (e) {
          print('❌ Error procesando gasto recurrente ${expense.name}: $e');
          // Continuar con el siguiente gasto en caso de error
        }
      }
    }

    // Guardar los cambios si se procesaron gastos
    if (createdTransactions.isNotEmpty) {
      await _saveRecurringExpenses();
      print('✅ Procesados ${createdTransactions.length} gastos recurrentes exitosamente');
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
    
    // Encontrar presupuestos afectados
    for (final budget in activeBudgets) {
      if (categoryImpact.containsKey(budget.category)) {
        affectedBudgets[budget.category] ??= [];
        affectedBudgets[budget.category]!.add(budget.name);
      }
    }
    
    return {
      'categoriesWithImpact': categoryImpact.length,
      'affectedBudgets': affectedBudgets.values.expand((list) => list).length,
      'categoryImpact': categoryImpact,
      'affectedBudgetsByCategory': affectedBudgets,
      'totalEstimatedImpact': categoryImpact.values.fold(0.0, (sum, amount) => sum + amount),
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