import 'package:json_annotation/json_annotation.dart';

// Esto le dice a Dart que genere código automáticamente
part 'transaction.g.dart';

// Enum para los tipos de transacción
enum TransactionType {
  income,   // Ingreso
  expense   // Gasto
}

// Enum para las categorías de gastos del sistema (no modificables)
enum ExpenseCategory {
  transport,      // Transporte
  food,          // Alimentación
  utilities,      // Servicios Básicos
  health,         // Salud
  education,      // Educación
  entertainment,  // Entretenimiento
  clothing,       // Ropa y Calzado
  home,          // Hogar y Muebles
  technology,    // Tecnología
  savings,       // Ahorros e Inversión
  gifts,         // Regalos y Donaciones
  other          // Otros
}

// Enum para las categorías de ingresos
enum IncomeCategory {
  salary,       // Salario
  freelance,    // Freelance/Independiente
  business,     // Negocio
  investment,   // Inversiones
  rental,       // Alquiler/Renta
  bonus,        // Bonificación
  commission,   // Comisión
  refund,       // Reembolso
  gift,         // Regalo
  extra,        // Extra
  other         // Otros
}

@JsonSerializable()
class Transaction {
  final String id;
  final double amount;           // Monto
  final TransactionType type;    // Tipo: ingreso o gasto
  final String description;      // Descripción
  final DateTime date;          // Fecha
  final ExpenseCategory? expenseCategory;  // Categoría de gasto del sistema (opcional)
  final IncomeCategory? incomeCategory;    // Categoría de ingreso (opcional)
  final String? customCategoryId;  // ID de categoría personalizada (opcional)
  final String? customCategoryName; // Nombre de categoría personalizada (para historial)
  final String? customCategoryEmoji; // Emoji de categoría personalizada (para historial)
  final String accountId; // ID de la cuenta a la que pertenece

  Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.description,
    required this.date,
    this.expenseCategory,
    this.incomeCategory,
    this.customCategoryId,
    this.customCategoryName,
    this.customCategoryEmoji,
    required this.accountId,
  });

  /// Verifica si usa categoría personalizada
  bool get hasCustomCategory => customCategoryId != null && customCategoryId!.startsWith('custom_');

  // Métodos para convertir de/hacia JSON (manual para soportar campos nuevos)
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
            (e) => e.name == json['type'] || e.index == json['type'],
        orElse: () => TransactionType.expense,
      ),
      description: json['description'] as String,
      date: DateTime.parse(json['date'] as String),
      expenseCategory: json['expenseCategory'] != null
          ? ExpenseCategory.values.firstWhere(
            (e) => e.name == json['expenseCategory'] || e.index == json['expenseCategory'],
        orElse: () => ExpenseCategory.other,
      )
          : null,
      incomeCategory: json['incomeCategory'] != null
          ? IncomeCategory.values.firstWhere(
            (e) => e.name == json['incomeCategory'] || e.index == json['incomeCategory'],
        orElse: () => IncomeCategory.other,
      )
          : null,
      customCategoryId: json['customCategoryId'] as String?,
      customCategoryName: json['customCategoryName'] as String?,
      customCategoryEmoji: json['customCategoryEmoji'] as String?,
      accountId: json['accountId'] as String? ?? 'account_default',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'type': type.name,
      'description': description,
      'date': date.toIso8601String(),
      'expenseCategory': expenseCategory?.name,
      'incomeCategory': incomeCategory?.name,
      'customCategoryId': customCategoryId,
      'customCategoryName': customCategoryName,
      'customCategoryEmoji': customCategoryEmoji,
      'accountId': accountId,
    };
  }

  /// Crea una copia con categoría reasignada a "Otros"
  Transaction copyWithCategoryAsOther() {
    return Transaction(
      id: id,
      amount: amount,
      type: type,
      description: description,
      date: date,
      expenseCategory: ExpenseCategory.other,
      incomeCategory: incomeCategory,
      customCategoryId: null,
      customCategoryName: null,
      customCategoryEmoji: null,
      accountId: accountId,
    );
  }

  /// Crea una copia con campos modificados
  Transaction copyWith({
    String? id,
    double? amount,
    TransactionType? type,
    String? description,
    DateTime? date,
    ExpenseCategory? expenseCategory,
    IncomeCategory? incomeCategory,
    String? customCategoryId,
    String? customCategoryName,
    String? customCategoryEmoji,
    String? accountId,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      description: description ?? this.description,
      date: date ?? this.date,
      expenseCategory: expenseCategory ?? this.expenseCategory,
      incomeCategory: incomeCategory ?? this.incomeCategory,
      customCategoryId: customCategoryId ?? this.customCategoryId,
      customCategoryName: customCategoryName ?? this.customCategoryName,
      customCategoryEmoji: customCategoryEmoji ?? this.customCategoryEmoji,
      accountId: accountId ?? this.accountId,
    );
  }

  // Método para obtener el nombre de la categoría en español
  String get categoryName {
    // Si tiene categoría personalizada, usar el nombre guardado
    if (hasCustomCategory) {
      return customCategoryName ?? 'Otros';
    }

    if (type == TransactionType.income) {
      switch (incomeCategory) {
        case IncomeCategory.salary:
          return 'Salario';
        case IncomeCategory.freelance:
          return 'Freelance';
        case IncomeCategory.business:
          return 'Negocio';
        case IncomeCategory.investment:
          return 'Inversiones';
        case IncomeCategory.rental:
          return 'Alquiler';
        case IncomeCategory.bonus:
          return 'Bonificación';
        case IncomeCategory.commission:
          return 'Comisión';
        case IncomeCategory.refund:
          return 'Reembolso';
        case IncomeCategory.gift:
          return 'Regalo';
        case IncomeCategory.extra:
          return 'Extra';
        case IncomeCategory.other:
          return 'Otros ingresos';
        default:
          return 'Ingreso';
      }
    } else {
      switch (expenseCategory) {
        case ExpenseCategory.transport:
          return 'Transporte';
        case ExpenseCategory.food:
          return 'Alimentación';
        case ExpenseCategory.utilities:
          return 'Servicios Básicos';
        case ExpenseCategory.health:
          return 'Salud';
        case ExpenseCategory.education:
          return 'Educación';
        case ExpenseCategory.entertainment:
          return 'Entretenimiento';
        case ExpenseCategory.clothing:
          return 'Ropa y Calzado';
        case ExpenseCategory.home:
          return 'Hogar y Muebles';
        case ExpenseCategory.technology:
          return 'Tecnología';
        case ExpenseCategory.savings:
          return 'Ahorros e Inversión';
        case ExpenseCategory.gifts:
          return 'Regalos y Donaciones';
        case ExpenseCategory.other:
          return 'Otros gastos';
        default:
          return 'Gasto';
      }
    }
  }

  // Método para obtener el ícono de la categoría
  String get categoryIcon {
    // Si tiene categoría personalizada, usar el emoji guardado
    if (hasCustomCategory) {
      return customCategoryEmoji ?? '📦';
    }

    if (type == TransactionType.income) {
      switch (incomeCategory) {
        case IncomeCategory.salary:
          return '💼';
        case IncomeCategory.freelance:
          return '💻';
        case IncomeCategory.business:
          return '🏪';
        case IncomeCategory.investment:
          return '📈';
        case IncomeCategory.rental:
          return '🏠';
        case IncomeCategory.bonus:
          return '🎯';
        case IncomeCategory.commission:
          return '🤝';
        case IncomeCategory.refund:
          return '↩️';
        case IncomeCategory.gift:
          return '🎁';
        case IncomeCategory.extra:
          return '⭐';
        case IncomeCategory.other:
          return '💰';
        default:
          return '💵';
      }
    } else {
      switch (expenseCategory) {
        case ExpenseCategory.transport:
          return '🚗';
        case ExpenseCategory.food:
          return '🍕';
        case ExpenseCategory.utilities:
          return '💡';
        case ExpenseCategory.health:
          return '🏥';
        case ExpenseCategory.education:
          return '📚';
        case ExpenseCategory.entertainment:
          return '🎬';
        case ExpenseCategory.clothing:
          return '👕';
        case ExpenseCategory.home:
          return '🏠';
        case ExpenseCategory.technology:
          return '📱';
        case ExpenseCategory.savings:
          return '💰';
        case ExpenseCategory.gifts:
          return '🎁';
        case ExpenseCategory.other:
          return '📦';
        default:
          return '💸';
      }
    }
  }
}