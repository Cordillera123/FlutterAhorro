import '../transaction.dart';
import 'calendar_movement_type.dart';

/// Datos financieros agregados de un único día del calendario.
///
/// Es un modelo de VISTA (no se persiste). Se construye una sola vez por mes
/// dentro de [CalendarService] y luego se reutiliza tanto para pintar la celda
/// del día como para el panel inferior de detalle.
class DayCalendarData {
  /// Fecha normalizada a medianoche (sin hora).
  final DateTime date;

  /// Movimientos del día ordenados cronológicamente (más antiguo primero).
  final List<Transaction> movements;

  final double totalIncome;
  final double totalExpense;

  const DayCalendarData({
    required this.date,
    required this.movements,
    required this.totalIncome,
    required this.totalExpense,
  });

  /// Día vacío (sin movimientos). Útil para celdas sin actividad.
  factory DayCalendarData.empty(DateTime date) {
    return DayCalendarData(
      date: DateTime(date.year, date.month, date.day),
      movements: const [],
      totalIncome: 0,
      totalExpense: 0,
    );
  }

  double get balance => totalIncome - totalExpense;

  int get movementCount => movements.length;

  bool get hasMovements => movements.isNotEmpty;

  bool get hasMultipleMovements => movementCount > 1;

  /// Indica si el día contiene al menos un ingreso.
  bool get hasIncome =>
      movements.any((m) => m.type == TransactionType.income);

  /// Indica si el día contiene al menos un gasto.
  bool get hasExpense =>
      movements.any((m) => m.type == TransactionType.expense);

  /// Indica si el día contiene al menos una transferencia.
  bool get hasTransfer =>
      movements.any((m) => m.type == TransactionType.transfer);

  /// Conteo de movimientos por tipo de calendario.
  ///
  /// Diseñado para escalar: al agregar `transfer` a [CalendarMovementType],
  /// este mapa lo reflejará automáticamente sin cambios en la celda.
  Map<CalendarMovementType, int> get countByType {
    final counts = <CalendarMovementType, int>{};
    for (final movement in movements) {
      final type = CalendarMovementType.fromTransaction(movement);
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }
}
