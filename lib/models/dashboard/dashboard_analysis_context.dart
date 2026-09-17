import '../account.dart';
import '../budget.dart';
import '../financial_goal.dart';
import 'dashboard_module_config.dart';
import 'dashboard_snapshot.dart';

/// Contexto inmutable de análisis: snapshot + datos de dominio.
class DashboardAnalysisContext {
  final DashboardSnapshot snapshot;
  final Account account;
  final List<FinancialGoal> activeGoals;
  final List<FinancialGoal> allAccountGoals;

  /// Todos los presupuestos de la cuenta, incluidos los de períodos pasados.
  /// `snapshot.budgetProgress` solo cubre los del período vigente, por lo que
  /// no sirve para saber si el usuario ya creó presupuestos alguna vez.
  final List<Budget> allAccountBudgets;
  final Map<String, double> goalWeeklyContributionRates;
  final DateTime generatedAt;
  final DashboardModuleConfig config;

  const DashboardAnalysisContext({
    required this.snapshot,
    required this.account,
    required this.activeGoals,
    required this.allAccountGoals,
    this.allAccountBudgets = const [],
    required this.goalWeeklyContributionRates,
    required this.generatedAt,
    required this.config,
  });

  bool get hasMinimumData =>
      snapshot.totalTransactionCount >= config.minTransactionsForAnalysis;

  bool get hasMonthData =>
      snapshot.currentMonthExpenses > 0 || snapshot.currentMonthIncome > 0;

  bool get hasPreviousMonthData =>
      snapshot.previousMonthExpenses > 0 || snapshot.previousMonthIncome > 0;

  bool get hasActiveBudgets => snapshot.budgetProgress.isNotEmpty;

  bool get hasActiveGoals => activeGoals.isNotEmpty;

  double weeklyContributionRateForGoal(String goalId) =>
      goalWeeklyContributionRates[goalId] ?? 0.0;
}
