import 'package:flutter/material.dart';
import '../utils/format_utils.dart';

enum GoalType {
  purchase, // Comprar algo específico (moto, carro, etc.)
  savings, // Ahorrar dinero general
  emergency, // Fondo de emergencia
  vacation, // Viaje o vacaciones
  education, // Educación o cursos
  custom, // Meta personalizada
}

enum GoalPriority { low, medium, high, urgent }

enum GoalStatus { active, paused, completed, cancelled }

enum AutoSaveFrequency { daily, weekly, monthly }

enum GoalContributionCadence { weekly, monthly }

class GoalContributionSuggestion {
  final double amount;
  final GoalContributionCadence cadence;
  final int periodsRemaining;

  const GoalContributionSuggestion({
    required this.amount,
    required this.cadence,
    required this.periodsRemaining,
  });

  String get cadenceLabel {
    switch (cadence) {
      case GoalContributionCadence.weekly:
        return 'semana';
      case GoalContributionCadence.monthly:
        return 'mes';
    }
  }

  String get cadenceLabelPlural {
    switch (cadence) {
      case GoalContributionCadence.weekly:
        return 'semanas';
      case GoalContributionCadence.monthly:
        return 'meses';
    }
  }
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
  final double autoSaveAmount;
  final bool autoSave;
  final AutoSaveFrequency autoSaveFrequency;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final String accountId; // ID de la cuenta a la que pertenece

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
    this.autoSaveAmount = 0.0,
    this.autoSave = false,
    this.autoSaveFrequency = AutoSaveFrequency.monthly,
    required this.createdAt,
    this.updatedAt,
    this.completedAt,
    required this.accountId,
  });

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static int _lastDayOfMonth(int year, int month) {
    return DateUtils.getDaysInMonth(year, month);
  }

  static int _approxWeeksBetween(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    return (days / 7).round().clamp(1, 999999);
  }

  static int _approxMonthsBetween(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    return (days / 30.4375).round().clamp(1, 999999);
  }

  static GoalContributionSuggestion calculateSuggestedContribution({
    required double targetAmount,
    required double currentAmount,
    required DateTime targetDate,
    DateTime? referenceDate,
  }) {
    final normalizedNow = _dateOnly(referenceDate ?? DateTime.now());
    final normalizedTargetDate = _dateOnly(targetDate);
    final remainingAmount = (targetAmount - currentAmount).clamp(
      0.0,
      double.infinity,
    );

    if (remainingAmount <= 0) {
      return const GoalContributionSuggestion(
        amount: 0.0,
        cadence: GoalContributionCadence.monthly,
        periodsRemaining: 0,
      );
    }

    final monthsRemaining = _approxMonthsBetween(
      normalizedNow,
      normalizedTargetDate,
    );
    if (monthsRemaining <= 12) {
      final weeksRemaining = _approxWeeksBetween(
        normalizedNow,
        normalizedTargetDate,
      );
      return GoalContributionSuggestion(
        amount: remainingAmount / weeksRemaining,
        cadence: GoalContributionCadence.weekly,
        periodsRemaining: weeksRemaining,
      );
    }

    return GoalContributionSuggestion(
      amount: remainingAmount / monthsRemaining,
      cadence: GoalContributionCadence.monthly,
      periodsRemaining: monthsRemaining,
    );
  }

  // Getters calculados
  double get remainingAmount =>
      (targetAmount - currentAmount).clamp(0.0, double.infinity);

  double get progressPercentage {
    if (targetAmount <= 0) return 0.0;
    return (currentAmount / targetAmount).clamp(0.0, 1.0);
  }

  int get daysRemaining {
    final now = _dateOnly(DateTime.now());
    final target = _dateOnly(targetDate);
    if (now.isAfter(target)) return 0;
    return target.difference(now).inDays;
  }

  int get monthsRemaining {
    return _approxMonthsBetween(
      _dateOnly(DateTime.now()),
      _dateOnly(targetDate),
    );
  }

  GoalContributionSuggestion get contributionSuggestion {
    return calculateSuggestedContribution(
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: targetDate,
    );
  }

  double get suggestedContributionAmount => contributionSuggestion.amount;

  GoalContributionCadence get suggestedContributionCadence =>
      contributionSuggestion.cadence;

  int get suggestedContributionPeriodsRemaining =>
      contributionSuggestion.periodsRemaining;

  String get suggestedContributionLabel {
    final suggestion = contributionSuggestion;
    return '${FormatUtils.formatMoney(suggestion.amount)} por ${suggestion.cadenceLabel}';
  }

  // Validar que la contribución no exceda el monto objetivo
  bool isContributionValid(double contribution) {
    return contribution > 0;
  }

  // Obtener la próxima fecha de contribución automática
  DateTime? get nextAutoSaveDate {
    if (!autoSave) return null;

    final now = DateTime.now();
    switch (autoSaveFrequency) {
      case AutoSaveFrequency.daily:
        return DateTime(now.year, now.month, now.day + 1);
      case AutoSaveFrequency.weekly:
        return now.add(Duration(days: 8 - now.weekday));
      case AutoSaveFrequency.monthly:
        return DateTime(now.year, now.month + 1, now.day);
    }
  }

  bool get isOnTrack {
    if (status == GoalStatus.completed) return true;
    if (daysRemaining <= 0) return currentAmount >= targetAmount;

    final totalDays = targetDate.difference(startDate).inDays;
    if (totalDays <= 0) return progressPercentage >= 1.0;

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
    if (isOverdue)
      return 'Meta vencida. Considera extender la fecha o ajustar el monto.';

    final suggestion = contributionSuggestion;
    if (suggestion.amount <= 0) {
      return 'Cada aporte cuenta para seguir avanzando hacia tu meta.';
    }

    return suggestion.cadence == GoalContributionCadence.weekly
        ? 'Ahorra ${FormatUtils.formatMoney(suggestion.amount)} semanales para llegar a tiempo.'
        : 'Ahorra ${FormatUtils.formatMoney(suggestion.amount)} mensuales para alcanzar tu meta.';
  }

  // Información sobre el tiempo
  String get timeInfo {
    if (isCompleted) return 'Meta alcanzada';
    if (isOverdue) return 'Tiempo vencido';

    if (daysRemaining <= 0) return 'Hoy vence';
    if (daysRemaining == 1) return 'Vence mañana';
    if (daysRemaining <= 7) return 'Vence en $daysRemaining días';
    if (daysRemaining <= 30)
      return 'Vence en ${(daysRemaining / 7).ceil()} semanas';

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
      'autoSaveAmount': autoSaveAmount,
      'autoSave': autoSave,
      'autoSaveFrequency': autoSaveFrequency.index,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'accountId': accountId,
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
      autoSaveAmount:
          (json['autoSaveAmount'] ?? json['monthlyContribution'] ?? 0)
              .toDouble(),
      autoSave: json['autoSave'] ?? false,
      autoSaveFrequency:
          AutoSaveFrequency.values[json['autoSaveFrequency'] ?? 2],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      accountId: json['accountId'] as String? ?? 'account_default',
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
    double? autoSaveAmount,
    bool? autoSave,
    AutoSaveFrequency? autoSaveFrequency,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    String? accountId,
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
      autoSaveAmount: autoSaveAmount ?? this.autoSaveAmount,
      autoSave: autoSave ?? this.autoSave,
      autoSaveFrequency: autoSaveFrequency ?? this.autoSaveFrequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      completedAt: completedAt ?? this.completedAt,
      accountId: accountId ?? this.accountId,
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
  final String accountId; // ID de la cuenta a la que pertenece

  GoalContribution({
    this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.note,
    this.isAutomatic = false,
    required this.accountId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goalId': goalId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'isAutomatic': isAutomatic,
      'accountId': accountId,
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
      accountId: json['accountId'] as String? ?? 'account_default',
    );
  }
}
