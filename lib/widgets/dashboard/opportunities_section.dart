import 'package:flutter/material.dart';
import '../../models/dashboard/dashboard_opportunity.dart';
import 'dashboard_message_tile.dart';
import 'dashboard_theme.dart';

class OpportunitiesSection extends StatelessWidget {
  final List<DashboardOpportunity> opportunities;

  const OpportunitiesSection({super.key, required this.opportunities});

  @override
  Widget build(BuildContext context) {
    if (opportunities.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 12),
        ...opportunities.map(
          (o) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: DashboardTheme.cardDecoration(
              borderColor: DashboardTheme.successGreen.withValues(alpha: 0.3),
            ),
            child: Column(
              children: [
                DashboardMessageTile(
                  message: o,
                  badge: 'Oportunidad',
                  accentColor: DashboardTheme.successGreen,
                ),
                if (o.expectedBenefit.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 18, color: DashboardTheme.successGreen),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            o.expectedBenefit,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: DashboardTheme.successGreen,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        Icon(Icons.lightbulb_outline_rounded, color: DashboardTheme.successGreen, size: 22),
        const SizedBox(width: 8),
        Text(
          'Oportunidades',
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
