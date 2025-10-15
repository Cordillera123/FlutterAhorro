import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../utils/format_utils.dart';

class StatsService {
  final TransactionService _transactionService = TransactionService();

  // Obtener estadísticas del período actual vs anterior
  FinancialStats getCurrentVsPreviousStats() {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);
    
    final transactions = _transactionService.transactions;
    
    // Transacciones del mes actual
    final currentMonthTransactions = transactions.where((t) => 
      FormatUtils.isSameMonth(t.date, now)
    ).toList();
    
    // Transacciones del mes anterior
    final previousMonthTransactions = transactions.where((t) => 
      FormatUtils.isSameMonth(t.date, previousMonth)
    ).toList();
    
    // Calcular totales
    final currentIncome = _calculateTotalIncome(currentMonthTransactions);
    final currentExpenses = _calculateTotalExpenses(currentMonthTransactions);
    final currentBalance = currentIncome - currentExpenses;
    
    final previousIncome = _calculateTotalIncome(previousMonthTransactions);
    final previousExpenses = _calculateTotalExpenses(previousMonthTransactions);
    final previousBalance = previousIncome - previousExpenses;
    
    // Calcular porcentajes de crecimiento
    final balanceGrowth = FormatUtils.calculateGrowthPercentage(currentBalance, previousBalance);
    final incomeGrowth = FormatUtils.calculateGrowthPercentage(currentIncome, previousIncome);
    final expenseGrowth = FormatUtils.calculateGrowthPercentage(currentExpenses, previousExpenses);
    
    return FinancialStats(
      currentIncome: currentIncome,
      currentExpenses: currentExpenses,
      currentBalance: currentBalance,
      previousIncome: previousIncome,
      previousExpenses: previousExpenses,
      previousBalance: previousBalance,
      balanceGrowthPercentage: balanceGrowth,
      incomeGrowthPercentage: incomeGrowth,
      expenseGrowthPercentage: expenseGrowth,
      currentMonthTransactionCount: currentMonthTransactions.length,
      previousMonthTransactionCount: previousMonthTransactions.length,
    );
  }

  // Obtener estadísticas por categoría
  List<CategoryStats> getCategoryStats() {
    final transactions = _transactionService.transactions;
    final now = DateTime.now();
    
    final currentMonthTransactions = transactions.where((t) => 
      FormatUtils.isSameMonth(t.date, now)
    ).toList();
    
    // Agrupar por categorías de gastos
    final Map<ExpenseCategory, List<Transaction>> expensesByCategory = {};
    
    for (final transaction in currentMonthTransactions) {
      if (transaction.type == TransactionType.expense && transaction.expenseCategory != null) {
        expensesByCategory.putIfAbsent(transaction.expenseCategory!, () => []);
        expensesByCategory[transaction.expenseCategory!]!.add(transaction);
      }
    }
    
    final totalExpenses = _calculateTotalExpenses(currentMonthTransactions);
    
    return expensesByCategory.entries.map((entry) {
      final category = entry.key;
      final categoryTransactions = entry.value;
      final categoryTotal = categoryTransactions.fold(0.0, (sum, t) => sum + t.amount);
      final percentage = totalExpenses > 0 ? (categoryTotal / totalExpenses) * 100 : 0.0;
      
      return CategoryStats(
        category: category,
        amount: categoryTotal,
        percentage: percentage,
        transactionCount: categoryTransactions.length,
        categoryName: _getCategoryName(category),
        categoryIcon: _getCategoryIcon(category),
      );
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));
  }

  // Obtener estadísticas semanales (últimas 4 semanas)
  List<WeeklyStats> getWeeklyStats() {
    final transactions = _transactionService.transactions;
    final now = DateTime.now();
    final List<WeeklyStats> weeklyStats = [];
    
    for (int i = 3; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: (i * 7) + now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));
      
      final weekTransactions = transactions.where((t) => 
        t.date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        t.date.isBefore(weekEnd.add(const Duration(days: 1)))
      ).toList();
      
      final income = _calculateTotalIncome(weekTransactions);
      final expenses = _calculateTotalExpenses(weekTransactions);
      
      weeklyStats.add(WeeklyStats(
        weekStart: weekStart,
        weekEnd: weekEnd,
        income: income,
        expenses: expenses,
        balance: income - expenses,
        transactionCount: weekTransactions.length,
      ));
    }
    
    return weeklyStats;
  }

  // Obtener estadísticas de los últimos 6 meses (método existente mantenido para compatibilidad)
  List<MonthlyStats> getMonthlyStats() {
    return getMonthlyStatsHistory(months: 6);
  }

  // NUEVO: Obtener historial mensual expandido (hasta 12 meses)
  List<MonthlyStats> getMonthlyStatsHistory({int months = 12}) {
    final transactions = _transactionService.transactions;
    final now = DateTime.now();
    final List<MonthlyStats> monthlyStats = [];
    
    for (int i = months - 1; i >= 0; i--) {
      final targetMonth = DateTime(now.year, now.month - i);
      final monthTransactions = transactions.where((t) => 
        FormatUtils.isSameMonth(t.date, targetMonth)
      ).toList();
      
      final income = _calculateTotalIncome(monthTransactions);
      final expenses = _calculateTotalExpenses(monthTransactions);
      final categoryBreakdown = _getCategoryBreakdownForMonth(monthTransactions);
      final topExpenseCategory = _getTopCategoryForMonth(monthTransactions);
      
      monthlyStats.add(MonthlyStats(
        month: targetMonth,
        income: income,
        expenses: expenses,
        balance: income - expenses,
        transactionCount: monthTransactions.length,
        incomeTransactionCount: monthTransactions.where((t) => t.type == TransactionType.income).length,
        expenseTransactionCount: monthTransactions.where((t) => t.type == TransactionType.expense).length,
        categoryBreakdown: categoryBreakdown,
        topExpenseCategory: topExpenseCategory,
      ));
    }
    
    return monthlyStats;
  }

  // NUEVO: Obtener estadísticas de comparación mensual avanzada
  MonthlyComparisonStats getMonthlyComparison() {
    final monthlyHistory = getMonthlyStatsHistory(months: 6); // Últimos 6 meses
    
    if (monthlyHistory.length < 2) {
      return MonthlyComparisonStats(
        currentMonth: monthlyHistory.isNotEmpty ? monthlyHistory.last : null,
        previousMonth: null,
        averageIncome: 0,
        averageExpenses: 0,
        bestMonth: null,
        worstMonth: null,
        trend: MonthlyTrend.stable,
        monthsWithData: monthlyHistory.length,
      );
    }

    final current = monthlyHistory.last;
    final previous = monthlyHistory[monthlyHistory.length - 2];
    
    // Calcular promedios
    final monthsWithTransactions = monthlyHistory.where((m) => m.transactionCount > 0).toList();
    final avgIncome = monthsWithTransactions.isEmpty ? 0.0 : 
        monthsWithTransactions.map((m) => m.income).reduce((a, b) => a + b) / monthsWithTransactions.length;
    final avgExpenses = monthsWithTransactions.isEmpty ? 0.0 : 
        monthsWithTransactions.map((m) => m.expenses).reduce((a, b) => a + b) / monthsWithTransactions.length;
    
    // Encontrar mejor y peor mes por balance
    MonthlyStats? bestMonth;
    MonthlyStats? worstMonth;
    
    if (monthsWithTransactions.isNotEmpty) {
      bestMonth = monthsWithTransactions.reduce((a, b) => a.balance > b.balance ? a : b);
      worstMonth = monthsWithTransactions.reduce((a, b) => a.balance < b.balance ? a : b);
    }
    
    // Determinar tendencia basada en los últimos 3 meses
    MonthlyTrend trend = MonthlyTrend.stable;
    if (monthsWithTransactions.length >= 3) {
      final last3Months = monthsWithTransactions.take(3).toList();
      
      // Verificar si hay tendencia creciente
      bool isImproving = true;
      bool isWorsening = true;
      
      for (int i = 1; i < last3Months.length; i++) {
        if (last3Months[i].balance <= last3Months[i-1].balance) {
          isImproving = false;
        }
        if (last3Months[i].balance >= last3Months[i-1].balance) {
          isWorsening = false;
        }
      }
      
      if (isImproving) trend = MonthlyTrend.improving;
      else if (isWorsening) trend = MonthlyTrend.declining;
    }

    return MonthlyComparisonStats(
      currentMonth: current,
      previousMonth: previous,
      averageIncome: avgIncome,
      averageExpenses: avgExpenses,
      bestMonth: bestMonth,
      worstMonth: worstMonth,
      trend: trend,
      monthsWithData: monthsWithTransactions.length,
    );
  }

  // NUEVO: Obtener estadísticas detalladas de un mes específico
  MonthlyDetailStats getMonthStats(DateTime month) {
    final transactions = _transactionService.transactions;
    final monthTransactions = transactions.where((t) => 
      FormatUtils.isSameMonth(t.date, month)
    ).toList();
    
    final income = _calculateTotalIncome(monthTransactions);
    final expenses = _calculateTotalExpenses(monthTransactions);
    final categoryStats = _getCategoryStatsForMonth(monthTransactions);
    
    // Obtener estadísticas por día del mes
    final Map<int, DayStats> dailyStats = {};
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    
    for (int day = 1; day <= daysInMonth; day++) {
      final dayTransactions = monthTransactions.where((t) => t.date.day == day).toList();
      dailyStats[day] = DayStats(
        day: day,
        income: _calculateTotalIncome(dayTransactions),
        expenses: _calculateTotalExpenses(dayTransactions),
        transactionCount: dayTransactions.length,
      );
    }
    
    // Encontrar el día con mayor gasto
    DayStats? highestExpenseDay;
    if (dailyStats.values.isNotEmpty) {
      highestExpenseDay = dailyStats.values.reduce((a, b) => a.expenses > b.expenses ? a : b);
      if (highestExpenseDay!.expenses == 0) highestExpenseDay = null;
    }
    
    return MonthlyDetailStats(
      month: month,
      income: income,
      expenses: expenses,
      balance: income - expenses,
      transactionCount: monthTransactions.length,
      categoryStats: categoryStats,
      dailyStats: dailyStats,
      averageDailyExpenses: expenses / daysInMonth,
      highestExpenseDay: highestExpenseDay,
      transactionsList: monthTransactions,
    );
  }

  // Obtener resumen general
  OverallStats getOverallStats() {
    final transactions = _transactionService.transactions;
    final totalIncome = _calculateTotalIncome(transactions);
    final totalExpenses = _calculateTotalExpenses(transactions);
    final totalBalance = totalIncome - totalExpenses;
    
    // Categoría con más gastos
    final categoryStats = getCategoryStats();
    final topCategory = categoryStats.isNotEmpty ? categoryStats.first : null;
    
    // Promedio mensual (últimos 6 meses)
    final monthlyStats = getMonthlyStats();
    final monthsWithData = monthlyStats.where((m) => m.transactionCount > 0).toList();
    
    final avgIncome = monthsWithData.isNotEmpty 
        ? monthsWithData.map((m) => m.income).reduce((a, b) => a + b) / monthsWithData.length
        : 0.0;
    
    final avgExpenses = monthsWithData.isNotEmpty 
        ? monthsWithData.map((m) => m.expenses).reduce((a, b) => a + b) / monthsWithData.length
        : 0.0;
    
    return OverallStats(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      totalBalance: totalBalance,
      totalTransactions: transactions.length,
      averageMonthlyIncome: avgIncome,
      averageMonthlyExpenses: avgExpenses,
      topExpenseCategory: topCategory,
      monthsWithData: monthsWithData.length,
    );
  }

  // Obtener transacciones más recientes
  List<Transaction> getRecentTransactions({int limit = 5}) {
    final transactions = _transactionService.transactions;
    if (transactions.isEmpty) return [];
    
    final sorted = List<Transaction>.from(transactions);
    sorted.sort((a, b) => b.date.compareTo(a.date));
    
    return sorted.take(limit).toList();
  }

  // Métodos auxiliares privados
  double _calculateTotalIncome(List<Transaction> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double _calculateTotalExpenses(List<Transaction> transactions) {
    return transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // NUEVO: Obtener desglose por categorías de un mes específico
  Map<ExpenseCategory, double> _getCategoryBreakdownForMonth(List<Transaction> transactions) {
    final Map<ExpenseCategory, double> breakdown = {};
    
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense && transaction.expenseCategory != null) {
        breakdown[transaction.expenseCategory!] = 
            (breakdown[transaction.expenseCategory!] ?? 0.0) + transaction.amount;
      }
    }
    
    return breakdown;
  }

  // NUEVO: Obtener la categoría con mayor gasto del mes
  CategoryStats? _getTopCategoryForMonth(List<Transaction> transactions) {
    final breakdown = _getCategoryBreakdownForMonth(transactions);
    if (breakdown.isEmpty) return null;
    
    final topEntry = breakdown.entries.reduce((a, b) => a.value > b.value ? a : b);
    final totalExpenses = breakdown.values.fold(0.0, (sum, amount) => sum + amount);
    final percentage = totalExpenses > 0 ? (topEntry.value / totalExpenses) * 100 : 0.0;
    
    return CategoryStats(
      category: topEntry.key,
      amount: topEntry.value,
      percentage: percentage,
      transactionCount: transactions.where((t) => t.expenseCategory == topEntry.key).length,
      categoryName: _getCategoryName(topEntry.key),
      categoryIcon: _getCategoryIcon(topEntry.key),
    );
  }

  // NUEVO: Obtener estadísticas de categorías para un mes específico
  List<CategoryStats> _getCategoryStatsForMonth(List<Transaction> transactions) {
    final expenseTransactions = transactions.where((t) => t.type == TransactionType.expense).toList();
    final totalExpenses = _calculateTotalExpenses(expenseTransactions);
    
    final Map<ExpenseCategory, List<Transaction>> expensesByCategory = {};
    
    for (final transaction in expenseTransactions) {
      if (transaction.expenseCategory != null) {
        expensesByCategory.putIfAbsent(transaction.expenseCategory!, () => []);
        expensesByCategory[transaction.expenseCategory!]!.add(transaction);
      }
    }
    
    return expensesByCategory.entries.map((entry) {
      final category = entry.key;
      final categoryTransactions = entry.value;
      final categoryTotal = categoryTransactions.fold(0.0, (sum, t) => sum + t.amount);
      final percentage = totalExpenses > 0 ? (categoryTotal / totalExpenses) * 100 : 0.0;
      
      return CategoryStats(
        category: category,
        amount: categoryTotal,
        percentage: percentage,
        transactionCount: categoryTransactions.length,
        categoryName: _getCategoryName(category),
        categoryIcon: _getCategoryIcon(category),
      );
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));
  }

  String _getCategoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.transport: return 'Transporte';
      case ExpenseCategory.food: return 'Alimentación';
      case ExpenseCategory.utilities: return 'Servicios Básicos';
      case ExpenseCategory.health: return 'Salud';
      case ExpenseCategory.education: return 'Educación';
      case ExpenseCategory.entertainment: return 'Entretenimiento';
      case ExpenseCategory.clothing: return 'Ropa y Calzado';
      case ExpenseCategory.home: return 'Hogar y Muebles';
      case ExpenseCategory.technology: return 'Tecnología';
      case ExpenseCategory.savings: return 'Ahorros e Inversión';
      case ExpenseCategory.gifts: return 'Regalos y Donaciones';
      case ExpenseCategory.other: return 'Otros';
    }
  }

  String _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.transport: return '🚗';
      case ExpenseCategory.food: return '🍕';
      case ExpenseCategory.utilities: return '💡';
      case ExpenseCategory.health: return '🏥';
      case ExpenseCategory.education: return '📚';
      case ExpenseCategory.entertainment: return '🎬';
      case ExpenseCategory.clothing: return '👕';
      case ExpenseCategory.home: return '🏠';
      case ExpenseCategory.technology: return '📱';
      case ExpenseCategory.savings: return '💰';
      case ExpenseCategory.gifts: return '🎁';
      case ExpenseCategory.other: return '📦';
    }
  }
}

// Modelos para las estadísticas
class FinancialStats {
  final double currentIncome;
  final double currentExpenses;
  final double currentBalance;
  final double previousIncome;
  final double previousExpenses;
  final double previousBalance;
  final double balanceGrowthPercentage;
  final double incomeGrowthPercentage;
  final double expenseGrowthPercentage;
  final int currentMonthTransactionCount;
  final int previousMonthTransactionCount;

  FinancialStats({
    required this.currentIncome,
    required this.currentExpenses,
    required this.currentBalance,
    required this.previousIncome,
    required this.previousExpenses,
    required this.previousBalance,
    required this.balanceGrowthPercentage,
    required this.incomeGrowthPercentage,
    required this.expenseGrowthPercentage,
    required this.currentMonthTransactionCount,
    required this.previousMonthTransactionCount,
  });

  bool get isGrowing => balanceGrowthPercentage > 0;
  bool get hasData => currentMonthTransactionCount > 0 || previousMonthTransactionCount > 0;
  bool get hasCurrentData => currentMonthTransactionCount > 0;
  bool get hasPreviousData => previousMonthTransactionCount > 0;
}

class CategoryStats {
  final ExpenseCategory category;
  final double amount;
  final double percentage;
  final int transactionCount;
  final String categoryName;
  final String categoryIcon;

  CategoryStats({
    required this.category,
    required this.amount,
    required this.percentage,
    required this.transactionCount,
    required this.categoryName,
    required this.categoryIcon,
  });
}

class WeeklyStats {
  final DateTime weekStart;
  final DateTime weekEnd;
  final double income;
  final double expenses;
  final double balance;
  final int transactionCount;

  WeeklyStats({
    required this.weekStart,
    required this.weekEnd,
    required this.income,
    required this.expenses,
    required this.balance,
    required this.transactionCount,
  });

  String get weekLabel {
    final start = FormatUtils.formatDateShort(weekStart);
    final end = FormatUtils.formatDateShort(weekEnd);
    return '$start - $end';
  }
}

class MonthlyStats {
  final DateTime month;
  final double income;
  final double expenses;
  final double balance;
  final int transactionCount;
  final int incomeTransactionCount;
  final int expenseTransactionCount;
  final Map<ExpenseCategory, double> categoryBreakdown;
  final CategoryStats? topExpenseCategory;

  MonthlyStats({
    required this.month,
    required this.income,
    required this.expenses,
    required this.balance,
    required this.transactionCount,
    required this.incomeTransactionCount,
    required this.expenseTransactionCount,
    required this.categoryBreakdown,
    this.topExpenseCategory,
  });

  String get monthLabel => FormatUtils.getMonthName(month.month);
  String get shortMonthLabel => FormatUtils.getShortMonthName(month.month);
  double get savingsRate => income > 0 ? (balance / income) * 100 : 0.0;
  bool get hasData => transactionCount > 0;
  bool get isPositive => balance >= 0;
  String get fullMonthLabel => '${monthLabel} ${month.year}';
}

class OverallStats {
  final double totalIncome;
  final double totalExpenses;
  final double totalBalance;
  final int totalTransactions;
  final double averageMonthlyIncome;
  final double averageMonthlyExpenses;
  final CategoryStats? topExpenseCategory;
  final int monthsWithData;

  OverallStats({
    required this.totalIncome,
    required this.totalExpenses,
    required this.totalBalance,
    required this.totalTransactions,
    required this.averageMonthlyIncome,
    required this.averageMonthlyExpenses,
    required this.topExpenseCategory,
    required this.monthsWithData,
  });

  double get averageMonthlyBalance => averageMonthlyIncome - averageMonthlyExpenses;
  double get savingsRate => averageMonthlyIncome > 0 ? (averageMonthlyBalance / averageMonthlyIncome) * 100 : 0.0;
}

// NUEVAS CLASES PARA LAS ESTADÍSTICAS AMPLIADAS

enum MonthlyTrend {
  improving,  // Mejorando
  declining,  // Empeorando
  stable,     // Estable
}

class MonthlyComparisonStats {
  final MonthlyStats? currentMonth;
  final MonthlyStats? previousMonth;
  final double averageIncome;
  final double averageExpenses;
  final MonthlyStats? bestMonth;
  final MonthlyStats? worstMonth;
  final MonthlyTrend trend;
  final int monthsWithData;

  MonthlyComparisonStats({
    this.currentMonth,
    this.previousMonth,
    required this.averageIncome,
    required this.averageExpenses,
    this.bestMonth,
    this.worstMonth,
    required this.trend,
    required this.monthsWithData,
  });

  double get averageBalance => averageIncome - averageExpenses;
  bool get hasEnoughData => monthsWithData >= 2;
  
  String get trendDescription {
    switch (trend) {
      case MonthlyTrend.improving:
        return 'Mejorando';
      case MonthlyTrend.declining:
        return 'Empeorando';
      case MonthlyTrend.stable:
        return 'Estable';
    }
  }

  String get trendEmoji {
    switch (trend) {
      case MonthlyTrend.improving:
        return '📈';
      case MonthlyTrend.declining:
        return '📉';
      case MonthlyTrend.stable:
        return '➡️';
    }
  }
}

class MonthlyDetailStats {
  final DateTime month;
  final double income;
  final double expenses;
  final double balance;
  final int transactionCount;
  final List<CategoryStats> categoryStats;
  final Map<int, DayStats> dailyStats;
  final double averageDailyExpenses;
  final DayStats? highestExpenseDay;
  final List<Transaction> transactionsList;

  MonthlyDetailStats({
    required this.month,
    required this.income,
    required this.expenses,
    required this.balance,
    required this.transactionCount,
    required this.categoryStats,
    required this.dailyStats,
    required this.averageDailyExpenses,
    this.highestExpenseDay,
    required this.transactionsList,
  });

  String get monthLabel => FormatUtils.getMonthName(month.month);
  double get savingsRate => income > 0 ? (balance / income) * 100 : 0.0;
  bool get hasData => transactionCount > 0;
  bool get isPositive => balance >= 0;
}

class DayStats {
  final int day;
  final double income;
  final double expenses;
  final int transactionCount;

  DayStats({
    required this.day,
    required this.income,
    required this.expenses,
    required this.transactionCount,
  });

  double get balance => income - expenses;
  bool get hasTransactions => transactionCount > 0;
}