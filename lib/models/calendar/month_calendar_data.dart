import 'day_calendar_data.dart';

/// Datos agregados de un mes completo para el Calendario Financiero.
///
/// Contiene el resumen mensual (para las tarjetas superiores) y el detalle
/// por día indexado por número de día (1..N) para acceso O(1) desde la celda.
/// Es un modelo de VISTA cacheable; no se persiste.
class MonthCalendarData {
  /// Primer día del mes (año/mes de referencia, día = 1).
  final DateTime month;

  /// Detalle por día, indexado por número de día del mes (1..daysInMonth).
  final Map<int, DayCalendarData> daysByNumber;

  final double totalIncome;
  final double totalExpense;
  final int movementCount;

  const MonthCalendarData({
    required this.month,
    required this.daysByNumber,
    required this.totalIncome,
    required this.totalExpense,
    required this.movementCount,
  });

  /// Mes vacío (sin datos). Se usa como estado inicial seguro.
  factory MonthCalendarData.empty(DateTime month) {
    return MonthCalendarData(
      month: DateTime(month.year, month.month, 1),
      daysByNumber: const {},
      totalIncome: 0,
      totalExpense: 0,
      movementCount: 0,
    );
  }

  double get balance => totalIncome - totalExpense;

  bool get hasData => movementCount > 0;

  /// Cantidad de días del mes.
  int get daysInMonth => DateTime(month.year, month.month + 1, 0).day;

  /// Retorna los datos de un día (acceso O(1)) o un día vacío si no hay
  /// movimientos registrados.
  DayCalendarData dayData(int dayNumber) {
    return daysByNumber[dayNumber] ??
        DayCalendarData.empty(DateTime(month.year, month.month, dayNumber));
  }
}
