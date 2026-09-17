import 'package:flutter/material.dart';
import '../../models/dashboard/dashboard_observation.dart';
import 'dashboard_message_tile.dart';
import 'dashboard_theme.dart';

class ObservationsSection extends StatelessWidget {
  final List<DashboardObservation> observations;

  const ObservationsSection({super.key, required this.observations});

  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 12),
        ...observations.map(
          (o) => DashboardMessageTile(
            message: o,
            badge: o.dimensionLabel,
            accentColor: DashboardTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        Icon(Icons.analytics_outlined, color: DashboardTheme.primaryBlue, size: 22),
        const SizedBox(width: 8),
        Text(
          'Tu análisis',
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
