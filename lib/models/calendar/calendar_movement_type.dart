import '../transaction.dart';

/// Tipo de movimiento representado en el Calendario Financiero.
enum CalendarMovementType {
  income,
  expense,
  transfer;

  /// Deriva el tipo de calendario a partir de una [Transaction].
  static CalendarMovementType fromTransaction(Transaction transaction) {
    switch (transaction.type) {
      case TransactionType.income:
        return CalendarMovementType.income;
      case TransactionType.expense:
        return CalendarMovementType.expense;
      case TransactionType.transfer:
        return CalendarMovementType.transfer;
    }
  }
}
