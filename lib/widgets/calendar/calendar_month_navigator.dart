import 'package:flutter/material.dart';
import '../../utils/format_utils.dart';
import 'calendar_theme.dart';

/// Barra de navegación entre meses: botón anterior, etiqueta del mes/año,
/// botón siguiente y acceso rápido a "Hoy".
class CalendarMonthNavigator extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  /// Indica si el mes mostrado ya es el mes actual (para deshabilitar "Hoy").
  final bool isCurrentMonth;

  const CalendarMonthNavigator({
    super.key,
    required this.month,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.isCurrentMonth,
  });

  @override
  Widget build(BuildContext context) {
    final label = '${FormatUtils.getMonthName(month.month)} ${month.year}';

    return Row(
      children: [
        _navButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
        Expanded(
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: CalendarTheme.textDark,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        _navButton(icon: Icons.chevron_right_rounded, onTap: onNext),
        const SizedBox(width: 8),
        _todayButton(),
      ],
    );
  }

  Widget _navButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CalendarTheme.borderLight),
        ),
        child: Icon(icon, color: CalendarTheme.textDark, size: 24),
      ),
    );
  }

  Widget _todayButton() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isCurrentMonth ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: isCurrentMonth ? null : onToday,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: CalendarTheme.primaryBlue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text(
              'Hoy',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
