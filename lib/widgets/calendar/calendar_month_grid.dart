import 'package:flutter/material.dart';
import '../../models/calendar/month_calendar_data.dart';
import 'calendar_day_cell.dart';
import 'calendar_theme.dart';

/// Grid mensual (7 columnas, semana iniciando en Lunes) que dibuja las celdas
/// de cada día del mes. No hace scroll propio: se integra dentro del scroll de
/// la pantalla.
class CalendarMonthGrid extends StatelessWidget {
  final MonthCalendarData monthData;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const CalendarMonthGrid({
    super.key,
    required this.monthData,
    required this.selectedDay,
    required this.onDaySelected,
  });

  static const List<String> _weekDayLabels = [
    'L',
    'M',
    'M',
    'J',
    'V',
    'S',
    'D',
  ];

  @override
  Widget build(BuildContext context) {
    final month = monthData.month;
    final daysInMonth = monthData.daysInMonth;

    // Offset de días vacíos antes del día 1 (Lunes = 0 ... Domingo = 6).
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final leadingBlanks = firstWeekday - 1;

    final totalCells = leadingBlanks + daysInMonth;

    final now = DateTime.now();

    return Column(
      children: [
        Row(
          children: _weekDayLabels
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CalendarTheme.textLight,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.82,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            if (index < leadingBlanks) {
              return const SizedBox.shrink();
            }

            final dayNumber = index - leadingBlanks + 1;
            final date = DateTime(month.year, month.month, dayNumber);

            final isToday =
                date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;

            final isSelected =
                selectedDay != null &&
                selectedDay!.year == date.year &&
                selectedDay!.month == date.month &&
                selectedDay!.day == date.day;

            return CalendarDayCell(
              dayNumber: dayNumber,
              data: monthData.daysByNumber[dayNumber],
              isToday: isToday,
              isSelected: isSelected,
              onTap: () => onDaySelected(date),
            );
          },
        ),
      ],
    );
  }
}
