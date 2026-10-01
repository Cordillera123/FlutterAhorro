import 'package:flutter/material.dart';

/// Tipos de cuenta predefinidos
enum AccountType {
  main, // Principal
  savings, // Ahorros
  investment, // Inversiones
  work, // Trabajo
  personal, // Personal
  business, // Negocio
  emergency, // Emergencia
  education, // Educación
  family, // Familia
  other, // Otro
}

/// Modelo para cuentas financieras del usuario.
/// Cada cuenta tiene sus propias transacciones, presupuestos, metas,
/// gastos recurrentes y categorías personalizadas.
class Account {
  final String id;
  final String name;
  final AccountType type;
  final String emoji;
  final Color color;
  final bool isDefault; // La cuenta principal por defecto
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Balance de apertura de la cuenta. Se suma al balance calculado
  /// desde transacciones, permitiendo reflejar dinero previo a la app.
  final double initialBalance;

  Account({
    required this.id,
    required this.name,
    required this.type,
    this.emoji = '💼',
    this.color = const Color(0xFF3B82F6),
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
    this.initialBalance = 0.0,
  });

  /// Genera un ID único para nuevas cuentas
  static String generateId() {
    return 'account_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// ID fijo para la cuenta principal por defecto (migración de datos existentes)
  static const String defaultAccountId = 'account_default';

  /// Crea la cuenta principal por defecto
  factory Account.defaultAccount() {
    return Account(
      id: defaultAccountId,
      name: 'Cuenta Principal',
      type: AccountType.main,
      emoji: '🏦',
      color: const Color(0xFF3B82F6),
      isDefault: true,
      createdAt: DateTime.now(),
    );
  }

  // Nombre descriptivo del tipo de cuenta
  String get typeName {
    switch (type) {
      case AccountType.main:
        return 'Principal';
      case AccountType.savings:
        return 'Ahorros';
      case AccountType.investment:
        return 'Inversiones';
      case AccountType.work:
        return 'Trabajo';
      case AccountType.personal:
        return 'Personal';
      case AccountType.business:
        return 'Negocio';
      case AccountType.emergency:
        return 'Emergencia';
      case AccountType.education:
        return 'Educación';
      case AccountType.family:
        return 'Familia';
      case AccountType.other:
        return 'Otro';
    }
  }

  /// Emoji por defecto según el tipo de cuenta
  static String defaultEmojiForType(AccountType type) {
    switch (type) {
      case AccountType.main:
        return '🏦';
      case AccountType.savings:
        return '🐷';
      case AccountType.investment:
        return '📈';
      case AccountType.work:
        return '💼';
      case AccountType.personal:
        return '👤';
      case AccountType.business:
        return '🏪';
      case AccountType.emergency:
        return '🚨';
      case AccountType.education:
        return '🎓';
      case AccountType.family:
        return '👨‍👩‍👧‍👦';
      case AccountType.other:
        return '📂';
    }
  }

  /// Color por defecto según el tipo de cuenta
  static Color defaultColorForType(AccountType type) {
    switch (type) {
      case AccountType.main:
        return const Color(0xFF3B82F6); // Azul
      case AccountType.savings:
        return const Color(0xFF059669); // Verde
      case AccountType.investment:
        return const Color(0xFF7C3AED); // Morado
      case AccountType.work:
        return const Color(0xFFF59E0B); // Amarillo
      case AccountType.personal:
        return const Color(0xFF06B6D4); // Cyan
      case AccountType.business:
        return const Color(0xFFEF4444); // Rojo
      case AccountType.emergency:
        return const Color(0xFFDC2626); // Rojo oscuro
      case AccountType.education:
        return const Color(0xFF8B5CF6); // Violeta
      case AccountType.family:
        return const Color(0xFFEC4899); // Rosa
      case AccountType.other:
        return const Color(0xFF6B7280); // Gris
    }
  }

  /// Crea una copia con campos modificados
  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? emoji,
    Color? color,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? initialBalance,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      initialBalance: initialBalance ?? this.initialBalance,
    );
  }

  /// Convierte a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'emoji': emoji,
      'color': color.value,
      'isDefault': isDefault,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'initialBalance': initialBalance,
    };
  }

  /// Crea instancia desde JSON (con backward compatibility)
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      name: json['name'] as String,
      type: AccountType.values[json['type'] as int? ?? 0],
      emoji: json['emoji'] as String? ?? '💼',
      color: Color(json['color'] as int? ?? 0xFF3B82F6),
      isDefault: json['isDefault'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      // backward compatible: cuentas antiguas parten desde 0
      initialBalance: (json['initialBalance'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'Account(id: $id, name: $name, type: $typeName, emoji: $emoji)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Account && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
