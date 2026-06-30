/// Modelo para categorías de gastos personalizadas creadas por el usuario.
/// Las categorías del sistema (ExpenseCategory enum) no se pueden modificar.
class CustomCategory {
  final String id;
  final String name;
  final String emoji;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? accountId; // ID de la cuenta a la que pertenece

  CustomCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.createdAt,
    this.updatedAt,
    this.accountId,
  });

  /// Crea una copia con campos modificados
  CustomCategory copyWith({
    String? id,
    String? name,
    String? emoji,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? accountId,
  }) {
    return CustomCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      accountId: accountId ?? this.accountId,
    );
  }

  /// Convierte a JSON para persistencia
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'accountId': accountId,
    };
  }

  /// Crea instancia desde JSON
  factory CustomCategory.fromJson(Map<String, dynamic> json) {
    return CustomCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      accountId: json['accountId'] as String?,
    );
  }

  /// Genera un ID único para nuevas categorías
  static String generateId() {
    return 'custom_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  String toString() {
    return 'CustomCategory(id: $id, name: $name, emoji: $emoji)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
