import 'package:flutter/material.dart';
import 'transaction.dart';
import '../utils/format_utils.dart';

// NUEVO: Clase auxiliar para manejar rangos de fechas
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

enum BudgetPeriod {
  weekly,
  monthly,
  yearly,
}

enum BudgetStatus {
  safe,      // Menos del 70%
  warning,   // 70% - 89%
  danger,    // 90% - 99%
  exceeded,  // 100% o más
}

class Budget {
  final String? id;
  final String name;
  final double amount;
  final BudgetPeriod period;
  final ExpenseCategory category; // Categoría del sistema
  final String? customCategoryId; // ID de categoría personalizada (opcional)
  final String? customCategoryName; // Nombre de categoría personalizada (para display)
  final String? customCategoryEmoji; // Emoji de categoría personalizada (para display)
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final bool alertsEnabled;
  final double alertThreshold; // Porcentaje para alertas (0.0 a 1.0)
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? lastResetDate; // Fecha del último reinicio
  final String accountId; // ID de la cuenta a la que pertenece

  Budget({
    this.id,
    required this.name,
    required this.amount,
    required this.period,
    required this.category,
    this.customCategoryId,
    this.customCategoryName,
    this.customCategoryEmoji,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.alertsEnabled = true,
    this.alertThreshold = 0.8, // 80% por defecto
    required this.createdAt,
    this.updatedAt,
    this.lastResetDate,
    required this.accountId,
  });

  /// Verifica si usa categoría personalizada
  bool get hasCustomCategory => customCategoryId != null && customCategoryId!.startsWith('custom_');

  // Getters calculados
  String get periodName {
    switch (period) {
      case BudgetPeriod.weekly:
        return 'Semanal';
      case BudgetPeriod.monthly:
        return 'Mensual';
      case BudgetPeriod.yearly:
        return 'Anual';
    }
  }

  // Método categoryName - soporta categorías personalizadas
  String get categoryName {
    // Si tiene categoría personalizada, usar el nombre guardado
    if (hasCustomCategory) {
      return customCategoryName ?? 'Otros';
    }

    switch (category) {
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
        return 'Otros';
    }
  }

  // Método categoryIcon - soporta categorías personalizadas
  String get categoryIcon {
    // Si tiene categoría personalizada, usar el emoji guardado
    if (hasCustomCategory) {
      return customCategoryEmoji ?? '📦';
    }

    switch (category) {
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
    }
  }

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays + 1;
  }

  bool get isCurrentlyActive {
    if (!isActive) return false; // Si está pausado, no está activo

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

    // Verificar si la fecha actual está dentro del rango del presupuesto
    return today.isAfter(startDay.subtract(const Duration(days: 1))) &&
        today.isBefore(endDay.add(const Duration(days: 1)));
  }

  // NUEVO: Método para verificar si el presupuesto está pausado
  bool get isPaused => !isActive;

  // NUEVO: Método para obtener el estado del presupuesto
  String get statusText {
    if (!isActive) return 'Pausado';
    if (!isCurrentlyActive) return 'Fuera de período';
    return 'Activo';
  }

  // NUEVO: Verificar si necesita reiniciarse
  // Se reinicia en cuanto el período actual ya terminó (endDate quedó en el
  // pasado), sin importar qué día de la semana/mes se abra la app. Antes solo
  // se evaluaba en el día exacto del reinicio (lunes/día 1/1 de enero), así
  // que un presupuesto podía quedar "Fuera de período" por tiempo indefinido
  // si la app no se abría justo ese día.
  bool get needsReset {
    final now = DateTime.now();
    if (!now.isAfter(endDate)) return false;

    // Si nunca se ha reiniciado, usar la fecha de creación
    final lastReset = lastResetDate ?? createdAt;
    return !_isSameDay(lastReset, now);
  }

  // Método auxiliar para comparar fechas (solo día, mes, año)
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // NUEVO: Calcular las nuevas fechas de inicio y fin después del reinicio
  DateRange getNextPeriodRange() {
    final now = DateTime.now();
    DateTime newStart;
    DateTime newEnd;

    switch (period) {
      case BudgetPeriod.weekly:
      // Nueva semana comienza el lunes actual
        newStart = _getMondayOfWeek(now);
        newEnd = newStart.add(const Duration(days: 6)); // Domingo
        break;

      case BudgetPeriod.monthly:
      // Nuevo mes comienza el primer día del mes actual
        newStart = DateTime(now.year, now.month, 1);
        // Último día del mes
        newEnd = DateTime(now.year, now.month + 1, 0);
        break;

      case BudgetPeriod.yearly:
      // Nuevo año comienza el 1 de enero
        newStart = DateTime(now.year, 1, 1);
        newEnd = DateTime(now.year, 12, 31);
        break;
    }

    return DateRange(start: newStart, end: newEnd);
  }

  // Método auxiliar para obtener el lunes de una semana
  DateTime _getMondayOfWeek(DateTime date) {
    final daysSinceMonday = date.weekday - DateTime.monday;
    return DateTime(date.year, date.month, date.day - daysSinceMonday);
  }

  // Calcular status basado en gasto actual
  BudgetStatus getStatus(double spentAmount) {
    final percentage = amount > 0 ? spentAmount / amount : 0.0;

    if (percentage >= 1.0) return BudgetStatus.exceeded;
    if (percentage >= 0.9) return BudgetStatus.danger;
    if (percentage >= 0.7) return BudgetStatus.warning;
    return BudgetStatus.safe;
  }

  // Obtener color según status
  static Color getStatusColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.safe:
        return const Color(0xFF059669); // Verde
      case BudgetStatus.warning:
        return const Color(0xFFF59E0B); // Amarillo
      case BudgetStatus.danger:
        return const Color(0xFFEF4444); // Naranja
      case BudgetStatus.exceeded:
        return const Color(0xFFDC2626); // Rojo
    }
  }

  static String getStatusMessage(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.safe:
        return 'Vas muy bien';
      case BudgetStatus.warning:
        return 'Cuidado con el gasto';
      case BudgetStatus.danger:
        return '¡Alerta! Cerca del límite';
      case BudgetStatus.exceeded:
        return 'Presupuesto excedido';
    }
  }

  // Serialización
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'period': period.index,
      'category': category.index,
      'customCategoryId': customCategoryId,
      'customCategoryName': customCategoryName,
      'customCategoryEmoji': customCategoryEmoji,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
      'alertsEnabled': alertsEnabled,
      'alertThreshold': alertThreshold,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastResetDate': lastResetDate?.toIso8601String(),
      'accountId': accountId,
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'],
      name: json['name'],
      amount: json['amount'].toDouble(),
      period: BudgetPeriod.values[json['period']],
      category: ExpenseCategory.values[json['category']],
      customCategoryId: json['customCategoryId'] as String?,
      customCategoryName: json['customCategoryName'] as String?,
      customCategoryEmoji: json['customCategoryEmoji'] as String?,
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      isActive: json['isActive'] ?? true,
      alertsEnabled: json['alertsEnabled'] ?? true,
      alertThreshold: json['alertThreshold']?.toDouble() ?? 0.8,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      lastResetDate: json['lastResetDate'] != null
          ? DateTime.parse(json['lastResetDate'])
          : null,
      accountId: json['accountId'] as String? ?? 'account_default',
    );
  }

  Budget copyWith({
    String? id,
    String? name,
    double? amount,
    BudgetPeriod? period,
    ExpenseCategory? category,
    String? customCategoryId,
    String? customCategoryName,
    String? customCategoryEmoji,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? alertsEnabled,
    double? alertThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastResetDate,
    String? accountId,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      category: category ?? this.category,
      customCategoryId: customCategoryId ?? this.customCategoryId,
      customCategoryName: customCategoryName ?? this.customCategoryName,
      customCategoryEmoji: customCategoryEmoji ?? this.customCategoryEmoji,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      lastResetDate: lastResetDate ?? this.lastResetDate,
      accountId: accountId ?? this.accountId,
    );
  }
}

// Clase auxiliar para manejar el progreso del presupuesto
class BudgetProgress {
  final Budget budget;
  final double spentAmount;
  final List<Transaction> transactions;

  BudgetProgress({
    required this.budget,
    required this.spentAmount,
    required this.transactions,
  });

  double get remainingAmount => budget.amount - spentAmount;
  double get percentage => (spentAmount / budget.amount).clamp(0.0, 1.0);
  BudgetStatus get status => budget.getStatus(spentAmount);

  double get dailyAverageSpent {
    final daysPassed = DateTime.now().difference(budget.startDate).inDays + 1;
    return daysPassed > 0 ? spentAmount / daysPassed : 0.0;
  }

  double get suggestedDailyLimit {
    return budget.daysRemaining > 0
        ? remainingAmount / budget.daysRemaining
        : 0.0;
  }

  bool get isOnTrack {
    if (budget.daysRemaining <= 0) return spentAmount <= budget.amount;
    return dailyAverageSpent <= suggestedDailyLimit;
  }

  String get progressMessage {
    if (status == BudgetStatus.exceeded) {
      return 'Has excedido tu presupuesto por ${FormatUtils.formatMoney(spentAmount - budget.amount)}';
    }

    if (budget.daysRemaining <= 0) {
      return isOnTrack
          ? 'Presupuesto completado exitosamente'
          : 'Presupuesto excedido';
    }

    if (isOnTrack) {
      return 'Vas bien, puedes gastar ${FormatUtils.formatMoney(suggestedDailyLimit)} diarios';
    } else {
      return 'Reduce el gasto a ${FormatUtils.formatMoney(suggestedDailyLimit)} diarios';
    }
  }
}