import '../transaction.dart';

/// Tipo de movimiento representado en el Calendario Financiero.
///
/// v1: solo maneja ingresos y gastos (los movimientos que afectan
/// directamente el flujo financiero del usuario).
///
/// EXTENSIBILIDAD (versión futura): para incorporar transferencias basta con
/// agregar el valor `transfer` a este enum y su rama en [fromTransaction].
/// El resto de la arquitectura (servicio, celdas, leyenda) consume este enum,
/// por lo que no será necesario refactorizar la lógica de agrupación.
enum CalendarMovementType {
  income,
  expense;
  // transfer, // <- Futuro: transferencias entre cuentas.

  /// Deriva el tipo de calendario a partir de una [Transaction].
  static CalendarMovementType fromTransaction(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.income:
        return CalendarMovementType.income;
      case TransactionType.expense:
        return CalendarMovementType.expense;
    }
  }
}
