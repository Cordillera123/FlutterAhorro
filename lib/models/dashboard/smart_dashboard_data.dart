import 'dashboard_achievement.dart';
import 'dashboard_alert.dart';
import 'dashboard_forecast.dart';
import 'dashboard_module_config.dart';
import 'dashboard_observation.dart';
import 'dashboard_opportunity.dart';
import 'executive_summary.dart';
import 'financial_health_state.dart';

/// DTO raíz consumido por la UI del Dashboard Inteligente.
class SmartDashboardData {
  final ExecutiveSummary summary;
  final FinancialHealthState health;
  final List<DashboardAlert> alerts;
  final List<DashboardForecast> forecasts;
  final List<DashboardObservation> observations;
  final List<DashboardOpportunity> opportunities;

  /// Logros ya conseguidos, listos para destacar (limitados por configuración).
  final List<DashboardAchievement> achievements;

  /// Catálogo completo: conseguidos y pendientes con su progreso. Lo consume
  /// la pantalla de Logros para mostrar al usuario qué le falta.
  final List<DashboardAchievement> allAchievements;
  final DateTime generatedAt;
  final bool hasSufficientData;
  final String? emptyStateMessage;
  final DashboardModuleConfig config;

  const SmartDashboardData({
    required this.summary,
    required this.health,
    required this.alerts,
    required this.forecasts,
    required this.observations,
    required this.opportunities,
    required this.achievements,
    this.allAchievements = const [],
    required this.generatedAt,
    required this.hasSufficientData,
    this.emptyStateMessage,
    required this.config,
  });

  bool get hasAlerts => alerts.isNotEmpty;

  List<DashboardAchievement> get unlockedAchievements =>
      allAchievements.where((a) => a.unlocked).toList();

  List<DashboardAchievement> get lockedAchievements =>
      allAchievements.where((a) => !a.unlocked).toList();

  int get unlockedAchievementCount => unlockedAchievements.length;

  int get totalAchievementCount => allAchievements.length;
}
