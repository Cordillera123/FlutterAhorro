import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/dashboard/dashboard_enums.dart';
import '../../models/dashboard/financial_health_state.dart';
import 'dashboard_theme.dart';

class FinancialHealthSection extends StatefulWidget {
  final FinancialHealthState health;

  const FinancialHealthSection({super.key, required this.health});

  @override
  State<FinancialHealthSection> createState() => _FinancialHealthSectionState();
}

class _FinancialHealthSectionState extends State<FinancialHealthSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final health = widget.health;
    final color = DashboardTheme.healthColor(health.score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Estado financiero',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: DashboardTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: DashboardTheme.cardDecoration(
            borderColor: color.withValues(alpha: 0.3),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CustomPaint(
                      painter: _ScoreRingPainter(
                        score: health.score,
                        color: color,
                      ),
                      child: Center(
                        child: Text(
                          '${health.score}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          health.levelLabel,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: DashboardTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Basado en ${health.activeFactorCount} de ${health.totalFactorCount} factores',
                          style: TextStyle(
                            color: DashboardTheme.textMedium,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (health.observations.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...health.observations.map(_observationRow),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(
                  _expanded ? 'Ocultar desglose' : 'Ver desglose del puntaje',
                ),
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                ...health.factors.map(_factorRow),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _observationRow(HealthObservation obs) {
    final icon = switch (obs.sentiment) {
      HealthFactorSentiment.positive => Icons.check_circle_outline,
      HealthFactorSentiment.warning => Icons.warning_amber_rounded,
      HealthFactorSentiment.negative => Icons.cancel_outlined,
      HealthFactorSentiment.neutral => Icons.info_outline,
    };
    final color = switch (obs.sentiment) {
      HealthFactorSentiment.positive => DashboardTheme.successGreen,
      HealthFactorSentiment.warning => DashboardTheme.warningYellow,
      HealthFactorSentiment.negative => DashboardTheme.dangerRed,
      HealthFactorSentiment.neutral => DashboardTheme.textMedium,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              obs.message,
              style: TextStyle(color: DashboardTheme.textMedium, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _factorRow(HealthFactor factor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  factor.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: DashboardTheme.textDark,
                  ),
                ),
                Text(
                  factor.explanation,
                  style: TextStyle(
                    fontSize: 12,
                    color: DashboardTheme.textMedium,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${factor.rawScore}/100',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: DashboardTheme.textDark,
                ),
              ),
              Text(
                '+${factor.contributionPoints.toStringAsFixed(0)} pts',
                style: TextStyle(
                  fontSize: 11,
                  color: DashboardTheme.textMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final int score;
  final Color color;

  _ScoreRingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 8.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke;
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    final sweep = (score / 100) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
