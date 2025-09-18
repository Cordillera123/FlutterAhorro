import 'package:flutter/material.dart';
import 'transaction.dart';
import '../utils/format_utils.dart';

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
  final ExpenseCategory category;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final bool alertsEnabled;
  final double alertThreshold; // Porcentaje para alertas (0.0 a 1.0)
  final DateTime createdAt;
  final DateTime? updatedAt;

  Budget({
    this.id,
    required this.name,
    required this.amount,
    required this.period,
    required this.category,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.alertsEnabled = true,
    this.alertThreshold = 0.8, // 80% por defecto
    required this.createdAt,
    this.updatedAt,
  });

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

  // ACTUALIZADO - Método categoryName con todas las categorías
  String get categoryName {
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

  // ACTUALIZADO - Método categoryIcon con todas las categorías
  String get categoryIcon {
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

  // Calcular status basado en gasto actual
  BudgetStatus getStatus(double spentAmount) {
    final percentage = spentAmount / amount;

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
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': isActive,
      'alertsEnabled': alertsEnabled,
      'alertThreshold': alertThreshold,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Budget.fromJson(Map<String, dynamic> json) {
    return Budget(
      id: json['id'],
      name: json['name'],
      amount: json['amount'].toDouble(),
      period: BudgetPeriod.values[json['period']],
      category: ExpenseCategory.values[json['category']],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      isActive: json['isActive'] ?? true,
      alertsEnabled: json['alertsEnabled'] ?? true,
      alertThreshold: json['alertThreshold']?.toDouble() ?? 0.8,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Budget copyWith({
    String? id,
    String? name,
    double? amount,
    BudgetPeriod? period,
    ExpenseCategory? category,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    bool? alertsEnabled,
    double? alertThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      category: category ?? this.category,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      alertsEnabled: alertsEnabled ?? this.alertsEnabled,
      alertThreshold: alertThreshold ?? this.alertThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
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