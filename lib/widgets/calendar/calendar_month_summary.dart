import 'package:flutter/material.dart';
import '../../models/calendar/month_calendar_data.dart';
import '../../utils/format_utils.dart';
import 'calendar_theme.dart';

/// Tarjetas de resumen del mes: ingresos, gastos, balance y cantidad de
/// movimientos. Widget de presentación puro.
class CalendarMonthSummary extends StatelessWidget {
  final MonthCalendarData monthData;

  const CalendarMonthSummary({super.key, required this.monthData});

  @override
  Widget build(BuildContext context) {
    final balance = monthData.balance;
    final balanceColor = balance >= 0
        ? CalendarTheme.incomeGreen
        : CalendarTheme.expenseRed;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.arrow_downward_rounded,
                label: 'Ingresos',
                value: FormatUtils.formatMoney(monthData.totalIncome),
                color: CalendarTheme.incomeGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                icon: Icons.arrow_upward_rounded,
                label: 'Gastos',
                value: FormatUtils.formatMoney(monthData.totalExpense),
                color: CalendarTheme.expenseRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Balance',
                value: FormatUtils.formatMoney(balance),
                color: balanceColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                icon: Icons.swap_vert_rounded,
                label: 'Movimientos',
                value: '${monthData.movementCount}',
                color: CalendarTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CalendarTheme.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CalendarTheme.textMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
