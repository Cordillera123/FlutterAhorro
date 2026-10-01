import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/calendar/day_calendar_data.dart';
import '../../models/calendar/month_calendar_data.dart';
import '../../screens/financial_calendar_screen.dart';
import '../../services/account_service.dart';
import '../../services/calendar_service.dart';
import '../../services/transaction_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/format_utils.dart';
import '../transaction_actions_sheet.dart';
import 'calendar_day_cell.dart';
import 'calendar_day_sheet.dart';
import 'calendar_legend.dart';
import 'calendar_month_grid.dart';

/// Calendario compacto para Inicio.
///
/// Por defecto muestra solo la semana actual (ocupa poco espacio); un toque en
/// el encabezado lo expande al mes completo. Cada día indica con puntos si
/// tiene ingresos (verde) y/o gastos (rojo), y al tocarlo abre el detalle del
/// día con sus transacciones.
///
/// No guarda ni calcula datos propios: lee de [CalendarService], que a su vez
/// agrega las transacciones de [TransactionService] (la misma fuente del
/// Historial), y se refresca cuando esas transacciones o la cuenta cambian.
class HomeCalendarCard extends StatefulWidget {
  const HomeCalendarCard({super.key});

  @override
  State<HomeCalendarCard> createState() => _HomeCalendarCardState();
}

class _HomeCalendarCardState extends State<HomeCalendarCard> {
  // CalendarService se instancia primero para que su listener (que invalida
  // la caché) quede registrado antes que el de este widget.
  final CalendarService _calendarService = CalendarService();
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  bool _expanded = false;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _transactionService.addListener(_onDataChanged);
    _accountService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _transactionService.removeListener(_onDataChanged);
    _accountService.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() => _expanded = !_expanded);
  }

  Future<void> _onDaySelected(DateTime day) async {
    HapticFeedback.selectionClick();
    setState(() => _selectedDay = day);

    final dayData = _calendarService.getDayData(day);
    await CalendarDaySheet.show(
      context,
      data: dayData,
      onMovementTap: (movement) {
        // Cierra el panel del día y abre el detalle con Editar/Eliminar.
        Navigator.of(context).pop();
        showTransactionActions(context, movement);
      },
    );
    if (mounted) setState(() => _selectedDay = null);
  }

  void _openFullCalendar() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FinancialCalendarScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthData = _calendarService.getMonthData(now);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
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
          _buildHeader(now),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    children: [
                      CalendarMonthGrid(
                        monthData: monthData,
                        selectedDay: _selectedDay,
                        onDaySelected: _onDaySelected,
                      ),
                      const SizedBox(height: 8),
                      const CalendarLegend(),
                    ],
                  )
                : _buildWeekStrip(now, monthData),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(DateTime now) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleExpanded,
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Calendario',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      Text(
                        '${FormatUtils.getMonthName(now.month)} ${now.year}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Ver calendario completo',
          onPressed: _openFullCalendar,
          icon: const Icon(
            Icons.open_in_full_rounded,
            size: 20,
            color: AppColors.primaryBlue,
          ),
        ),
      ],
    );
  }

  /// Semana actual (lunes a domingo). Si la semana cruza de mes, los días del
  /// otro mes se consultan igual a través de [CalendarService.getDayData].
  Widget _buildWeekStrip(DateTime now, MonthCalendarData monthData) {
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Row(
      children: List.generate(7, (i) {
        final date = DateTime(monday.year, monday.month, monday.day + i);
        final DayCalendarData? data =
            date.month == monthData.month.month &&
                date.year == monthData.month.year
            ? monthData.daysByNumber[date.day]
            : _calendarService.getDayData(date);

        final isSelected =
            _selectedDay != null &&
            _selectedDay!.year == date.year &&
            _selectedDay!.month == date.month &&
            _selectedDay!.day == date.day;

        return Expanded(
          child: Column(
            children: [
              Text(
                labels[i],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 52,
                child: CalendarDayCell(
                  dayNumber: date.day,
                  data: data,
                  isToday: date == today,
                  isSelected: isSelected,
                  onTap: () => _onDaySelected(date),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
