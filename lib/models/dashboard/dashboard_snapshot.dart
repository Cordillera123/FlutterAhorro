import '../../models/budget.dart';

/// Agregado mensual precalculado en un único recorrido.
class MonthAggregate {
  final int year;
  final int month;
  final double income;
  final double expenses;
  final double savings;
  final int transactionCount;

  const MonthAggregate({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
    required this.savings,
    required this.transactionCount,
  });

  int get monthKey => year * 100 + month;
}

class CategoryAggregate {
  final String key;
  final String displayName;
  final String? emoji;
  final double amount;
  final double percentageOfExpenses;
  final int transactionCount;

  const CategoryAggregate({
    required this.key,
    required this.displayName,
    this.emoji,
    required this.amount,
    required this.percentageOfExpenses,
    required this.transactionCount,
  });
}

class IncomeSourceAggregate {
  final String key;
  final String displayName;
  final double amount;
  final double percentageOfIncome;
  final int transactionCount;

  const IncomeSourceAggregate({
    required this.key,
    required this.displayName,
    required this.amount,
    required this.percentageOfIncome,
    required this.transactionCount,
  });
}

class WeekOfMonthAggregate {
  final int weekNumber;
  final double expenses;
  final double percentageOfMonth;

  const WeekOfMonthAggregate({
    required this.weekNumber,
    required this.expenses,
    required this.percentageOfMonth,
  });
}

/// Progreso de presupuesto precalculado desde el snapshot (sin re-filtrar TX).
class BudgetProgressSnapshot {
  final Budget budget;
  final double spentAmount;

  const BudgetProgressSnapshot({
    required this.budget,
    required this.spentAmount,
  });

  double get remainingAmount => budget.amount - spentAmount;
  double get percentage => budget.amount > 0
      ? (spentAmount / budget.amount).clamp(0.0, double.infinity)
      : 0.0;
  BudgetStatus get status => budget.getStatus(spentAmount);

  double get dailySpendRate {
    final daysPassed = DateTime.now().difference(budget.startDate).inDays + 1;
    return daysPassed > 0 ? spentAmount / daysPassed : 0.0;
  }

  int get daysUntilDepleted {
    final remaining = remainingAmount;
    final rate = dailySpendRate;
    if (remaining <= 0 || rate <= 0) return 0;
    return (remaining / rate).ceil();
  }
}

/// Modelo de vista cacheable. No se persiste.
class DashboardSnapshot {
  final String accountId;
  final DateTime generatedAt;
  final DateTime referenceMonth;
  final int daysElapsedInMonth;
  final int daysInMonth;

  final double currentMonthIncome;
  final double currentMonthExpenses;
  final double currentMonthSavings;

  final double previousMonthIncome;
  final double previousMonthExpenses;
  final double previousMonthSavings;

  final double totalBalance;
  final int totalTransactionCount;

  final Map<int, MonthAggregate> monthlyHistory;
  final Map<String, CategoryAggregate> expensesByCategory;
  final Map<String, IncomeSourceAggregate> incomeBySource;
  final Map<int, double> expensesByDayOfMonth;
  final Map<int, double> expensesByWeekday;
  final Map<int, double> incomeByWeekday;
  final Map<int, WeekOfMonthAggregate> expensesByWeekOfMonth;
  final Map<int, Map<String, double>> expensesByMonthAndCategory;

  final double dailyAverageExpense;
  final double dailyAverageIncome;
  final double previousMonthDailyAverageExpense;
  final DateTime? lastTransactionDate;
  final int daysSinceLastTransaction;
  final int daysWithTransactionsLast30;
  final int currentStreakDays;

  final MonthAggregate? bestSavingsMonth;
  final MonthAggregate? worstSavingsMonth;

  final List<BudgetProgressSnapshot> budgetProgress;
  final double incomeThisWeek;
  final double expensesThisWeek;

  const DashboardSnapshot({
    required this.accountId,
    required this.generatedAt,
    required this.referenceMonth,
    required this.daysElapsedInMonth,
    required this.daysInMonth,
    required this.currentMonthIncome,
    required this.currentMonthExpenses,
    required this.currentMonthSavings,
    required this.previousMonthIncome,
    required this.previousMonthExpenses,
    required this.previousMonthSavings,
    required this.totalBalance,
    required this.totalTransactionCount,
    required this.monthlyHistory,
    required this.expensesByCategory,
    required this.incomeBySource,
    required this.expensesByDayOfMonth,
    required this.expensesByWeekday,
    required this.incomeByWeekday,
    required this.expensesByWeekOfMonth,
    required this.expensesByMonthAndCategory,
    required this.dailyAverageExpense,
    required this.dailyAverageIncome,
    required this.previousMonthDailyAverageExpense,
    required this.lastTransactionDate,
    required this.daysSinceLastTransaction,
    required this.daysWithTransactionsLast30,
    required this.currentStreakDays,
    this.bestSavingsMonth,
    this.worstSavingsMonth,
    required this.budgetProgress,
    required this.incomeThisWeek,
    required this.expensesThisWeek,
  });

  int get currentMonthKey =>
      referenceMonth.year * 100 + referenceMonth.month;

  int get previousMonthKey {
    final prev = DateTime(referenceMonth.year, referenceMonth.month - 1);
    return prev.year * 100 + prev.month;
  }

  double get savingsRate => currentMonthIncome > 0
      ? (currentMonthSavings / currentMonthIncome).clamp(-1.0, 1.0)
      : 0.0;

  CategoryAggregate? get topExpenseCategory {
    if (expensesByCategory.isEmpty) return null;
    return expensesByCategory.values.reduce(
      (a, b) => a.amount > b.amount ? a : b,
    );
  }

  IncomeSourceAggregate? get topIncomeSource {
    if (incomeBySource.isEmpty) return null;
    return incomeBySource.values.reduce(
      (a, b) => a.amount > b.amount ? a : b,
    );
  }

  bool get hasSufficientData => totalTransactionCount >= 3;

  List<MonthAggregate> get sortedMonthlyHistory {
    final list = monthlyHistory.values.toList()
      ..sort((a, b) => a.monthKey.compareTo(b.monthKey));
    return list;
  }

  double categoryExpensesForMonth(int monthKey, String categoryKey) {
    return expensesByMonthAndCategory[monthKey]?[categoryKey] ?? 0.0;
  }
}
