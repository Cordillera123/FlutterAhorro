import 'package:json_annotation/json_annotation.dart';
import 'transaction.dart';

part 'recurring_expense.g.dart';

// Frecuencia del gasto recurrente
enum RecurrenceFrequency {
  daily,      // Diario
  weekly,     // Semanal
  monthly,    // Mensual
  custom      // Personalizado (cada X días)
}

// Días de la semana para gastos semanales
enum WeekDay {
  monday,    // Lunes
  tuesday,   // Martes
  wednesday, // Miércoles
  thursday,  // Jueves
  friday,    // Viernes
  saturday,  // Sábado
  sunday     // Domingo
}

@JsonSerializable()
class RecurringExpense {
  final String id;
  final String name;                    // Nombre del gasto (ej: "Transporte diario")
  final String description;             // Descripción (ej: "Bus casa-trabajo")
  final double amount;                  // Monto
  final ExpenseCategory category;       // Categoría
  final RecurrenceFrequency frequency;  // Frecuencia
  final int? customDays;                // Días personalizados (si frequency es custom)
  final List<WeekDay>? weekDays;        // Días de la semana (si frequency es weekly)
  final int? monthlyDay;                // Día del mes (si frequency es monthly)
  final DateTime startDate;             // Fecha de inicio
  final DateTime? endDate;              // Fecha de fin (opcional)
  final bool isActive;                  // Si está activo
  final DateTime createdAt;             // Fecha de creación
  final DateTime? lastProcessed;        // Última vez que se procesó

  RecurringExpense({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.category,
    required this.frequency,
    this.customDays,
    this.weekDays,
    this.monthlyDay,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
    this.lastProcessed,
  });

  factory RecurringExpense.fromJson(Map<String, dynamic> json) =>
      _$RecurringExpenseFromJson(json);

  Map<String, dynamic> toJson() => _$RecurringExpenseToJson(this);

  // Crear una copia con campos modificados
  RecurringExpense copyWith({
    String? id,
    String? name,
    String? description,
    double? amount,
    ExpenseCategory? category,
    RecurrenceFrequency? frequency,
    int? customDays,
    List<WeekDay>? weekDays,
    int? monthlyDay,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastProcessed,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      frequency: frequency ?? this.frequency,
      customDays: customDays ?? this.customDays,
      weekDays: weekDays ?? this.weekDays,
      monthlyDay: monthlyDay ?? this.monthlyDay,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastProcessed: lastProcessed ?? this.lastProcessed,
    );
  }

  // Obtener el nombre de la frecuencia en español
  String get frequencyName {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return 'Diario';
      case RecurrenceFrequency.weekly:
        return 'Semanal';
      case RecurrenceFrequency.monthly:
        return 'Mensual';
      case RecurrenceFrequency.custom:
        return 'Cada $customDays días';
    }
  }

  // Obtener descripción detallada de la frecuencia
  String get frequencyDescription {
    switch (frequency) {
      case RecurrenceFrequency.daily:
        return 'Todos los días';
      case RecurrenceFrequency.weekly:
        if (weekDays != null && weekDays!.isNotEmpty) {
          final dayNames = weekDays!.map((day) => _getWeekDayName(day)).join(', ');
          return 'Cada $dayNames';
        }
        return 'Semanal';
      case RecurrenceFrequency.monthly:
        if (monthlyDay != null) {
          return 'El día $monthlyDay de cada mes';
        }
        return 'Mensual';
      case RecurrenceFrequency.custom:
        return 'Cada $customDays días';
    }
  }

  String _getWeekDayName(WeekDay day) {
    switch (day) {
      case WeekDay.monday: return 'Lunes';
      case WeekDay.tuesday: return 'Martes';
      case WeekDay.wednesday: return 'Miércoles';
      case WeekDay.thursday: return 'Jueves';
      case WeekDay.friday: return 'Viernes';
      case WeekDay.saturday: return 'Sábado';
      case WeekDay.sunday: return 'Domingo';
    }
  }

  // Verificar si debe ejecutarse hoy
  bool shouldRunToday() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Si no está activo, no ejecutar
    if (!isActive) return false;

    // Si tiene fecha de fin y ya pasó, no ejecutar
    if (endDate != null && todayDate.isAfter(endDate!)) return false;

    // Si es antes de la fecha de inicio, no ejecutar
    if (todayDate.isBefore(DateTime(startDate.year, startDate.month, startDate.day))) {
      return false;
    }

    // Si ya se procesó hoy, no ejecutar
    if (lastProcessed != null) {
      final lastProcessedDate = DateTime(
          lastProcessed!.year,
          lastProcessed!.month,
          lastProcessed!.day
      );
      if (lastProcessedDate == todayDate) return false;
    }

    switch (frequency) {
      case RecurrenceFrequency.daily:
        return true;

      case RecurrenceFrequency.weekly:
        if (weekDays != null && weekDays!.isNotEmpty) {
          final todayWeekDay = _getTodayWeekDay();
          return weekDays!.contains(todayWeekDay);
        }
        return false;

      case RecurrenceFrequency.monthly:
        if (monthlyDay != null) {
          return today.day == monthlyDay;
        }
        return false;

      case RecurrenceFrequency.custom:
        if (customDays != null && lastProcessed != null) {
          final daysSinceLastProcessed = todayDate.difference(
              DateTime(lastProcessed!.year, lastProcessed!.month, lastProcessed!.day)
          ).inDays;
          return daysSinceLastProcessed >= customDays!;
        } else if (customDays != null) {
          // Primera vez, verificar desde startDate
          final daysSinceStart = todayDate.difference(
              DateTime(startDate.year, startDate.month, startDate.day)
          ).inDays;
          return daysSinceStart % customDays! == 0;
        }
        return false;
    }
  }

  WeekDay _getTodayWeekDay() {
    final today = DateTime.now();
    switch (today.weekday) {
      case 1: return WeekDay.monday;
      case 2: return WeekDay.tuesday;
      case 3: return WeekDay.wednesday;
      case 4: return WeekDay.thursday;
      case 5: return WeekDay.friday;
      case 6: return WeekDay.saturday;
      case 7: return WeekDay.sunday;
      default: return WeekDay.monday;
    }
  }

  // Crear transacción a partir del gasto recurrente
  Transaction createTransaction() {
    return Transaction(
      id: 'recurring_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
      type: TransactionType.expense,
      description: '$name - $description',
      date: DateTime.now(),
      expenseCategory: category,
      incomeCategory: null,
    );
  }

  // Obtener el ícono de la categoría
  String get categoryIcon {
    switch (category) {
      case ExpenseCategory.transport:
        return '🚗';
      case ExpenseCategory.food:
        return '🍕';
      case ExpenseCategory.shopping:
        return '🛍️';
      case ExpenseCategory.entertainment:
        return '🎬';
      case ExpenseCategory.other:
        return '📦';
    }
  }

  // Obtener el nombre de la categoría
  String get categoryName {
    switch (category) {
      case ExpenseCategory.transport:
        return 'Transporte';
      case ExpenseCategory.food:
        return 'Comida';
      case ExpenseCategory.shopping:
        return 'Compras';
      case ExpenseCategory.entertainment:
        return 'Entretenimiento';
      case ExpenseCategory.other:
        return 'Otros';
    }
  }
}