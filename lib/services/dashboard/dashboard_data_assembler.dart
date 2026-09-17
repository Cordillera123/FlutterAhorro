import '../../models/dashboard/dashboard_alert.dart';
import '../../models/dashboard/dashboard_achievement.dart';
import '../../models/dashboard/dashboard_analysis_context.dart';
import '../../models/dashboard/dashboard_forecast.dart';
import '../../models/dashboard/dashboard_observation.dart';
import '../../models/dashboard/dashboard_opportunity.dart';
import '../../models/dashboard/financial_health_state.dart';
import '../../models/dashboard/smart_dashboard_data.dart';
import 'executive_summary_generator.dart';
import 'message_deduplicator.dart';

class DashboardDataAssembler {
  final MessageDeduplicator _deduplicator = MessageDeduplicator();
  final ExecutiveSummaryGenerator _summaryGenerator =
      ExecutiveSummaryGenerator();

  SmartDashboardData assemble({
    required FinancialHealthState health,
    required List<DashboardAlert> alerts,
    required List<DashboardForecast> forecasts,
    required List<DashboardObservation> observations,
    required List<DashboardOpportunity> opportunities,
    required List<DashboardAchievement> achievements,
    required DashboardAnalysisContext context,
  }) {
    final config = context.config;

    final sortedAlerts = _deduplicator.dedupeAndLimit<DashboardAlert>(
      items: alerts,
      idExtractor: (a) => a.id,
      limit: config.maxAlerts,
      priorityComparator: (a, b) => a.sortOrder.compareTo(b.sortOrder),
    );

    final sortedForecasts = _deduplicator.dedupeAndLimit<DashboardForecast>(
      items: forecasts,
      idExtractor: (f) => f.id,
      limit: config.maxForecasts,
      priorityComparator: (a, b) =>
          a.confidence.index.compareTo(b.confidence.index),
    );

    final sortedObservations =
        _deduplicator.dedupeAndLimit<DashboardObservation>(
      items: observations,
      idExtractor: (o) => o.id,
      limit: config.maxObservations,
    );

    final sortedOpportunities =
        _deduplicator.dedupeAndLimit<DashboardOpportunity>(
      items: opportunities,
      idExtractor: (o) => o.id,
      limit: config.maxOpportunities,
    );

    // Los logros no se recortan como el resto de mensajes: el catálogo
    // completo alimenta la pantalla de Logros. Solo la lista destacada
    // (los ya conseguidos) respeta el límite de configuración.
    final uniqueAchievements =
        _deduplicator.dedupeAndLimit<DashboardAchievement>(
      items: achievements,
      idExtractor: (a) => a.id,
      limit: achievements.length,
    );

    final unlocked = uniqueAchievements.where((a) => a.unlocked).toList()
      ..sort(_compareUnlocked);
    final locked = uniqueAchievements.where((a) => !a.unlocked).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));

    final highlighted = unlocked.length > config.maxAchievements
        ? unlocked.sublist(0, config.maxAchievements)
        : unlocked;

    final summary = _summaryGenerator.generate(health, sortedAlerts, context);

    return SmartDashboardData(
      summary: summary,
      health: health,
      alerts: sortedAlerts,
      forecasts: sortedForecasts,
      observations: sortedObservations,
      opportunities: sortedOpportunities,
      achievements: highlighted,
      allAchievements: [...unlocked, ...locked],
      generatedAt: context.generatedAt,
      hasSufficientData: context.hasMinimumData,
      emptyStateMessage: context.hasMinimumData
          ? null
          : 'Registra al menos ${config.minTransactionsForAnalysis} movimientos para que podamos analizar tus finanzas.',
      config: config,
    );
  }

  /// Destaca primero lo más reciente y, a falta de fecha, el nivel más alto:
  /// es lo que el usuario percibe como su mayor logro.
  int _compareUnlocked(DashboardAchievement a, DashboardAchievement b) {
    final dateA = a.achievedAt;
    final dateB = b.achievedAt;
    if (dateA != null && dateB != null) return dateB.compareTo(dateA);
    if (dateA != null) return -1;
    if (dateB != null) return 1;
    return b.tier.compareTo(a.tier);
  }
}
