import 'package:flutter/material.dart';
import 'calendar_theme.dart';

/// Leyenda que explica los indicadores del calendario (v1).
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CalendarTheme.borderLight),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        children: const [
          _LegendItem(color: CalendarTheme.incomeGreen, label: 'Ingresos'),
          _LegendItem(color: CalendarTheme.expenseRed, label: 'Gastos'),
          _LegendItem(color: CalendarTheme.emptyGray, label: 'Sin movimientos'),
          _LegendItem(
            color: CalendarTheme.primaryBlue,
            label: 'Varios (+N)',
            isCounter: true,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isCounter;

  const _LegendItem({
    required this.color,
    required this.label,
    this.isCounter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCounter)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+N',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CalendarTheme.textMedium,
          ),
        ),
      ],
    );
  }
}
