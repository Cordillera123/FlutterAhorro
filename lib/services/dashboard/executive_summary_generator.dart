import '../../models/dashboard/dashboard_alert.dart';
import '../../models/dashboard/dashboard_analysis_context.dart';
import '../../models/dashboard/dashboard_enums.dart';
import '../../models/dashboard/executive_summary.dart';
import '../../models/dashboard/financial_health_state.dart';

/// Genera el resumen ejecutivo en una frase a partir del estado y alertas.
class ExecutiveSummaryGenerator {
  ExecutiveSummary generate(
    FinancialHealthState health,
    List<DashboardAlert> alerts,
    DashboardAnalysisContext context,
  ) {
    if (!context.hasMinimumData) {
      return const ExecutiveSummary(
        message: 'Registra más movimientos para que podamos analizar tus finanzas.',
        subtitle: 'Necesitas al menos 3 transacciones',
      );
    }

    final critical = alerts.where((a) => a.severity == AlertSeverity.critical);
    if (critical.isNotEmpty) {
      return ExecutiveSummary(
        message: critical.first.message,
        subtitle: 'Tu estado financiero es ${health.levelLabel} (${health.score}/100)',
      );
    }

    final s = context.snapshot;
    String message;
    switch (health.level) {
      case FinancialHealthLevel.excellent:
      case FinancialHealthLevel.good:
        if (s.currentMonthSavings > 0) {
          message =
              'Vas bien este mes. Tu estado financiero es ${health.levelLabel.toLowerCase()} y estás generando ahorro positivo.';
        } else {
          message =
              'Tu estado financiero es ${health.levelLabel.toLowerCase()}, aunque este mes aún no registras ahorro neto.';
        }
        break;
      case FinancialHealthLevel.fair:
        message =
            'Tu situación es regular (${health.score}/100). Hay margen para mejorar tus hábitos de gasto.';
        break;
      case FinancialHealthLevel.needsAttention:
        message =
            'Tu situación financiera necesita atención. Revisa los puntos marcados abajo.';
        break;
    }

    String? subtitle;
    if (context.hasPreviousMonthData) {
      final savingsDiff = s.currentMonthSavings - s.previousMonthSavings;
      if (savingsDiff > 0) {
        subtitle = 'Tu ahorro mensual mejoró respecto al mes anterior.';
      } else if (savingsDiff < 0) {
        subtitle = 'Tu ahorro mensual disminuyó respecto al mes anterior.';
      }
    }

    return ExecutiveSummary(message: message, subtitle: subtitle);
  }
}
