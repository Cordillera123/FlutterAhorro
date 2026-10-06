import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/budget.dart';
import 'package:ahorro_app/models/financial_goal.dart';
import 'package:ahorro_app/models/recurring_expense.dart';
import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/budget_service.dart';
import 'package:ahorro_app/services/goal_service.dart';
import 'package:ahorro_app/services/recurring_expense_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';

/// Alerta del presupuesto ("Alertar al X % del presupuesto"): se avisa una
/// vez al llegar al porcentaje elegido y otra al llegar al límite, solo si las
/// alertas están activadas, sin repetir avisos (ni al reabrir la app) y desde
/// cualquier origen del gasto.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final accounts = AccountService();
  final transactions = TransactionService();
  final budgets = BudgetService();

  final received = <BudgetAlert>[];
  budgets.alerts.listen(received.add);

  // Los avisos llegan por un Stream (asíncrono).
  Future<List<BudgetAlert>> drain() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final copy = List.of(received);
    received.clear();
    return copy;
  }

  var seq = 0;
  Transaction expense(
    double amount, {
    ExpenseCategory category = ExpenseCategory.food,
    DateTime? date,
  }) {
    seq++;
    return Transaction(
      id: 'al_$seq',
      amount: amount,
      type: TransactionType.expense,
      description: 'Gasto $seq',
      date: date ?? DateTime.now(),
      expenseCategory: category,
      accountId: accounts.activeAccountId,
    );
  }

  Future<Budget> createBudget({
    double amount = 100,
    double threshold = 0.8,
    bool alertsEnabled = true,
    ExpenseCategory category = ExpenseCategory.food,
  }) async {
    final dates = BudgetService.generateBudgetDates(
      BudgetPeriod.monthly,
      DateTime.now(),
    );
    await budgets.addBudget(
      Budget(
        name: 'Comida',
        amount: amount,
        period: BudgetPeriod.monthly,
        category: category,
        startDate: dates['start']!,
        endDate: dates['end']!,
        alertsEnabled: alertsEnabled,
        alertThreshold: threshold,
        createdAt: DateTime.now(),
        accountId: accounts.activeAccountId,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return budgets.budgets.firstWhere((b) => b.category == category);
  }

  Future<void> restart() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    budgets.forgetAlertMarksForTesting();
    await accounts.loadAccounts();
    await transactions.loadTransactions();
    await budgets.loadBudgets();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GoalService().loadGoals();
    budgets.forgetAlertMarksForTesting();
    await accounts.loadAccounts();
    await transactions.loadTransactions();
    await budgets.loadBudgets();
    await RecurringExpenseService().loadRecurringExpenses();
    await drain();
  });

  group('Cuándo se avisa', () {
    test('al llegar al % elegido y otra vez al pasar el límite', () async {
      await createBudget(amount: 100, threshold: 0.8);

      await transactions.addTransaction(expense(50));
      expect(await drain(), isEmpty, reason: '50 %: todavía no');

      await transactions.addTransaction(expense(35));
      final first = await drain();
      expect(first, hasLength(1));
      expect(first.single.level, BudgetAlertLevel.threshold);
      expect(first.single.title, 'Alerta de presupuesto');
      expect(first.single.message, contains('85 %'));
      expect(first.single.message, contains('tu alerta es al 80 %'));
      expect(first.single.message, contains('15,00'));

      await transactions.addTransaction(expense(10));
      expect(await drain(), isEmpty, reason: '95 %: ya se avisó');

      await transactions.addTransaction(expense(10));
      final second = await drain();
      expect(second, hasLength(1));
      expect(second.single.level, BudgetAlertLevel.exceeded);
      expect(second.single.title, 'Presupuesto excedido');
      expect(second.single.message, contains('105 %'));
      expect(second.single.message, contains('Te pasaste por 5,00'));

      await transactions.addTransaction(expense(50));
      expect(await drain(), isEmpty, reason: 'excedido: ya se avisó');
    });

    test('un solo gasto que salta del 0 % al 120 % avisa el límite', () async {
      await createBudget(amount: 100);
      await transactions.addTransaction(expense(120));
      final alerts = await drain();
      expect(alerts.single.level, BudgetAlertLevel.exceeded);
    });

    test('exactamente el 100 % es "al límite"', () async {
      await createBudget(amount: 100);
      await transactions.addTransaction(expense(100));
      final alert = (await drain()).single;
      expect(alert.title, 'Presupuesto al límite');
      expect(alert.message, contains('llegaste al 100 %'));
    });

    test('justo en el porcentaje (80 de 100) avisa', () async {
      await createBudget(amount: 100, threshold: 0.8);
      await transactions.addTransaction(expense(80));
      expect((await drain()).single.level, BudgetAlertLevel.threshold);
    });

    test('porcentaje guardado con decimales del control (0,6499…)', () async {
      await createBudget(amount: 100, threshold: 0.6499999999999999);
      await transactions.addTransaction(expense(65));
      expect((await drain()).single.message, contains('tu alerta es al 65 %'));
    });

    test('con las alertas desactivadas no se avisa nunca', () async {
      await createBudget(amount: 100, alertsEnabled: false);
      await transactions.addTransaction(expense(90));
      await transactions.addTransaction(expense(50));
      expect(await drain(), isEmpty);
    });

    test('un gasto de otra categoría no avisa', () async {
      await createBudget(amount: 100);
      await transactions.addTransaction(
        expense(500, category: ExpenseCategory.transport),
      );
      expect(await drain(), isEmpty);
    });

    test('un gasto de otro mes no cuenta para el aviso', () async {
      await createBudget(amount: 100);
      final now = DateTime.now();
      await transactions.addTransaction(
        expense(500, date: DateTime(now.year, now.month, 0, 12)),
      );
      expect(await drain(), isEmpty);
    });
  });

  group('Sin avisos repetidos ni sorpresas', () {
    test('editar o eliminar puede bajar el nivel y volver a avisar', () async {
      await createBudget(amount: 100);
      final g = expense(85);
      await transactions.addTransaction(g);
      expect(await drain(), hasLength(1));

      // Se corrige el gasto a 40 → baja del 80 %; sin aviso.
      await transactions.updateTransaction(g.copyWith(amount: 40));
      expect(await drain(), isEmpty);

      // Vuelve a subir → se avisa de nuevo.
      await transactions.updateTransaction(g.copyWith(amount: 82));
      expect((await drain()).single.level, BudgetAlertLevel.threshold);

      await transactions.deleteTransaction(g.id);
      expect(await drain(), isEmpty);
    });

    test('al reabrir la app no se repite un aviso ya dado', () async {
      await createBudget(amount: 100);
      await transactions.addTransaction(expense(85));
      expect(await drain(), hasLength(1));

      await restart();
      await transactions.addTransaction(expense(5));
      expect(await drain(), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      final marks = json.decode(prefs.getString('budget_alert_marks')!) as Map;
      expect(marks.values.single['level'], 'threshold');
    });

    test('crear un presupuesto ya pasado no avisa por lo ya gastado', () async {
      await transactions.addTransaction(expense(150));
      await createBudget(amount: 100);
      await transactions.addTransaction(
        expense(1, category: ExpenseCategory.transport),
      );
      await transactions.addTransaction(expense(10));
      expect(await drain(), isEmpty);
    });

    test('bajar el monto del presupuesto no avisa (lo hizo el usuario)', () async {
      final b = await createBudget(amount: 1000);
      await transactions.addTransaction(expense(300));
      await budgets.updateBudget(b.copyWith(amount: 320));
      await transactions.addTransaction(expense(5)); // 95 %
      expect(await drain(), isEmpty);
      await transactions.addTransaction(expense(20)); // 100 %+
      expect((await drain()).single.level, BudgetAlertLevel.exceeded);
    });

    test('presupuestos que ya existían al actualizar la app parten de cero avisos', () async {
      final b = await createBudget(amount: 100);
      await transactions.addTransaction(expense(90));
      await drain();

      // Sin marcas guardadas (como antes de esta versión) y ya al 90 %.
      SharedPreferences.setMockInitialValues({
        'budgets': json.encode([b.toJson()]),
        'transactions': json.encode(
          transactions.allTransactions.map((t) => t.toJson()).toList(),
        ),
        'accounts': json.encode(
          accounts.accounts.map((a) => a.toJson()).toList(),
        ),
      });
      await restart();
      await transactions.addTransaction(expense(1)); // 91 %
      expect(await drain(), isEmpty);
    });

    test('un presupuesto pausado no avisa y al reanudarlo tampoco de golpe', () async {
      final b = await createBudget(amount: 100);
      await budgets.toggleBudget(b.id!);
      await transactions.addTransaction(expense(95));
      expect(await drain(), isEmpty);

      await budgets.toggleBudget(b.id!);
      await transactions.addTransaction(expense(1));
      expect(await drain(), isEmpty);
      await transactions.addTransaction(expense(10));
      expect((await drain()).single.level, BudgetAlertLevel.exceeded);
    });

    test('en un período nuevo se vuelve a avisar', () async {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0);
      await budgets.addBudget(
        Budget(
          name: 'Mes pasado',
          amount: 100,
          period: BudgetPeriod.monthly,
          category: ExpenseCategory.food,
          startDate: start,
          endDate: end,
          createdAt: start,
          accountId: accounts.activeAccountId,
        ),
      );
      // El mes pasado ya se había avisado.
      await transactions.addTransaction(
        expense(95, date: DateTime(now.year, now.month - 1, 10)),
      );
      await drain();

      await budgets.processAutomaticResets(); // pasa al mes actual
      await transactions.addTransaction(expense(85));
      expect((await drain()).single.level, BudgetAlertLevel.threshold);
    });
  });

  group('Desde cualquier origen del gasto', () {
    test('un aporte a una meta cuenta para "Ahorros e Inversión"', () async {
      await createBudget(amount: 200, category: ExpenseCategory.savings);
      final now = DateTime.now();
      await GoalService().addGoal(
        FinancialGoal(
          name: 'Viaje',
          description: '',
          targetAmount: 5000,
          startDate: now,
          targetDate: DateTime(now.year + 1, now.month, now.day),
          type: GoalType.vacation,
          createdAt: now,
          accountId: accounts.activeAccountId,
        ),
      );
      await GoalService().addContribution(GoalService().goals.single.id!, 170);
      expect((await drain()).single.budget.category, ExpenseCategory.savings);
    });

    test('un gasto automático del día también avisa', () async {
      await createBudget(amount: 10, category: ExpenseCategory.transport);
      final now = DateTime.now();
      await RecurringExpenseService().addRecurringExpense(
        RecurringExpense(
          id: 'bus',
          name: 'Bus',
          description: 'ida y vuelta',
          amount: 9,
          category: ExpenseCategory.transport,
          frequency: RecurrenceFrequency.daily,
          startDate: DateTime(now.year, now.month, now.day - 1),
          createdAt: now,
          accountId: accounts.activeAccountId,
        ),
      );
      await RecurringExpenseService().processRecurringExpensesForToday();
      expect((await drain()).single.level, BudgetAlertLevel.threshold);
    });
  });

  group('Estado de la tarjeta', () {
    Budget budget({double threshold = 0.8, bool enabled = true}) {
      final now = DateTime.now();
      return Budget(
        name: 'X',
        amount: 100,
        period: BudgetPeriod.monthly,
        category: ExpenseCategory.food,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        alertThreshold: threshold,
        alertsEnabled: enabled,
        createdAt: now,
        accountId: 'a',
      );
    }

    test('con el 80 % por defecto los estados no cambian', () {
      final b = budget();
      expect(b.getStatus(69), BudgetStatus.safe);
      expect(b.getStatus(70), BudgetStatus.warning);
      expect(b.getStatus(90), BudgetStatus.danger);
      expect(b.getStatus(100), BudgetStatus.exceeded);
    });

    test('con alerta al 50 % el 60 % ya es "cuidado"', () {
      expect(budget(threshold: 0.5).getStatus(60), BudgetStatus.warning);
      expect(budget(threshold: 0.5).getStatus(49), BudgetStatus.safe);
      // Con las alertas apagadas se usa el criterio general.
      expect(
        budget(threshold: 0.5, enabled: false).getStatus(60),
        BudgetStatus.safe,
      );
    });
  });
}
