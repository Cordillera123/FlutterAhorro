import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/category_service.dart';
import 'package:ahorro_app/services/stats_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';
import 'package:ahorro_app/utils/format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String accountId;
  final stats = StatsService();
  final transactions = TransactionService();
  final categories = CategoryService();

  var counter = 0;
  Transaction expense(
    double amount, {
    ExpenseCategory? system,
    String? customId,
    String? customName,
    String? customEmoji,
    DateTime? date,
    TransactionType type = TransactionType.expense,
  }) {
    counter++;
    return Transaction(
      id: 'tx_$counter',
      amount: amount,
      type: type,
      description: 'mov $counter',
      date: date ?? DateTime.now(),
      expenseCategory: system,
      customCategoryId: customId,
      customCategoryName: customName,
      customCategoryEmoji: customEmoji,
      accountId: accountId,
    );
  }

  Transaction income(double amount, {DateTime? date}) {
    counter++;
    return Transaction(
      id: 'tx_$counter',
      amount: amount,
      type: TransactionType.income,
      description: 'ingreso $counter',
      date: date ?? DateTime.now(),
      incomeCategory: IncomeCategory.salary,
      accountId: accountId,
    );
  }

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AccountService().loadAccounts();
    accountId = AccountService().activeAccountId;
    await categories.loadCategories();
  });

  setUp(() async {
    await transactions.clearAllTransactions();
  });

  group('Estadísticas por categoría incluyen las categorías personalizadas', () {
    test('Caso 1: una categoría nueva con gastos aparece en el gráfico/lista', () async {
      final pets = await categories.addCategory(name: 'Mascotas', emoji: '🐶');

      await transactions.addTransaction(
        expense(70, system: ExpenseCategory.food),
      );
      await transactions.addTransaction(
        expense(
          30,
          customId: pets.id,
          customName: pets.name,
          customEmoji: pets.emoji,
        ),
      );

      final result = stats.getCategoryStats();

      expect(result.length, 2);
      final custom = result.firstWhere((c) => c.customCategoryId == pets.id);
      expect(custom.categoryName, 'Mascotas');
      expect(custom.categoryIcon, '🐶');
      expect(custom.amount, 30);
      expect(custom.category, isNull);
      expect(custom.percentage, closeTo(30, 0.0001));
      // Ordenadas de mayor a menor gasto.
      expect(result.first.categoryName, 'Alimentación');
    });

    test('Caso 2: la suma de categorías coincide con el total de gastos', () async {
      final travel = await categories.addCategory(name: 'Viajes', emoji: '✈️');
      // El id de una categoría es `custom_<milisegundo>`: se separan para que
      // no colisionen (en la app real las crea una persona, nunca en el mismo ms).
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final gym = await categories.addCategory(name: 'Gimnasio', emoji: '🏋️');

      await transactions.addTransaction(expense(12.5, system: ExpenseCategory.food));
      await transactions.addTransaction(expense(7.25, system: ExpenseCategory.transport));
      await transactions.addTransaction(expense(3, system: ExpenseCategory.food));
      await transactions.addTransaction(
        expense(20000000, customId: travel.id, customName: 'Viajes', customEmoji: '✈️'),
      );
      await transactions.addTransaction(
        expense(32.45, customId: gym.id, customName: 'Gimnasio', customEmoji: '🏋️'),
      );
      // Un ingreso y una transferencia NO son gastos.
      await transactions.addTransaction(income(11));
      await transactions.addTransaction(
        expense(999, type: TransactionType.transfer),
      );

      final result = stats.getCategoryStats();
      final sumAmounts = result.fold<double>(0, (s, c) => s + c.amount);
      final sumPercent = result.fold<double>(0, (s, c) => s + c.percentage);
      final monthly = stats.getCurrentVsPreviousStats();

      expect(result.length, 4);
      expect(sumAmounts, closeTo(20000055.2, 0.0001));
      expect(sumAmounts, closeTo(monthly.currentExpenses, 0.0001));
      expect(sumPercent, closeTo(100, 0.0001));
    });

    test('una categoría que ya no tiene gastos en el mes no aparece', () async {
      final now = DateTime.now();
      final lastMonth = DateTime(now.year, now.month - 1, 15);
      final cat = await categories.addCategory(name: 'Pasatiempos', emoji: '🎨');

      await transactions.addTransaction(
        expense(40, customId: cat.id, customName: cat.name, customEmoji: cat.emoji, date: lastMonth),
      );

      expect(stats.getCategoryStats(), isEmpty);
      final previous = stats.getCategoryStats(month: lastMonth);
      expect(previous.single.categoryName, 'Pasatiempos');
    });

    test('si la categoría personalizada ya no existe se usa el nombre guardado', () async {
      await transactions.addTransaction(
        expense(15, customId: 'custom_borrada', customName: 'Café', customEmoji: '☕'),
      );

      final result = stats.getCategoryStats();
      expect(result.single.categoryName, 'Café');
      expect(result.single.categoryIcon, '☕');
    });

    test('un gasto sin ninguna categoría cae en "Otros" y el total cuadra', () async {
      await transactions.addTransaction(expense(10));
      await transactions.addTransaction(expense(5, system: ExpenseCategory.other));

      final result = stats.getCategoryStats();
      expect(result.length, 1);
      expect(result.single.categoryName, 'Otros');
      expect(result.single.amount, 15);
    });

    test('el desglose del historial mensual también incluye personalizadas', () async {
      final cat = await categories.addCategory(name: 'Regalos extra', emoji: '🎀');
      await transactions.addTransaction(income(100));
      await transactions.addTransaction(
        expense(60, customId: cat.id, customName: cat.name, customEmoji: cat.emoji),
      );
      await transactions.addTransaction(expense(10, system: ExpenseCategory.food));

      final current = stats.getMonthlyStatsHistory(months: 1).single;
      expect(current.topExpenseCategory?.categoryName, 'Regalos extra');
      expect(current.categoryBreakdown.values.fold<double>(0, (a, b) => a + b), 70);
    });
  });

  group('Porcentajes', () {
    test('tryCalculateGrowthPercentage: sin base comparable devuelve null', () {
      expect(FormatUtils.tryCalculateGrowthPercentage(100, 0), isNull);
      expect(FormatUtils.tryCalculateGrowthPercentage(0, 0), isNull);
      expect(FormatUtils.tryCalculateGrowthPercentage(100, 0.001), isNull);
      expect(FormatUtils.tryCalculateGrowthPercentage(double.nan, 10), isNull);
      expect(FormatUtils.tryCalculateGrowthPercentage(10, double.infinity), isNull);
    });

    test('tryCalculateGrowthPercentage: cálculos normales', () {
      expect(FormatUtils.tryCalculateGrowthPercentage(150, 100), closeTo(50, 1e-9));
      expect(FormatUtils.tryCalculateGrowthPercentage(50, 100), closeTo(-50, 1e-9));
      // Balance negativo que mejora: la variación es positiva.
      expect(FormatUtils.tryCalculateGrowthPercentage(-50, -100), closeTo(50, 1e-9));
    });

    test('Caso 6: variación contra un mes anterior con \$0 es null ("Nuevo")', () async {
      await transactions.addTransaction(income(200));
      await transactions.addTransaction(expense(50, system: ExpenseCategory.food));

      final s = stats.getCurrentVsPreviousStats();
      expect(s.incomeGrowthPercentage, isNull);
      expect(s.expenseGrowthPercentage, isNull);
      expect(FormatUtils.formatGrowthLabel(s.incomeGrowthPercentage, current: s.currentIncome), 'Nuevo');
      expect(FormatUtils.formatGrowthLabel(null, current: 0), '—');
    });

    test('variación con mes anterior con datos se calcula', () async {
      final now = DateTime.now();
      await transactions.addTransaction(income(100, date: DateTime(now.year, now.month - 1, 10)));
      await transactions.addTransaction(income(150));

      final s = stats.getCurrentVsPreviousStats();
      expect(s.incomeGrowthPercentage, closeTo(50, 1e-9));
    });

    test('el -181818376,8% del reporte es la tasa de ahorro con ingresos de 11', () async {
      await transactions.addTransaction(income(11));
      await transactions.addTransaction(expense(20000032.45, system: ExpenseCategory.other));

      final month = stats.getMonthlyStatsHistory(months: 1).single;
      // balance / ingresos × 100: matemáticamente correcto con esos datos...
      expect(month.savingsRate, closeTo(-181818376.8, 0.1));
      // ...pero ilegible, así que la UI lo presenta acotado sin tocar el valor.
      expect(FormatUtils.formatPercentageCapped(month.savingsRate!, signed: true), '<-999%');
    });

    test('sin ingresos no hay tasa de ahorro (null, no "0.0%")', () async {
      await transactions.addTransaction(expense(30, system: ExpenseCategory.food));

      final month = stats.getMonthlyStatsHistory(months: 1).single;
      expect(month.income, 0);
      expect(month.savingsRate, isNull);
    });

    test('mes sin transacciones: todo en cero y sin porcentajes', () {
      final month = stats.getMonthlyStatsHistory(months: 1).single;
      expect(month.transactionCount, 0);
      expect(month.savingsRate, isNull);
      expect(stats.getCategoryStats(), isEmpty);
    });

    test('formatPercentageCapped', () {
      expect(FormatUtils.formatPercentageCapped(12.34), '12.3%');
      expect(FormatUtils.formatPercentageCapped(5, signed: true), '+5.0%');
      expect(FormatUtils.formatPercentageCapped(-5, signed: true), '-5.0%');
      expect(FormatUtils.formatPercentageCapped(-0.04, signed: true), '0.0%');
      expect(FormatUtils.formatPercentageCapped(999), '999.0%');
      expect(FormatUtils.formatPercentageCapped(1234), '>999%');
      expect(FormatUtils.formatPercentageCapped(-181818376.8), '<-999%');
      expect(FormatUtils.formatPercentageCapped(double.nan), '—');
      expect(FormatUtils.formatPercentageCapped(double.infinity), '—');
    });
  });

  group('Validación de montos', () {
    test('parseAmount ignora NaN / Infinity', () {
      expect(FormatUtils.parseAmount('NaN'), 0.0);
      expect(FormatUtils.parseAmount('Infinity'), 0.0);
      expect(FormatUtils.parseAmount('-Infinity'), 0.0);
      expect(FormatUtils.parseAmount('1,000.50'), 1000.5);
    });

    test('el servicio rechaza montos no finitos o no positivos', () async {
      expect(() => transactions.addTransaction(expense(double.nan)), throwsArgumentError);
      expect(() => transactions.addTransaction(expense(double.infinity)), throwsArgumentError);
      expect(() => transactions.addTransaction(expense(0)), throwsArgumentError);
      expect(() => transactions.addTransaction(expense(-5)), throwsArgumentError);
      expect(transactions.allTransactions, isEmpty);
    });

    test('Caso 5: montos altos se guardan, suman y no rompen el balance', () async {
      for (final amount in [1000.0, 10000.0, 100000.0, 1000000.0, 20000032.45]) {
        await transactions.addTransaction(income(amount));
      }
      final total = 1000 + 10000 + 100000 + 1000000 + 20000032.45;
      expect(transactions.totalIncome, closeTo(total, 0.001));
      expect(transactions.totalBalance.isFinite, isTrue);
      // intl separa el símbolo con un espacio no separable (U+00A0).
      expect(FormatUtils.formatMoney(20000032.45), '20.000.032,45 \$');
    });
  });
}
