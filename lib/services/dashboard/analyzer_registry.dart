import '../../models/dashboard/dashboard_alert.dart';
import '../../models/dashboard/dashboard_achievement.dart';
import '../../models/dashboard/dashboard_forecast.dart';
import '../../models/dashboard/dashboard_observation.dart';
import '../../models/dashboard/dashboard_opportunity.dart';
import 'analyzers/achievements/achievement_analyzers.dart';
import 'analyzers/alerts/alert_analyzers.dart';
import 'analyzers/forecasts/forecast_analyzers.dart';
import 'analyzers/observations/observation_analyzers.dart';
import 'analyzers/opportunities/opportunity_analyzers.dart';
import 'dashboard_analyzer.dart';

/// Registro central de todos los analyzers del dashboard.
class AnalyzerRegistry {
  final List<DashboardAnalyzer<DashboardAlert>> alertAnalyzers;
  final List<DashboardAnalyzer<DashboardObservation>> observationAnalyzers;
  final List<DashboardAnalyzer<DashboardForecast>> forecastAnalyzers;
  final List<DashboardAnalyzer<DashboardOpportunity>> opportunityAnalyzers;
  final List<DashboardAnalyzer<DashboardAchievement>> achievementAnalyzers;

  AnalyzerRegistry()
      : alertAnalyzers = [
          BudgetExceededAlertAnalyzer(),
          BudgetDangerAlertAnalyzer(),
          NegativeSavingsAlertAnalyzer(),
          GoalOverdueAlertAnalyzer(),
          NoIncomeWeekAlertAnalyzer(),
          InactivityAlertAnalyzer(),
        ],
        observationAnalyzers = [
          ExpenseVsPreviousObservationAnalyzer(),
          IncomeVsPreviousObservationAnalyzer(),
          BestSavingsMonthObservationAnalyzer(),
          SavingsStreakObservationAnalyzer(),
          GoalNearObservationAnalyzer(),
          CategoryReductionObservationAnalyzer(),
          WeekendSpendingObservationAnalyzer(),
          PeakWeekdayObservationAnalyzer(),
          MonthEndLoadObservationAnalyzer(),
          DominantIncomeObservationAnalyzer(),
          DominantExpenseObservationAnalyzer(),
          DailyAverageChangeObservationAnalyzer(),
          RegistrationStreakObservationAnalyzer(),
        ],
        forecastAnalyzers = [
          MonthEndSavingsForecastAnalyzer(),
          ExpenseTrendForecastAnalyzer(),
          GoalCompletionForecastAnalyzer(),
          GoalExtraSavingsForecastAnalyzer(),
          BudgetDepletionForecastAnalyzer(),
          BalanceProjectionForecastAnalyzer(),
        ],
        opportunityAnalyzers = [
          BudgetAlertOpportunityAnalyzer(),
          ReduceCategoryOpportunityAnalyzer(),
          BoostGoalOpportunityAnalyzer(),
          BudgetTrimOpportunityAnalyzer(),
          RecordIncomeOpportunityAnalyzer(),
          SavingsOpportunityAnalyzer(),
        ],
        achievementAnalyzers = [
          // Primeros pasos
          MovementsAchievementAnalyzer(),
          FirstIncomeAchievementAnalyzer(),
          // Constancia
          RegistrationStreakAchievementAnalyzer(),
          ActiveMonthAchievementAnalyzer(),
          MonthsUsingAchievementAnalyzer(),
          // Ahorro
          SavingsRecordAchievementAnalyzer(),
          MonthlySavingsAchievementAnalyzer(),
          TotalSavingsAchievementAnalyzer(),
          SavingsRateAchievementAnalyzer(),
          PositiveMonthsAchievementAnalyzer(),
          // Presupuestos
          FirstBudgetAchievementAnalyzer(),
          BudgetStreakAchievementAnalyzer(),
          // Metas
          FirstGoalAchievementAnalyzer(),
          GoalsCompletedAchievementAnalyzer(),
          GoalNearAchievementAnalyzer(),
          // Crecimiento
          SavingsUpStreakAchievementAnalyzer(),
          ExpenseDownStreakAchievementAnalyzer(),
          IncomeUpStreakAchievementAnalyzer(),
          IncomeDiversityAchievementAnalyzer(),
        ];
}
