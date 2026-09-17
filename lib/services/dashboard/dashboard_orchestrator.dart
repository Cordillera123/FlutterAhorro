import '../../models/dashboard/dashboard_analysis_context.dart';
import '../../models/dashboard/dashboard_module_config.dart';
import '../../models/dashboard/smart_dashboard_data.dart';
import '../../services/account_service.dart';
import '../../services/budget_service.dart';
import '../../services/goal_service.dart';
import '../../services/transaction_service.dart';
import 'achievement_engine.dart';
import 'alert_engine.dart';
import 'analyzer_registry.dart';
import 'dashboard_data_assembler.dart';
import 'financial_health_calculator.dart';
import 'forecast_engine.dart';
import 'observation_engine.dart';
import 'opportunity_engine.dart';
import 'snapshot_builder.dart';

/// Coordina el pipeline completo de análisis del dashboard.
class DashboardOrchestrator {
  final FinancialHealthCalculator _healthCalculator =
      FinancialHealthCalculator();
  final AlertEngine _alertEngine;
  final ObservationEngine _observationEngine;
  final ForecastEngine _forecastEngine;
  final OpportunityEngine _opportunityEngine;
  final AchievementEngine _achievementEngine;
  final DashboardDataAssembler _assembler = DashboardDataAssembler();

  DashboardOrchestrator._(
    AnalyzerRegistry registry,
  )
      : _alertEngine = AlertEngine(registry),
        _observationEngine = ObservationEngine(registry),
        _forecastEngine = ForecastEngine(registry),
        _opportunityEngine = OpportunityEngine(registry),
        _achievementEngine = AchievementEngine(registry);

  factory DashboardOrchestrator.create() =>
      DashboardOrchestrator._(AnalyzerRegistry());

  SmartDashboardData run({
    DashboardModuleConfig config = DashboardModuleConfig.production,
  }) {
    final transactionService = TransactionService();
    final accountService = AccountService();
    final budgetService = BudgetService();
    final goalService = GoalService();

    final now = DateTime.now();
    final snapshot = SnapshotBuilder.build(
      transactions: transactionService.transactions,
      account: accountService.activeAccount,
      activeBudgets: budgetService.activeBudgets,
      referenceTime: now,
      historyMonths: config.historyMonths,
    );

    final context = DashboardAnalysisContext(
      snapshot: snapshot,
      account: accountService.activeAccount,
      activeGoals: goalService.activeGoals,
      allAccountGoals: goalService.goals,
      allAccountBudgets: budgetService.budgets,
      goalWeeklyContributionRates: _computeWeeklyRates(goalService),
      generatedAt: now,
      config: config,
    );

    final health = _healthCalculator.calculate(context);
    final alerts = _alertEngine.run(context);
    final forecasts = _forecastEngine.run(context);
    final observations = _observationEngine.run(context);
    final opportunities = _opportunityEngine.run(context);
    final achievements = _achievementEngine.run(context);

    return _assembler.assemble(
      health: health,
      alerts: alerts,
      forecasts: forecasts,
      observations: observations,
      opportunities: opportunities,
      achievements: achievements,
      context: context,
    );
  }

  Map<String, double> _computeWeeklyRates(GoalService goalService) {
    final now = DateTime.now();
    final fourWeeksAgo = now.subtract(const Duration(days: 28));
    final rates = <String, double>{};

    for (final goal in goalService.activeGoals) {
      if (goal.id == null) continue;
      final contributions = goalService
          .getGoalContributions(goal.id!)
          .where((c) => c.amount > 0 && c.date.isAfter(fourWeeksAgo))
          .toList();
      if (contributions.isEmpty) continue;
      final total =
          contributions.fold(0.0, (sum, c) => sum + c.amount);
      rates[goal.id!] = total / 4;
    }
    return rates;
  }
}
