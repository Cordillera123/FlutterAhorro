import 'package:flutter/material.dart';
import '../../models/calendar/day_calendar_data.dart';
import 'calendar_theme.dart';

/// Celda individual de un día dentro del grid del calendario.
///
/// Indicadores (v1):
/// - 🟢 verde  -> el día tiene ingresos
/// - 🔴 rojo   -> el día tiene gastos
/// - ⚪ gris   -> el día no tiene movimientos
/// - contador  -> si hay más de un movimiento, se muestra "+N"
///
/// Es un widget de presentación puro: no accede a servicios.
class CalendarDayCell extends StatelessWidget {
  final int dayNumber;
  final DayCalendarData? data;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const CalendarDayCell({
    super.key,
    required this.dayNumber,
    required this.data,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasMovements = data?.hasMovements ?? false;
    final hasIncome = data?.hasIncome ?? false;
    final hasExpense = data?.hasExpense ?? false;
    final movementCount = data?.movementCount ?? 0;

    final Color background = isSelected
        ? CalendarTheme.primaryBlue
        : isToday
        ? CalendarTheme.primaryBlue.withValues(alpha: 0.10)
        : Colors.transparent;

    final Color numberColor = isSelected
        ? Colors.white
        : isToday
        ? CalendarTheme.primaryBlue
        : CalendarTheme.textDark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(
                  color: CalendarTheme.primaryBlue.withValues(alpha: 0.35),
                  width: 1,
                )
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isToday || isSelected
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: numberColor,
              ),
            ),
            const SizedBox(height: 4),
            _buildIndicator(
              hasMovements: hasMovements,
              hasIncome: hasIncome,
              hasExpense: hasExpense,
              movementCount: movementCount,
              selected: isSelected,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator({
    required bool hasMovements,
    required bool hasIncome,
    required bool hasExpense,
    required int movementCount,
    required bool selected,
  }) {
    // Sin movimientos -> punto gris (⚪).
    if (!hasMovements) {
      return _dot(
        selected
            ? Colors.white.withValues(alpha: 0.4)
            : CalendarTheme.emptyGray,
      );
    }

    // Varios movimientos -> contador compacto "+N".
    if (movementCount > 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.25)
              : CalendarTheme.primaryBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasIncome)
              _dot(
                selected ? Colors.white : CalendarTheme.incomeGreen,
                size: 5,
              ),
            if (hasIncome && hasExpense) const SizedBox(width: 2),
            if (hasExpense)
              _dot(selected ? Colors.white : CalendarTheme.expenseRed, size: 5),
            const SizedBox(width: 3),
            Text(
              '$movementCount',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : CalendarTheme.primaryBlue,
              ),
            ),
          ],
        ),
      );
    }

    // Un solo movimiento -> punto del color correspondiente.
    final Color color = hasIncome
        ? CalendarTheme.incomeGreen
        : CalendarTheme.expenseRed;
    return _dot(selected ? Colors.white : color);
  }

  Widget _dot(Color color, {double size = 6}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
