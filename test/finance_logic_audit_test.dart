import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/account.dart';
import 'package:ahorro_app/models/budget.dart';
import 'package:ahorro_app/models/custom_category.dart';
import 'package:ahorro_app/models/recurring_expense.dart';
import 'package:ahorro_app/models/region.dart';
import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/budget_service.dart';
import 'package:ahorro_app/services/calendar_service.dart';
import 'package:ahorro_app/services/category_service.dart';
import 'package:ahorro_app/services/goal_service.dart';
import 'package:ahorro_app/services/recurring_expense_service.dart';
import 'package:ahorro_app/services/region_service.dart';
import 'package:ahorro_app/services/stats_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';
import 'package:ahorro_app/utils/format_utils.dart';
import 'package:ahorro_app/widgets/common/amount_input_formatter.dart';

/// Auditoría de la lógica de negocio, dato por dato:
/// VALOR INICIAL → OPERACIÓN → VALOR ESPERADO → otras pantallas
/// (balance, historial, estadísticas, categoría, presupuesto, calendario)
/// → persistencia.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final accounts = AccountService();
  final transactions = TransactionService();
  final budgets = BudgetService();
  final stats = StatsService();
  final categories = CategoryService();
  final recurring = RecurringExpenseService();

  var seq = 0;
  Transaction tx({
    required double amount,
    TransactionType type = TransactionType.expense,
    ExpenseCategory? category = ExpenseCategory.food,
    IncomeCategory? incomeCategory,
    DateTime? date,
    String? customId,
    String? customName,
    String description = 'Movimiento',
  }) {
    seq++;
    return Transaction(
      id: 'audit_$seq',
      amount: amount,
      type: type,
      description: description,
      date: date ?? DateTime.now(),
      expenseCategory: type == TransactionType.expense && customId == null
          ? category
          : null,
      incomeCategory: type == TransactionType.income
          ? (incomeCategory ?? IncomeCategory.salary)
          : null,
      customCategoryId: customId,
      customCategoryName: customName,
      accountId: accounts.activeAccountId,
    );
  }

  Transaction stored(String id) =>
      transactions.allTransactions.firstWhere((t) => t.id == id);

  Future<void> restart() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await accounts.loadAccounts();
    await transactions.loadTransactions();
    await categories.loadCategories();
    await budgets.loadBudgets();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GoalService().loadGoals();
    await accounts.loadAccounts();
    await accounts.updateInitialBalance(accounts.activeAccountId, 1000);
    await transactions.loadTransactions();
    await categories.loadCategories();
    await budgets.loadBudgets();
    await recurring.loadRecurringExpenses();
    await RegionService().setRegion(Region.ecuador);
  });

  group('Gastos: balance / historial / estadísticas / categoría', () {
    test('saldo 1.000 → gasto 100 → editar 150 → eliminar', () async {
      final now = DateTime.now();
      final g = tx(amount: 100, category: ExpenseCategory.food);

      await transactions.addTransaction(g);
      expect(transactions.totalBalance, 900);
      expect(transactions.transactions, hasLength(1));
      expect(stats.getCurrentVsPreviousStats().currentExpenses, 100);
      expect(stats.getCategoryStats().single.amount, 100);
      expect(stats.getCategoryStats().single.percentage, 100);
      expect(CalendarService().getDayData(now).totalExpense, 100);

      await transactions.updateTransaction(stored(g.id).copyWith(amount: 150));
      expect(transactions.totalBalance, 850);
      expect(stored(g.id).amount, 150);
      expect(stats.getCurrentVsPreviousStats().currentExpenses, 150);
      expect(stats.getCategoryStats().single.amount, 150);
      expect(CalendarService().getDayData(now).totalExpense, 150);

      await restart();
      expect(stored(g.id).amount, 150);
      expect(transactions.totalBalance, 850);

      await transactions.deleteTransaction(g.id);
      expect(transactions.totalBalance, 1000);
      expect(transactions.transactions, isEmpty);
      expect(stats.getCategoryStats(), isEmpty);
      expect(stats.getCurrentVsPreviousStats().currentExpenses, 0);
      expect(CalendarService().getDayData(now).totalExpense, 0);

      await restart();
      expect(transactions.transactions, isEmpty);
    });

    test('cambiar la categoría de un gasto mueve el total entre categorías', () async {
      final g = tx(amount: 80, category: ExpenseCategory.food);
      await transactions.addTransaction(g);
      await transactions.updateTransaction(
        stored(g.id).copyWith(expenseCategory: ExpenseCategory.transport),
      );
      final byCategory = {
        for (final s in stats.getCategoryStats()) s.category: s.amount,
      };
      expect(byCategory, {ExpenseCategory.transport: 80});
    });

    test('suma de categorías = total de gastos y porcentajes = 100 %', () async {
      final custom = await categories.addCategory(name: 'Mascotas', emoji: '🐶');
      await transactions.addTransaction(tx(amount: 33.33));
      await transactions.addTransaction(
        tx(amount: 66.67, category: ExpenseCategory.transport),
      );
      await transactions.addTransaction(
        tx(amount: 12.5, customId: custom.id, customName: custom.name),
      );
      await transactions.addTransaction(
        tx(amount: 500, type: TransactionType.income),
      );

      final list = stats.getCategoryStats();
      final total = stats.getCurrentVsPreviousStats().currentExpenses;
      expect(total, closeTo(112.5, 1e-9));
      expect(
        list.fold<double>(0, (s, c) => s + c.amount),
        closeTo(total, 1e-9),
      );
      expect(
        list.fold<double>(0, (s, c) => s + c.percentage),
        closeTo(100, 1e-9),
      );
      expect(list.every((c) => c.percentage.isFinite), isTrue);
      // La categoría nueva aparece con su nombre (no hay listas fijas).
      expect(list.map((c) => c.categoryName), contains('Mascotas'));
      // Ordenadas de mayor a menor.
      expect(list.first.amount, 66.67);
    });

    test('renombrar una categoría personalizada se refleja en estadísticas', () async {
      final custom = await categories.addCategory(name: 'Gym', emoji: '🏋️');
      await transactions.addTransaction(
        tx(amount: 20, customId: custom.id, customName: custom.name),
      );
      await categories.updateCategory(id: custom.id, name: 'Gimnasio', emoji: '💪');
      final s = stats.getCategoryStats().single;
      expect(s.categoryName, 'Gimnasio');
      expect(s.categoryIcon, '💪');
    });

    test('eliminar una categoría reasigna sus gastos a "Otros"', () async {
      final custom = await categories.addCategory(name: 'Club', emoji: '⚽');
      final g = tx(amount: 40, customId: custom.id, customName: custom.name);
      await transactions.addTransaction(g);

      await categories.deleteCategory(custom.id);

      expect(stored(g.id).expenseCategory, ExpenseCategory.other);
      expect(stored(g.id).customCategoryId, isNull);
      expect(stats.getCategoryStats().single.category, ExpenseCategory.other);
      expect(transactions.totalBalance, 960);
    });
  });

  group('Ingresos', () {
    test('crear → aumentar → disminuir → eliminar', () async {
      final i = tx(amount: 500, type: TransactionType.income);
      await transactions.addTransaction(i);
      expect(transactions.totalBalance, 1500);
      expect(stats.getCurrentVsPreviousStats().currentIncome, 500);

      await transactions.updateTransaction(stored(i.id).copyWith(amount: 800));
      expect(transactions.totalBalance, 1800);
      expect(stats.getCurrentVsPreviousStats().currentIncome, 800);

      await transactions.updateTransaction(stored(i.id).copyWith(amount: 200));
      expect(transactions.totalBalance, 1200);

      await restart();
      expect(stored(i.id).amount, 200);

      await transactions.deleteTransaction(i.id);
      expect(transactions.totalBalance, 1000);
      expect(stats.getCurrentVsPreviousStats().currentIncome, 0);
      // Un ingreso nunca aparece en el reparto de gastos.
      expect(stats.getCategoryStats(), isEmpty);
    });

    test('varios ingresos: editar uno y eliminar otro', () async {
      final a = tx(amount: 100, type: TransactionType.income);
      final b = tx(amount: 200, type: TransactionType.income);
      final c = tx(amount: 300, type: TransactionType.income);
      for (final t in [a, b, c]) {
        await transactions.addTransaction(t);
      }
      await transactions.updateTransaction(stored(b.id).copyWith(amount: 250));
      await transactions.deleteTransaction(c.id);

      expect(stats.getCurrentVsPreviousStats().currentIncome, 350);
      expect(transactions.totalBalance, 1350);
    });
  });

  group('Balance positivo / negativo y montos extremos', () {
    test('balance negativo se calcula y se formatea', () async {
      await transactions.addTransaction(tx(amount: 5000));
      expect(transactions.totalBalance, -4000);
      expect(FormatUtils.formatMoney(transactions.totalBalance), contains('4.000,00'));
      expect(FormatUtils.formatMoney(transactions.totalBalance), startsWith('-'));
    });

    test('ningún monto produce NaN/Infinity ni pierde decimales', () async {
      const values = [
        0.01,
        1.0,
        10.0,
        100.0,
        1000.0,
        10000.0,
        100000.0,
        1000000.0,
        10000000.0,
        20000032.45,
        999999999.99,
      ];
      for (final v in values) {
        await transactions.addTransaction(tx(amount: v));
        final text = FormatUtils.formatMoney(v);
        expect(text.contains('NaN') || text.contains('Infinity'), isFalse);
      }
      final total = values.reduce((a, b) => a + b);
      expect(
        stats.getCurrentVsPreviousStats().currentExpenses,
        closeTo(total, 0.001),
      );
      // intl separa el símbolo con un espacio duro (NBSP).
      expect(FormatUtils.formatMoney(20000032.45), '20.000.032,45\u00A0\$');
      expect(transactions.totalBalance.isFinite, isTrue);
    });

    test('monto 0, negativo o NaN se rechaza en el servicio', () async {
      for (final bad in [0.0, -1.0, double.nan, double.infinity]) {
        expect(
          () => transactions.addTransaction(tx(amount: bad)),
          throwsArgumentError,
        );
      }
      expect(transactions.allTransactions, isEmpty);
    });

    test('sin datos: estadísticas en 0 y sin porcentajes absurdos', () async {
      final s = stats.getCurrentVsPreviousStats();
      expect(s.currentIncome, 0);
      expect(s.currentExpenses, 0);
      expect(s.balanceGrowthPercentage, isNull);
      expect(stats.getCategoryStats(), isEmpty);
      expect(stats.getMonthlyComparison().monthsWithData, 0);
      expect(transactions.totalBalance, 1000);
      expect(FormatUtils.formatPercentageCapped(double.nan), '—');
      expect(FormatUtils.formatPercentageCapped(1e9), '>999%');
    });
  });

  group('Fechas y períodos', () {
    test('Diciembre → Enero: cada movimiento en su mes', () async {
      await transactions.addTransaction(
        tx(amount: 10, date: DateTime(2025, 12, 31, 23, 59)),
      );
      await transactions.addTransaction(
        tx(amount: 20, date: DateTime(2026, 1, 1, 0, 0)),
      );
      expect(stats.getMonthStats(DateTime(2025, 12)).expenses, 10);
      expect(stats.getMonthStats(DateTime(2026, 1)).expenses, 20);
      expect(
        CalendarService().getMonthData(DateTime(2025, 12)).totalExpense,
        10,
      );
      expect(CalendarService().getMonthData(DateTime(2026, 1)).totalExpense, 20);
      expect(
        CalendarService().getDayData(DateTime(2025, 12, 31)).totalExpense,
        10,
      );
    });

    test('"este mes" no incluye el último día del mes anterior', () async {
      final now = DateTime.now();
      final lastDayPrev = DateTime(now.year, now.month, 0, 15);
      await transactions.addTransaction(tx(amount: 7, date: lastDayPrev));
      await transactions.addTransaction(
        tx(amount: 3, date: DateTime(now.year, now.month, 1, 0, 0)),
      );
      expect(transactions.thisMonthTransactions.map((t) => t.amount), [3]);
      expect(stats.getCurrentVsPreviousStats().currentExpenses, 3);
      expect(stats.getCurrentVsPreviousStats().previousExpenses, 7);
    });

    test('semanas: ningún movimiento cuenta en dos semanas', () async {
      final now = DateTime.now();
      final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
      final dates = [
        DateTime(monday.year, monday.month, monday.day), // lunes 00:00
        DateTime(monday.year, monday.month, monday.day - 1, 23, 30), // dom
        DateTime(monday.year, monday.month, monday.day - 7, 12), // lunes ant.
        DateTime(monday.year, monday.month, monday.day - 8, 18), // dom ant.
      ];
      for (final d in dates) {
        await transactions.addTransaction(tx(amount: 1, date: d));
      }
      final weeks = stats.getWeeklyStats();
      expect(weeks.fold<double>(0, (s, w) => s + w.expenses), 4);
      expect(weeks.last.expenses, 1); // semana actual: solo el lunes
      expect(weeks[2].expenses, 2); // semana anterior: lunes + domingo
      expect(weeks.last.weekStart, monday);
    });

    test('el calendario coincide con el historial día por día', () async {
      final now = DateTime.now();
      final day1 = DateTime(now.year, now.month, 1, 9);
      await transactions.addTransaction(tx(amount: 50, date: day1));
      await transactions.addTransaction(
        tx(amount: 120, type: TransactionType.income, date: day1),
      );
      await transactions.addTransaction(tx(amount: 30, date: now));

      final month = CalendarService().getMonthData(now);
      final monthTx = transactions.transactions.where(
        (t) => t.date.year == now.year && t.date.month == now.month,
      );
      expect(month.movementCount, monthTx.length);
      expect(
        month.totalExpense,
        stats.getCurrentVsPreviousStats().currentExpenses,
      );
      expect(month.totalIncome, stats.getCurrentVsPreviousStats().currentIncome);
      final d1 = CalendarService().getDayData(day1);
      expect(d1.totalIncome, 120);
      expect(d1.totalExpense, now.day == 1 ? 80 : 50);
    });
  });

  group('Presupuestos', () {
    Future<Budget> createBudget({
      double amount = 500,
      ExpenseCategory category = ExpenseCategory.food,
      BudgetPeriod period = BudgetPeriod.monthly,
      CustomCategory? custom,
    }) async {
      final dates = BudgetService.generateBudgetDates(period, DateTime.now());
      await budgets.addBudget(
        Budget(
          name: 'Presupuesto ${budgets.budgets.length}',
          amount: amount,
          period: period,
          category: custom != null ? ExpenseCategory.other : category,
          customCategoryId: custom?.id,
          customCategoryName: custom?.name,
          customCategoryEmoji: custom?.emoji,
          startDate: dates['start']!,
          endDate: dates['end']!,
          createdAt: DateTime.now(),
          accountId: accounts.activeAccountId,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return budgets.budgets.first;
    }

    test('500: gasto 100 → editar 250 → eliminar', () async {
      final b = await createBudget(amount: 500);
      final g = tx(amount: 100);
      await transactions.addTransaction(g);

      var p = budgets.getBudgetProgress(b);
      expect(p.spentAmount, 100);
      expect(p.remainingAmount, 400);
      expect(p.usedFraction, closeTo(0.20, 1e-9));
      expect(p.status, BudgetStatus.safe);

      await transactions.updateTransaction(stored(g.id).copyWith(amount: 250));
      p = budgets.getBudgetProgress(b);
      expect(p.spentAmount, 250);
      expect(p.remainingAmount, 250);
      expect(p.usedFraction, closeTo(0.50, 1e-9));

      await transactions.deleteTransaction(g.id);
      p = budgets.getBudgetProgress(b);
      expect(p.spentAmount, 0);
      expect(p.remainingAmount, 500);
      expect(p.usedFraction, 0);
    });

    test('estados: 69 % seguro, 70 % alerta, 90 % peligro, 100 % excedido', () async {
      final b = await createBudget(amount: 100);
      final g = tx(amount: 69);
      await transactions.addTransaction(g);
      expect(budgets.getBudgetProgress(b).status, BudgetStatus.safe);
      for (final (amount, status) in [
        (70.0, BudgetStatus.warning),
        (90.0, BudgetStatus.danger),
        (100.0, BudgetStatus.exceeded),
      ]) {
        await transactions.updateTransaction(
          stored(g.id).copyWith(amount: amount),
        );
        expect(budgets.getBudgetProgress(b).status, status, reason: '$amount');
      }
    });

    test('gasto mayor al presupuesto: 150 %, restante negativo', () async {
      final b = await createBudget(amount: 500);
      await transactions.addTransaction(tx(amount: 750));
      final p = budgets.getBudgetProgress(b);
      expect(p.usedFraction, closeTo(1.5, 1e-9));
      expect(p.percentage, 1.0); // la barra no pasa del 100 %
      expect(p.remainingAmount, -250);
      expect(p.status, BudgetStatus.exceeded);
      expect(p.progressMessage, contains('250,00'));
    });

    test('muchos gastos pequeños: 100 × 0,01 = 1,00 exacto', () async {
      final b = await createBudget(amount: 2);
      for (var i = 0; i < 100; i++) {
        await transactions.addTransaction(tx(amount: 0.01));
      }
      final p = budgets.getBudgetProgress(b);
      expect(p.spentAmount, 1.0);
      expect(p.usedFraction, 0.5);
    });

    test('solo cuenta su categoría, gastos (no ingresos) y su período', () async {
      final now = DateTime.now();
      final b = await createBudget(amount: 1000);
      final firstDay = DateTime(now.year, now.month, 1);
      final lastDay = DateTime(now.year, now.month + 1, 0);
      await transactions.addTransaction(tx(amount: 1, date: firstDay));
      await transactions.addTransaction(
        tx(amount: 2, date: DateTime(lastDay.year, lastDay.month, lastDay.day, 23, 59)),
      );
      // Fuera del período: último día del mes anterior y 1° del siguiente.
      await transactions.addTransaction(
        tx(amount: 400, date: DateTime(now.year, now.month, 0, 12)),
      );
      await transactions.addTransaction(
        tx(amount: 800, date: DateTime(now.year, now.month + 1, 1)),
      );
      // Otra categoría e ingreso.
      await transactions.addTransaction(
        tx(amount: 50, category: ExpenseCategory.transport),
      );
      await transactions.addTransaction(
        tx(amount: 60, type: TransactionType.income),
      );

      expect(budgets.getBudgetProgress(b).spentAmount, 3);
    });

    test('presupuesto de categoría nueva (personalizada)', () async {
      final custom = await categories.addCategory(name: 'Café', emoji: '☕');
      final b = await createBudget(amount: 50, custom: custom);
      await transactions.addTransaction(
        tx(amount: 12, customId: custom.id, customName: custom.name),
      );
      // Un gasto "Otros" del sistema no cuenta para la personalizada.
      await transactions.addTransaction(
        tx(amount: 30, category: ExpenseCategory.other),
      );
      expect(budgets.getBudgetProgress(b).spentAmount, 12);
    });

    test('presupuesto de 0 no da NaN', () {
      final now = DateTime.now();
      final b = Budget(
        name: 'Cero',
        amount: 0,
        period: BudgetPeriod.monthly,
        category: ExpenseCategory.food,
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0),
        createdAt: now,
        accountId: accounts.activeAccountId,
      );
      final p = BudgetProgress(budget: b, spentAmount: 0, transactions: []);
      expect(p.percentage, 0);
      expect(p.usedFraction, 0);
      final spent = BudgetProgress(budget: b, spentAmount: 5, transactions: []);
      expect(spent.percentage, 1.0);
      expect(spent.status, BudgetStatus.safe); // getStatus: amount 0 → 0 %
    });

    test('el último día del período todavía cuenta como día restante', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final b = Budget(
        name: 'Hoy termina',
        amount: 100,
        period: BudgetPeriod.monthly,
        category: ExpenseCategory.food,
        startDate: DateTime(now.year, now.month, 1),
        endDate: today,
        createdAt: now,
        accountId: accounts.activeAccountId,
      );
      expect(b.daysRemaining, 1);
      expect(b.needsReset, isFalse);
    });

    test('dos semanales de la misma categoría y semana son duplicados', () async {
      await createBudget(period: BudgetPeriod.weekly);
      await expectLater(
        createBudget(period: BudgetPeriod.weekly),
        throwsException,
      );
      final b = budgets.budgets.single;
      expect(b.startDate.hour, 0);
      expect(b.startDate.weekday, DateTime.monday);
      expect(b.endDate.weekday, DateTime.sunday);
    });

    test('reinicio automático: el período vencido pasa al actual', () async {
      final now = DateTime.now();
      await budgets.addBudget(
        Budget(
          name: 'Viejo',
          amount: 300,
          period: BudgetPeriod.monthly,
          category: ExpenseCategory.food,
          startDate: DateTime(now.year, now.month - 2, 1),
          endDate: DateTime(now.year, now.month - 1, 0),
          createdAt: DateTime(now.year, now.month - 2, 1),
          accountId: accounts.activeAccountId,
        ),
      );
      await transactions.addTransaction(
        tx(amount: 99, date: DateTime(now.year, now.month - 2, 10)),
      );
      await transactions.addTransaction(tx(amount: 10));

      await budgets.processAutomaticResets();
      final b = budgets.budgets.single;
      expect(b.startDate, DateTime(now.year, now.month, 1));
      expect(b.endDate, DateTime(now.year, now.month + 1, 0));
      // Lo gastado se recalcula para el período nuevo.
      expect(budgets.getBudgetProgress(b).spentAmount, 10);

      await restart();
      expect(budgets.budgets.single.startDate, DateTime(now.year, now.month, 1));
    });
  });

  group('Gastos automáticos', () {
    RecurringExpense daily(String id, {String? accountId, double amount = 5}) {
      final now = DateTime.now();
      return RecurringExpense(
        id: id,
        name: 'Bus $id',
        description: 'ida',
        amount: amount,
        category: ExpenseCategory.transport,
        frequency: RecurrenceFrequency.daily,
        startDate: DateTime(now.year, now.month, now.day - 1),
        createdAt: now,
        accountId: accountId ?? accounts.activeAccountId,
      );
    }

    test('procesar dos veces a la vez no duplica movimientos', () async {
      await recurring.addRecurringExpense(daily('r1'));
      await recurring.addRecurringExpense(daily('r2'));

      final results = await Future.wait([
        recurring.processRecurringExpensesForToday(),
        recurring.processRecurringExpensesForToday(),
      ]);
      expect(results.first, hasLength(2));
      expect(transactions.allTransactions, hasLength(2));
      // Cada movimiento con su propio id.
      expect(transactions.allTransactions.map((t) => t.id).toSet(), hasLength(2));

      // Y una tercera vez (otro día de uso de la app) tampoco.
      await recurring.loadRecurringExpenses();
      expect(await recurring.processRecurringExpensesForToday(), isEmpty);
      expect(transactions.allTransactions, hasLength(2));
      expect(transactions.totalBalance, 990);
    });

    test('crear, editar, pausar, reactivar y eliminar persisten', () async {
      await recurring.addRecurringExpense(daily('r1'));
      await recurring.updateRecurringExpense(
        recurring.recurringExpenses.single.copyWith(amount: 7.5),
      );
      await recurring.toggleRecurringExpense('r1');
      await recurring.loadRecurringExpenses();
      expect(recurring.recurringExpenses.single.amount, 7.5);
      expect(recurring.recurringExpenses.single.isActive, isFalse);
      expect(await recurring.processRecurringExpensesForToday(), isEmpty);

      await recurring.toggleRecurringExpense('r1');
      expect(recurring.activeRecurringExpenses, hasLength(1));

      await recurring.deleteRecurringExpense('r1');
      await recurring.loadRecurringExpenses();
      expect(recurring.recurringExpenses, isEmpty);
      expect(recurring.getRecurringExpensesSummary()['estimatedMonthly'], 0);
    });

    test('al eliminar una cuenta se eliminan sus gastos automáticos', () async {
      final work = await accounts.addAccount(
        name: 'Trabajo',
        type: AccountType.work,
      );
      await recurring.addRecurringExpense(daily('r_work', accountId: work.id));
      await recurring.addRecurringExpense(daily('r_main'));

      await accounts.deleteAccount(work.id);
      await recurring.loadRecurringExpenses();

      expect(
        recurring.allRecurringExpenses.map((e) => e.id),
        ['r_main'],
      );
      await recurring.processRecurringExpensesForToday();
      // Solo el de la cuenta que sigue existiendo.
      expect(transactions.allTransactions, hasLength(1));
      expect(transactions.allTransactions.single.description, 'Bus r_main - ida');
    });
  });

  group('Categorías', () {
    test('no se duplica un nombre por espacios al final', () async {
      await categories.addCategory(name: 'Mascotas', emoji: '🐶');
      await expectLater(
        categories.addCategory(name: 'Mascotas  ', emoji: '🐱'),
        throwsException,
      );
      final created = await categories.addCategory(name: '  Hogar2 ', emoji: '🏡');
      expect(created.name, 'Hogar2');
    });

    test('ids únicos aunque se creen en el mismo milisegundo', () {
      final a = CustomCategory.generateId();
      final b = CustomCategory.generateId(existingIds: {a});
      expect(b, isNot(a));
      expect(b.startsWith('custom_'), isTrue);
    });

    test('ids de transacción únicos', () async {
      final ids = <String>{};
      for (var i = 0; i < 20; i++) {
        final id = transactions.generateId();
        ids.add(id);
        await transactions.addTransaction(
          Transaction(
            id: id,
            amount: 1,
            type: TransactionType.expense,
            description: 'x',
            date: DateTime.now(),
            expenseCategory: ExpenseCategory.food,
            accountId: accounts.activeAccountId,
          ),
        );
      }
      expect(ids, hasLength(20));
    });
  });

  group('Campo de monto (coma o punto decimal)', () {
    TextEditingValue type(String text, {String old = ''}) =>
        const AmountInputFormatter().formatEditUpdate(
          TextEditingValue(text: old),
          TextEditingValue(text: text),
        );

    test('la coma se convierte en punto (antes "10,50" quedaba en 1050)', () {
      expect(type('10,').text, '10.');
      expect(type('10,50').text, '10.50');
      expect(double.parse(type('10,50').text), 10.5);
    });

    test('rechaza lo que no es un monto válido', () {
      expect(type('1,234.50', old: '1').text, '1'); // dos separadores
      expect(type('10.505', old: '10.50').text, '10.50'); // 3 decimales
      expect(type('abc', old: '').text, '');
      expect(type('-5', old: '').text, '');
      expect(type('1000000000', old: '100000000').text, '100000000'); // tope
      expect(type('999999999.99').text, '999999999.99');
    });

    test('con los filtros de cada formulario la coma no se pierde', () {
      // Mismo orden que en Agregar transacción.
      final formatters = <TextInputFormatter>[
        const AmountInputFormatter(),
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        LengthLimitingTextInputFormatter(13),
      ];
      var value = const TextEditingValue();
      for (final next in ['1', '10', '10,', '10,5', '10,50']) {
        var candidate = TextEditingValue(text: '${value.text}${next.substring(value.text.length)}');
        for (final f in formatters) {
          candidate = f.formatEditUpdate(value, candidate);
        }
        value = candidate;
      }
      expect(value.text, '10.50');
    });
  });
}
