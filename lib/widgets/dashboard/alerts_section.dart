import 'package:flutter/material.dart';
import '../../models/dashboard/dashboard_alert.dart';
import '../../models/dashboard/dashboard_enums.dart';
import 'dashboard_message_tile.dart';
import 'dashboard_theme.dart';

class AlertsSection extends StatelessWidget {
  final List<DashboardAlert> alerts;

  const AlertsSection({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 12),
        ...alerts.map(
          (alert) => DashboardMessageTile(
            message: alert,
            badge: alert.severity == AlertSeverity.critical ? 'Crítico' : 'Atención',
            accentColor: alert.severity == AlertSeverity.critical
                ? DashboardTheme.dangerRed
                : DashboardTheme.warningYellow,
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        Icon(Icons.warning_rounded, color: DashboardTheme.dangerRed, size: 22),
        const SizedBox(width: 8),
        Text(
          'Requiere atención',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: DashboardTheme.textDark,
          ),
        ),
      ],
    );
  }
}
