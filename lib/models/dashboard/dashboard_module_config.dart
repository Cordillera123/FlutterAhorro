/// Configuración del módulo dashboard para límites y feature flags.
class DashboardModuleConfig {
  final int maxAlerts;
  final int maxForecasts;
  final int maxObservations;
  final int maxOpportunities;
  final int maxAchievements;
  final int minTransactionsForAnalysis;
  final int historyMonths;

  const DashboardModuleConfig({
    this.maxAlerts = 5,
    this.maxForecasts = 3,
    this.maxObservations = 5,
    this.maxOpportunities = 4,
    this.maxAchievements = 8,
    this.minTransactionsForAnalysis = 3,
    this.historyMonths = 12,
  });

  static const DashboardModuleConfig production = DashboardModuleConfig();
}
