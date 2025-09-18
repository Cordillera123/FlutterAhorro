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

  // Obtener estadísticas de los últimos 6 meses
  List<MonthlyStats> getMonthlyStats() {
    final transactions = _transactionService.transactions;
    final now = DateTime.now();
    final List<MonthlyStats> monthlyStats = [];
    
    for (int i = 5; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i);
      
      final monthTransactions = transactions.where((t) => 
        FormatUtils.isSameMonth(t.date, month)
      ).toList();
      
      final income = _calculateTotalIncome(monthTransactions);
      final expenses = _calculateTotalExpenses(monthTransactions);
      
      monthlyStats.add(MonthlyStats(
        month: month,
        income: income,
        expenses: expenses,
        balance: income - expenses,
        transactionCount: monthTransactions.length,
      ));
    }
    
    return monthlyStats;
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

  MonthlyStats({
    required this.month,
    required this.income,
    required this.expenses,
    required this.balance,
    required this.transactionCount,
  });

  String get monthLabel {
    return FormatUtils.getShortMonthName(month.month);
  }

  String get fullMonthLabel {
    return FormatUtils.getMonthName(month.month);
  }
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