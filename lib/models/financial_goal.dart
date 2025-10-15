import 'package:flutter/material.dart';
import '../utils/format_utils.dart';

enum GoalType {
  purchase,    // Comprar algo específico (moto, carro, etc.)
  savings,     // Ahorrar dinero general
  emergency,   // Fondo de emergencia
  vacation,    // Viaje o vacaciones
  education,   // Educación o cursos
  custom,      // Meta personalizada
}

enum GoalPriority {
  low,
  medium,
  high,
  urgent,
}

enum GoalStatus {
  active,
  paused,
  completed,
  cancelled,
}

enum AutoSaveFrequency {
  daily,
  weekly,
  monthly,
}

class FinancialGoal {
  final String? id;
  final String name;
  final String description;
  final double targetAmount;
  final double currentAmount;
  final DateTime startDate;
  final DateTime targetDate;
  final GoalType type;
  final GoalPriority priority;
  final GoalStatus status;
  final String emoji;
  final double monthlyContribution;
  final double suggestedContribution;
  final bool autoSave;
  final AutoSaveFrequency autoSaveFrequency;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  FinancialGoal({
    this.id,
    required this.name,
    required this.description,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.startDate,
    required this.targetDate,
    required this.type,
    this.priority = GoalPriority.medium,
    this.status = GoalStatus.active,
    this.emoji = '🎯',
    this.monthlyContribution = 0.0,
    this.suggestedContribution = 0.0,
    this.autoSave = false,
    this.autoSaveFrequency = AutoSaveFrequency.monthly,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  // Getters calculados
  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, double.infinity);
  double get progressPercentage => (currentAmount / targetAmount).clamp(0.0, 1.0);

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(targetDate)) return 0;
    return targetDate.difference(now).inDays + 1;
  }

  int get monthsRemaining {
    final now = DateTime.now();
    if (now.isAfter(targetDate)) return 0;
    int months = (targetDate.year - now.year) * 12 + targetDate.month - now.month;
    return months > 0 ? months : 0;
  }

  double get requiredMonthlyContribution {
    if (monthsRemaining <= 0) return remainingAmount;
    return remainingAmount / monthsRemaining;
  }

  double get requiredWeeklyContribution {
    final weeksRemaining = daysRemaining / 7;
    if (weeksRemaining <= 0) return remainingAmount;
    return remainingAmount / weeksRemaining;
  }

  double get requiredDailyContribution {
    if (daysRemaining <= 0) return remainingAmount;
    return remainingAmount / daysRemaining;
  }

  // Calcular contribución sugerida basada en la frecuencia seleccionada
  double calculateSuggestedContribution() {
    switch (autoSaveFrequency) {
      case AutoSaveFrequency.daily:
        return requiredDailyContribution;
      case AutoSaveFrequency.weekly:
        return requiredWeeklyContribution;
      case AutoSaveFrequency.monthly:
        return requiredMonthlyContribution;
    }
  }

  // Validar que la contribución no exceda el monto objetivo
  bool isContributionValid(double contribution) {
    return contribution > 0 && contribution <= remainingAmount;
  }

  // Obtener la próxima fecha de contribución automática
  DateTime? get nextAutoSaveDate {
    if (!autoSave) return null;
    
    final now = DateTime.now();
    switch (autoSaveFrequency) {
      case AutoSaveFrequency.daily:
        return DateTime(now.year, now.month, now.day + 1);
      case AutoSaveFrequency.weekly:
        return now.add(Duration(days: 7 - now.weekday + 1));
      case AutoSaveFrequency.monthly:
        return DateTime(now.year, now.month + 1, now.day);
    }
  }

  bool get isOnTrack {
    if (status == GoalStatus.completed) return true;
    if (daysRemaining <= 0) return currentAmount >= targetAmount;

    final totalDays = targetDate.difference(startDate).inDays;
    final daysPassed = DateTime.now().difference(startDate).inDays;
    final expectedProgress = daysPassed / totalDays;

    return progressPercentage >= expectedProgress;
  }

  bool get isCompleted => currentAmount >= targetAmount;
  bool get isOverdue => DateTime.now().isAfter(targetDate) && !isCompleted;

  // Nombres descriptivos
  String get typeName {
    switch (type) {
      case GoalType.purchase:
        return 'Compra';
      case GoalType.savings:
        return 'Ahorro';
      case GoalType.emergency:
        return 'Emergencia';
      case GoalType.vacation:
        return 'Viaje';
      case GoalType.education:
        return 'Educación';
      case GoalType.custom:
        return 'Personalizada';
    }
  }

  String get priorityName {
    switch (priority) {
      case GoalPriority.low:
        return 'Baja';
      case GoalPriority.medium:
        return 'Media';
      case GoalPriority.high:
        return 'Alta';
      case GoalPriority.urgent:
        return 'Urgente';
    }
  }

  String get statusName {
    switch (status) {
      case GoalStatus.active:
        return 'Activa';
      case GoalStatus.paused:
        return 'Pausada';
      case GoalStatus.completed:
        return 'Completada';
      case GoalStatus.cancelled:
        return 'Cancelada';
    }
  }

  String get autoSaveFrequencyName {
    switch (autoSaveFrequency) {
      case AutoSaveFrequency.daily:
        return 'Diariamente';
      case AutoSaveFrequency.weekly:
        return 'Semanalmente';
      case AutoSaveFrequency.monthly:
        return 'Mensualmente';
    }
  }

  // Colores según estado y prioridad
  Color get priorityColor {
    switch (priority) {
      case GoalPriority.low:
        return const Color(0xFF059669);
      case GoalPriority.medium:
        return const Color(0xFF3B82F6);
      case GoalPriority.high:
        return const Color(0xFFF59E0B);
      case GoalPriority.urgent:
        return const Color(0xFFDC2626);
    }
  }

  Color get statusColor {
    switch (status) {
      case GoalStatus.active:
        return const Color(0xFF059669);
      case GoalStatus.paused:
        return const Color(0xFFF59E0B);
      case GoalStatus.completed:
        return const Color(0xFF7C3AED);
      case GoalStatus.cancelled:
        return const Color(0xFF6B7280);
    }
  }

  Color get progressColor {
    if (isCompleted) return const Color(0xFF059669);
    if (isOverdue) return const Color(0xFFDC2626);
    if (progressPercentage >= 0.8) return const Color(0xFF059669);
    if (progressPercentage >= 0.5) return const Color(0xFF3B82F6);
    if (progressPercentage >= 0.3) return const Color(0xFFF59E0B);
    return const Color(0xFF6B7280);
  }

  // Mensajes motivacionales
  String get motivationalMessage {
    if (status == GoalStatus.completed) {
      return '¡Felicitaciones! Has alcanzado tu meta.';
    }

    if (isCompleted) {
      return '¡Increíble! Ya tienes el dinero para tu meta.';
    }

    if (progressPercentage >= 0.9) {
      return '¡Casi lo logras! Solo falta un poquito más.';
    }

    if (progressPercentage >= 0.75) {
      return '¡Excelente progreso! Vas muy bien.';
    }

    if (progressPercentage >= 0.5) {
      return '¡Ya estás a la mitad! Sigue así.';
    }

    if (progressPercentage >= 0.25) {
      return 'Buen comienzo, mantén el ritmo.';
    }

    return 'Cada pequeño ahorro cuenta. ¡Empecemos!';
  }

  // Consejos personalizados para alcanzar la meta
  String get mainTip {
    if (isCompleted) return 'Ya tienes el dinero suficiente para tu meta.';
    if (isOverdue) return 'Meta vencida. Considera extender la fecha o ajustar el monto.';

    if (daysRemaining <= 30) {
      return 'Queda poco tiempo. Necesitas ahorrar ${FormatUtils.formatMoney(requiredDailyContribution)} diarios.';
    }

    if (monthsRemaining <= 3) {
      return 'Ahorra ${FormatUtils.formatMoney(requiredWeeklyContribution)} semanales para llegar a tiempo.';
    }

    return 'Ahorra ${FormatUtils.formatMoney(requiredMonthlyContribution)} mensuales para alcanzar tu meta.';
  }

  // Información sobre el tiempo
  String get timeInfo {
    if (isCompleted) return 'Meta alcanzada';
    if (isOverdue) return 'Tiempo vencido';

    if (daysRemaining <= 0) return 'Hoy vence';
    if (daysRemaining == 1) return 'Vence mañana';
    if (daysRemaining <= 7) return 'Vence en $daysRemaining días';
    if (daysRemaining <= 30) return 'Vence en ${(daysRemaining / 7).ceil()} semanas';

    return 'Vence en $monthsRemaining meses';
  }

  // Serialización
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'startDate': startDate.toIso8601String(),
      'targetDate': targetDate.toIso8601String(),
      'type': type.index,
      'priority': priority.index,
      'status': status.index,
      'emoji': emoji,
      'monthlyContribution': monthlyContribution,
      'suggestedContribution': suggestedContribution,
      'autoSave': autoSave,
      'autoSaveFrequency': autoSaveFrequency.index,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory FinancialGoal.fromJson(Map<String, dynamic> json) {
    return FinancialGoal(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      targetAmount: json['targetAmount'].toDouble(),
      currentAmount: json['currentAmount']?.toDouble() ?? 0.0,
      startDate: DateTime.parse(json['startDate']),
      targetDate: DateTime.parse(json['targetDate']),
      type: GoalType.values[json['type']],
      priority: GoalPriority.values[json['priority'] ?? 1],
      status: GoalStatus.values[json['status'] ?? 0],
      emoji: json['emoji'] ?? '🎯',
      monthlyContribution: json['monthlyContribution']?.toDouble() ?? 0.0,
      suggestedContribution: json['suggestedContribution']?.toDouble() ?? 0.0,
      autoSave: json['autoSave'] ?? false,
      autoSaveFrequency: AutoSaveFrequency.values[json['autoSaveFrequency'] ?? 2],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
    );
  }

  FinancialGoal copyWith({
    String? id,
    String? name,
    String? description,
    double? targetAmount,
    double? currentAmount,
    DateTime? startDate,
    DateTime? targetDate,
    GoalType? type,
    GoalPriority? priority,
    GoalStatus? status,
    String? emoji,
    double? monthlyContribution,
    double? suggestedContribution,
    bool? autoSave,
    AutoSaveFrequency? autoSaveFrequency,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return FinancialGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      startDate: startDate ?? this.startDate,
      targetDate: targetDate ?? this.targetDate,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      emoji: emoji ?? this.emoji,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      suggestedContribution: suggestedContribution ?? this.suggestedContribution,
      autoSave: autoSave ?? this.autoSave,
      autoSaveFrequency: autoSaveFrequency ?? this.autoSaveFrequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

// Clase auxiliar para contribuciones a metas
class GoalContribution {
  final String? id;
  final String goalId;
  final double amount;
  final DateTime date;
  final String? note;
  final bool isAutomatic;

  GoalContribution({
    this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.note,
    this.isAutomatic = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goalId': goalId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'isAutomatic': isAutomatic,
    };
  }

  factory GoalContribution.fromJson(Map<String, dynamic> json) {
    return GoalContribution(
      id: json['id'],
      goalId: json['goalId'],
      amount: json['amount'].toDouble(),
      date: DateTime.parse(json['date']),
      note: json['note'],
      isAutomatic: json['isAutomatic'] ?? false,
    );
  }
}