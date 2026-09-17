import 'package:flutter/material.dart';
import '../../models/dashboard/dashboard_forecast.dart';
import '../../models/dashboard/dashboard_enums.dart';
import 'dashboard_message_tile.dart';
import 'dashboard_theme.dart';

class ForecastsSection extends StatelessWidget {
  final List<DashboardForecast> forecasts;

  const ForecastsSection({super.key, required this.forecasts});

  @override
  Widget build(BuildContext context) {
    if (forecasts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 12),
        ...forecasts.map(
          (f) => DashboardMessageTile(
            message: f,
            badge: _confidenceLabel(f.confidence),
            accentColor: DashboardTheme.primaryPurple,
          ),
        ),
      ],
    );
  }

  String _confidenceLabel(PredictionConfidence c) {
    switch (c) {
      case PredictionConfidence.high:
        return 'Alta confianza';
      case PredictionConfidence.medium:
        return 'Estimación';
      case PredictionConfidence.low:
        return 'Preliminar';
    }
  }

  Widget _header() {
    return Row(
      children: [
        Icon(Icons.timeline_rounded, color: DashboardTheme.primaryPurple, size: 22),
        const SizedBox(width: 8),
        Text(
          'Lo que viene',
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
