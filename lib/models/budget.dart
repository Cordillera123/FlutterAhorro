import 'package:flutter/material.dart';
import 'transaction.dart';
import '../utils/format_utils.dart';

// NUEVO: Clase auxiliar para manejar rangos de fechas
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}

enum BudgetPeriod { weekly, monthly, yearly }

enum BudgetStatus {
  safe, // Menos del 70%
  warning, // 70% - 89%
  danger, // 90% - 99%
  exceeded, // 100% o más
}

class Budget {
  final String? id;
  final String name;
  final double amount;
  final BudgetPeriod period;
  final ExpenseCategory category; // Categoría del sistema
  final String? customCategoryId; // ID de categoría personalizada (opcional)
  final String?
  customCategoryName; // Nombre de categoría personalizada (para display)
  final String?
  customCategoryEmoji; // Emoji de categoría personalizada (para display)
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
  bool get hasCustomCategory =>
      customCategoryId != null && customCategoryId!.startsWith('custom_');

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

  // Días que quedan contando hoy y el último día del período. Por días de
  // calendario (en UTC para que un cambio de horario no reste un día): antes,
  // durante todo el último día valía 0 y el presupuesto se daba por
  // "completado" aunque el día no hubiera terminado.
  int get daysRemaining {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final endDay = DateTime.utc(endDate.year, endDate.month, endDate.day);
    if (today.isAfter(endDay)) return 0;
    return endDay.difference(today).inDays + 1;
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
    // Recién cuando terminó el último día del período (endDate es la
    // medianoche de ese día).
    final today = DateTime(now.year, now.month, now.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);
    if (!today.isAfter(endDay)) return false;

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

  /// Porcentaje entero en el que el usuario pidió que se le avise (50–95).
  /// Redondeado: el control deslizante guarda valores como 0.6499999.
  int get alertPercent => (alertThreshold * 100).round();

  /// ¿Lo gastado llegó al porcentaje de alerta que eligió el usuario?
  /// Siempre `false` si desactivó las alertas.
  bool isAlertReached(double spentAmount) {
    if (!alertsEnabled || amount <= 0) return false;
    return spentAmount / amount * 100 >= alertPercent - 1e-9;
  }

  // Calcular status basado en gasto actual
  BudgetStatus getStatus(double spentAmount) {
    final percentage = amount > 0 ? spentAmount / amount : 0.0;

    if (percentage >= 1.0) return BudgetStatus.exceeded;
    if (percentage >= 0.9) return BudgetStatus.danger;
    if (percentage >= 0.7) return BudgetStatus.warning;
    // Si el usuario pidió que se le avise antes del 70 % (p. ej. al 50 %),
    // desde ese punto ya no "va muy bien". Con el valor por defecto (80 %)
    // esto no cambia nada.
    if (isAlertReached(spentAmount)) return BudgetStatus.warning;
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

/// Nivel de aviso de un presupuesto: aún nada, llegó al porcentaje de
/// alerta elegido, o llegó/superó el 100 %. El orden importa: solo se avisa
/// cuando el nivel sube.
enum BudgetAlertLevel { none, threshold, exceeded }

/// Aviso que se muestra cuando un gasto hace que un presupuesto cruce su
/// porcentaje de alerta o su límite.
class BudgetAlert {
  final Budget budget;
  final BudgetAlertLevel level;
  final double spentAmount;

  const BudgetAlert({
    required this.budget,
    required this.level,
    required this.spentAmount,
  });

  bool get isExceeded => level == BudgetAlertLevel.exceeded;

  /// Porcentaje usado redondeado para mostrar (180, 85…).
  int get usedPercent =>
      budget.amount > 0 ? (spentAmount / budget.amount * 100).round() : 0;

  String get title {
    if (!isExceeded) return 'Alerta de presupuesto';
    return spentAmount > budget.amount
        ? 'Presupuesto excedido'
        : 'Presupuesto al límite';
  }

  String get message {
    final name = '"${budget.name}"';
    if (!isExceeded) {
      final left = budget.amount - spentAmount;
      return '$name: ya usaste el $usedPercent % (tu alerta es al '
          '${budget.alertPercent} %). Te quedan '
          '${FormatUtils.formatMoney(left)}.';
    }
    if (spentAmount > budget.amount) {
      return '$name: gastaste ${FormatUtils.formatMoney(spentAmount)} de '
          '${FormatUtils.formatMoney(budget.amount)} ($usedPercent %). Te '
          'pasaste por ${FormatUtils.formatMoney(spentAmount - budget.amount)}.';
    }
    return '$name: llegaste al 100 % '
        '(${FormatUtils.formatMoney(budget.amount)}).';
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

  /// Fracción usada para la barra de progreso (0 a 1). Con un monto de 0 la
  /// división daba NaN y la barra quedaba rota.
  double get percentage => usedFraction.clamp(0.0, 1.0);

  /// Fracción realmente usada, sin tope: 1,5 = 150 % (presupuesto excedido).
  /// Es la que se muestra como porcentaje; antes se mostraba "100%" aunque
  /// se hubiera gastado el doble.
  double get usedFraction {
    if (budget.amount <= 0) return spentAmount > 0 ? 1.0 : 0.0;
    return spentAmount / budget.amount;
  }

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
