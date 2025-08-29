import 'package:json_annotation/json_annotation.dart';

// Esto le dice a Dart que genere código automáticamente
part 'transaction.g.dart';

// Enum para los tipos de transacción
enum TransactionType {
  income,   // Ingreso
  expense   // Gasto
}

// Enum para las categorías de gastos
enum ExpenseCategory {
  transport,      // Transporte
  shopping,       // Compras
  food,          // Comida
  entertainment, // Entretenimiento
  other          // Otros
}

// Enum para las categorías de ingresos
enum IncomeCategory {
  salary,    // Salario
  extra,     // Extra
  gift,      // Regalo
  other      // Otros
}

@JsonSerializable()
class Transaction {
  final String id;
  final double amount;           // Monto
  final TransactionType type;    // Tipo: ingreso o gasto
  final String description;      // Descripción
  final DateTime date;          // Fecha
  final ExpenseCategory? expenseCategory;  // Categoría de gasto (opcional)
  final IncomeCategory? incomeCategory;    // Categoría de ingreso (opcional)

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.date,
    this.expenseCategory,
    this.incomeCategory,
  });

  // Métodos para convertir de/hacia JSON
  factory Transaction.fromJson(Map<String, dynamic> json) =>
      _$TransactionFromJson(json);

  Map<String, dynamic> toJson() => _$TransactionToJson(this);

  // Método para obtener el nombre de la categoría en español
  String get categoryName {
    if (type == TransactionType.income) {
      switch (incomeCategory) {
        case IncomeCategory.salary:
          return 'Salario';
        case IncomeCategory.extra:
          return 'Extra';
        case IncomeCategory.gift:
          return 'Regalo';
        case IncomeCategory.other:
          return 'Otros ingresos';
        default:
          return 'Ingreso';
      }
    } else {
      switch (expenseCategory) {
        case ExpenseCategory.transport:
          return 'Transporte';
        case ExpenseCategory.shopping:
          return 'Compras';
        case ExpenseCategory.food:
          return 'Comida';
        case ExpenseCategory.entertainment:
          return 'Entretenimiento';
        case ExpenseCategory.other:
          return 'Otros gastos';
        default:
          return 'Gasto';
      }
    }
  }

  // Método para obtener el ícono de la categoría
  String get categoryIcon {
    if (type == TransactionType.income) {
      switch (incomeCategory) {
        case IncomeCategory.salary:
          return '💼';
        case IncomeCategory.extra:
          return '⭐';
        case IncomeCategory.gift:
          return '🎁';
        case IncomeCategory.other:
          return '💰';
        default:
          return '💵';
      }
    } else {
      switch (expenseCategory) {
        case ExpenseCategory.transport:
          return '🚗';
        case ExpenseCategory.shopping:
          return '🛍️';
        case ExpenseCategory.food:
          return '🍕';
        case ExpenseCategory.entertainment:
          return '🎬';
        case ExpenseCategory.other:
          return '📦';
        default:
          return '💸';
      }
    }
  }
}