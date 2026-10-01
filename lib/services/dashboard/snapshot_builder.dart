import '../../models/account.dart';
import '../../models/budget.dart';
import '../../models/transaction.dart';
import '../../models/dashboard/dashboard_snapshot.dart';
import '../../models/dashboard/movement_record.dart';

/// Construye [DashboardSnapshot] en un único recorrido O(n).
class SnapshotBuilder {
  static int monthKey(DateTime date) => date.year * 100 + date.month;

  static int weekOfMonth(DateTime date) {
    return ((date.day - 1) ~/ 7) + 1;
  }

  static DashboardSnapshot build({
    required List<Transaction> transactions,
    required Account account,
    required List<Budget> activeBudgets,
    DateTime? referenceTime,
    int historyMonths = 12,
  }) {
    final now = referenceTime ?? DateTime.now();
    final referenceMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day;
    final currentKey = monthKey(referenceMonth);
    final previousKey = monthKey(DateTime(now.year, now.month - 1));

    final monthlyIncome = <int, double>{};
    final monthlyExpenses = <int, double>{};
    final monthlyCount = <int, int>{};

    final categoryAmounts = <String, double>{};
    final categoryNames = <String, String>{};
    final categoryEmojis = <String, String?>{};
    final categoryCounts = <String, int>{};

    final incomeAmounts = <String, double>{};
    final incomeNames = <String, String>{};
    final incomeCounts = <String, int>{};

    final expensesByDay = <int, double>{};
    final expensesByWeekday = <int, double>{};
    final incomeByWeekday = <int, double>{};
    final weekOfMonthExpenses = <int, double>{};
    final expensesByMonthAndCategory = <int, Map<String, double>>{};

    final budgetSpent = <String, double>{
      for (final budget in activeBudgets)
        if (budget.id != null) budget.id!: 0.0,
    };

    double totalBalance = account.initialBalance;
    DateTime? lastTransactionDate;
    final daysWithTxLast30 = <String>{};
    final daysWithAnyTx = <String>{};

    double incomeThisWeek = 0;
    double expensesThisWeek = 0;
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day,
    );

    final cutoff30 = now.subtract(const Duration(days: 30));
    final cutoffHistory = DateTime(now.year, now.month - historyMonths, 1);

    for (final transaction in transactions) {
      final date = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );
      final mKey = monthKey(date);

      // El balance real y la actividad ("¿usé la app hoy?") SÍ consideran
      // transferencias — mueven dinero de verdad y son una acción del
      // usuario, aunque no sean ingreso ni gasto.
      totalBalance = transaction.applyToBalance(totalBalance);

      if (lastTransactionDate == null || date.isAfter(lastTransactionDate)) {
        lastTransactionDate = date;
      }

      final dayKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      daysWithAnyTx.add(dayKey);
      if (!date.isBefore(cutoff30)) {
        daysWithTxLast30.add(dayKey);
      }

      // Las transferencias no son ingreso ni gasto: no deben distorsionar
      // ningún análisis de patrones de ingreso/gasto de aquí en adelante.
      if (transaction.type == TransactionType.transfer) continue;

      final record = MovementRecord.fromTransaction(transaction);

      if (!date.isBefore(weekStartDate) && !date.isAfter(now)) {
        if (record.isIncome) {
          incomeThisWeek += record.amount;
        } else {
          expensesThisWeek += record.amount;
        }
      }

      if (date.isBefore(cutoffHistory)) continue;

      monthlyCount[mKey] = (monthlyCount[mKey] ?? 0) + 1;

      if (record.isIncome) {
        monthlyIncome[mKey] = (monthlyIncome[mKey] ?? 0) + record.amount;
        incomeByWeekday[date.weekday] =
            (incomeByWeekday[date.weekday] ?? 0) + record.amount;

        incomeAmounts[record.categoryKey] =
            (incomeAmounts[record.categoryKey] ?? 0) + record.amount;
        incomeNames[record.categoryKey] = record.displayName;
        incomeCounts[record.categoryKey] =
            (incomeCounts[record.categoryKey] ?? 0) + 1;
      } else {
        monthlyExpenses[mKey] = (monthlyExpenses[mKey] ?? 0) + record.amount;
        expensesByWeekday[date.weekday] =
            (expensesByWeekday[date.weekday] ?? 0) + record.amount;

        categoryAmounts[record.categoryKey] =
            (categoryAmounts[record.categoryKey] ?? 0) + record.amount;
        categoryNames[record.categoryKey] = record.displayName;
        categoryEmojis[record.categoryKey] = record.emoji;
        categoryCounts[record.categoryKey] =
            (categoryCounts[record.categoryKey] ?? 0) + 1;

        expensesByMonthAndCategory
            .putIfAbsent(mKey, () => {})
            .update(
              record.categoryKey,
              (v) => v + record.amount,
              ifAbsent: () => record.amount,
            );

        if (mKey == currentKey) {
          expensesByDay[date.day] =
              (expensesByDay[date.day] ?? 0) + record.amount;
          final wom = weekOfMonth(date);
          weekOfMonthExpenses[wom] =
              (weekOfMonthExpenses[wom] ?? 0) + record.amount;
        }

        for (final budget in activeBudgets) {
          if (budget.id == null) continue;
          if (!_matchesBudget(record, budget, date)) continue;
          budgetSpent[budget.id!] =
              (budgetSpent[budget.id!] ?? 0) + record.amount;
        }
      }
    }

    int currentStreak = 0;
    var checkDate = DateTime(now.year, now.month, now.day);
    while (true) {
      final key =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (!daysWithAnyTx.contains(key)) break;
      currentStreak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    final monthlyHistory = <int, MonthAggregate>{};
    final allMonthKeys = {
      ...monthlyIncome.keys,
      ...monthlyExpenses.keys,
      ...monthlyCount.keys,
    };
    for (final key in allMonthKeys) {
      final income = monthlyIncome[key] ?? 0;
      final expenses = monthlyExpenses[key] ?? 0;
      monthlyHistory[key] = MonthAggregate(
        year: key ~/ 100,
        month: key % 100,
        income: income,
        expenses: expenses,
        savings: income - expenses,
        transactionCount: monthlyCount[key] ?? 0,
      );
    }

    final currentMonthIncome = monthlyIncome[currentKey] ?? 0;
    final currentMonthExpenses = monthlyExpenses[currentKey] ?? 0;
    final previousMonthIncome = monthlyIncome[previousKey] ?? 0;
    final previousMonthExpenses = monthlyExpenses[previousKey] ?? 0;

    final totalCurrentExpenses = currentMonthExpenses;
    final expensesByCategory = <String, CategoryAggregate>{};
    final currentMonthCategories = expensesByMonthAndCategory[currentKey] ?? {};
    currentMonthCategories.forEach((key, amount) {
      expensesByCategory[key] = CategoryAggregate(
        key: key,
        displayName: categoryNames[key] ?? key,
        emoji: categoryEmojis[key],
        amount: amount,
        percentageOfExpenses: totalCurrentExpenses > 0
            ? (amount / totalCurrentExpenses) * 100
            : 0,
        transactionCount: categoryCounts[key] ?? 0,
      );
    });

    final totalCurrentIncome = currentMonthIncome;
    final incomeBySource = <String, IncomeSourceAggregate>{};
    final currentIncomeByKey = <String, double>{};
    for (final t in transactions) {
      if (t.type != TransactionType.income) continue;
      if (monthKey(t.date) != currentKey) continue;
      final key = MovementRecord.categoryKeyFromTransaction(t);
      currentIncomeByKey[key] = (currentIncomeByKey[key] ?? 0) + t.amount;
      incomeNames[key] = t.categoryName;
    }
    currentIncomeByKey.forEach((key, amount) {
      incomeBySource[key] = IncomeSourceAggregate(
        key: key,
        displayName: incomeNames[key] ?? key,
        amount: amount,
        percentageOfIncome: totalCurrentIncome > 0
            ? (amount / totalCurrentIncome) * 100
            : 0,
        transactionCount: incomeCounts[key] ?? 0,
      );
    });

    final expensesByWeekOfMonth = <int, WeekOfMonthAggregate>{};
    weekOfMonthExpenses.forEach((week, amount) {
      expensesByWeekOfMonth[week] = WeekOfMonthAggregate(
        weekNumber: week,
        expenses: amount,
        percentageOfMonth: totalCurrentExpenses > 0
            ? (amount / totalCurrentExpenses) * 100
            : 0,
      );
    });

    MonthAggregate? bestSavings;
    MonthAggregate? worstSavings;
    for (final aggregate in monthlyHistory.values) {
      if (aggregate.transactionCount == 0) continue;
      if (bestSavings == null || aggregate.savings > bestSavings.savings) {
        bestSavings = aggregate;
      }
      if (worstSavings == null || aggregate.savings < worstSavings.savings) {
        worstSavings = aggregate;
      }
    }

    final prevDaysInMonth = DateTime(now.year, now.month, 0).day;
    final previousDailyAvg = previousMonthExpenses / prevDaysInMonth;

    final budgetProgress = activeBudgets
        .where((b) => b.id != null)
        .map(
          (b) => BudgetProgressSnapshot(
            budget: b,
            spentAmount: budgetSpent[b.id!] ?? 0,
          ),
        )
        .toList();

    final daysSinceLast = lastTransactionDate == null
        ? 999
        : DateTime(
            now.year,
            now.month,
            now.day,
          ).difference(lastTransactionDate).inDays;

    return DashboardSnapshot(
      accountId: account.id,
      generatedAt: now,
      referenceMonth: referenceMonth,
      daysElapsedInMonth: daysElapsed,
      daysInMonth: daysInMonth,
      currentMonthIncome: currentMonthIncome,
      currentMonthExpenses: currentMonthExpenses,
      currentMonthSavings: currentMonthIncome - currentMonthExpenses,
      previousMonthIncome: previousMonthIncome,
      previousMonthExpenses: previousMonthExpenses,
      previousMonthSavings: previousMonthIncome - previousMonthExpenses,
      totalBalance: totalBalance,
      totalTransactionCount: transactions.length,
      monthlyHistory: monthlyHistory,
      expensesByCategory: expensesByCategory,
      incomeBySource: incomeBySource,
      expensesByDayOfMonth: expensesByDay,
      expensesByWeekday: expensesByWeekday,
      incomeByWeekday: incomeByWeekday,
      expensesByWeekOfMonth: expensesByWeekOfMonth,
      expensesByMonthAndCategory: expensesByMonthAndCategory,
      dailyAverageExpense: daysElapsed > 0
          ? currentMonthExpenses / daysElapsed
          : 0,
      dailyAverageIncome: daysElapsed > 0
          ? currentMonthIncome / daysElapsed
          : 0,
      previousMonthDailyAverageExpense: previousDailyAvg,
      lastTransactionDate: lastTransactionDate,
      daysSinceLastTransaction: daysSinceLast,
      daysWithTransactionsLast30: daysWithTxLast30.length,
      currentStreakDays: currentStreak,
      bestSavingsMonth: bestSavings,
      worstSavingsMonth: worstSavings,
      budgetProgress: budgetProgress,
      incomeThisWeek: incomeThisWeek,
      expensesThisWeek: expensesThisWeek,
    );
  }

  static bool _matchesBudget(
    MovementRecord record,
    Budget budget,
    DateTime date,
  ) {
    if (record.isIncome) return false;
    if (date.isBefore(
      DateTime(
        budget.startDate.year,
        budget.startDate.month,
        budget.startDate.day,
      ),
    )) {
      return false;
    }
    if (date.isAfter(
      DateTime(
        budget.endDate.year,
        budget.endDate.month,
        budget.endDate.day,
        23,
        59,
        59,
      ),
    )) {
      return false;
    }
    final budgetKey = MovementRecord.budgetCategoryKey(
      hasCustomCategory: budget.hasCustomCategory,
      customCategoryId: budget.customCategoryId,
      systemCategory: budget.category,
    );
    return record.categoryKey == budgetKey;
  }
}
