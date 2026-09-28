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
  final String accountId;              // ID de la cuenta a la que pertenece

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
    required this.accountId,
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
    String? accountId,
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
      accountId: accountId ?? this.accountId,
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
  bool shouldRunToday() => _runsOn(DateTime.now());

  // Verificar si el gasto debe ejecutarse en una fecha específica. Comparte
  // la lógica con [shouldRunToday] para que [nextOccurrence] nunca pueda
  // desincronizarse de lo que realmente procesa RecurringExpenseService.
  bool _runsOn(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);

    // Si no está activo, no ejecutar
    if (!isActive) return false;

    // Si tiene fecha de fin y ya pasó, no ejecutar
    if (endDate != null && targetDate.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day))) {
      return false;
    }

    // Si es antes de la fecha de inicio, no ejecutar
    if (targetDate.isBefore(DateTime(startDate.year, startDate.month, startDate.day))) {
      return false;
    }

    // Si ya se procesó ese día, no ejecutar de nuevo
    if (lastProcessed != null) {
      final lastProcessedDate = DateTime(
          lastProcessed!.year,
          lastProcessed!.month,
          lastProcessed!.day
      );
      if (lastProcessedDate == targetDate) return false;
    }

    switch (frequency) {
      case RecurrenceFrequency.daily:
        return true;

      case RecurrenceFrequency.weekly:
        if (weekDays != null && weekDays!.isNotEmpty) {
          return weekDays!.contains(_weekDayOf(targetDate));
        }
        return false;

      case RecurrenceFrequency.monthly:
        if (monthlyDay != null) {
          return targetDate.day == monthlyDay;
        }
        return false;

      case RecurrenceFrequency.custom:
        if (customDays != null && lastProcessed != null) {
          final daysSinceLastProcessed = targetDate.difference(
              DateTime(lastProcessed!.year, lastProcessed!.month, lastProcessed!.day)
          ).inDays;
          return daysSinceLastProcessed >= customDays!;
        } else if (customDays != null) {
          // Primera vez, verificar desde startDate
          final daysSinceStart = targetDate.difference(
              DateTime(startDate.year, startDate.month, startDate.day)
          ).inDays;
          return daysSinceStart % customDays! == 0;
        }
        return false;
    }
  }

  WeekDay _weekDayOf(DateTime date) {
    switch (date.weekday) {
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

  /// Próxima fecha (estrictamente después de [from], por defecto hoy) en la
  /// que este gasto recurrente volverá a ejecutarse. Devuelve `null` si está
  /// inactivo o si no hay ninguna ocurrencia dentro del horizonte de
  /// búsqueda (p. ej. porque ya pasó su fecha de fin).
  ///
  /// Se usa para los recordatorios ("próximos pagos") — el día de hoy no se
  /// incluye porque ya lo cubre [shouldRunToday]/`processRecurringExpensesForToday`.
  DateTime? nextOccurrence({DateTime? from, int horizonDays = 400}) {
    if (!isActive) return null;

    final base = DateTime(
      (from ?? DateTime.now()).year,
      (from ?? DateTime.now()).month,
      (from ?? DateTime.now()).day,
    );
    var candidate = base.add(const Duration(days: 1));

    for (var i = 0; i < horizonDays; i++) {
      if (endDate != null &&
          candidate.isAfter(DateTime(endDate!.year, endDate!.month, endDate!.day))) {
        return null;
      }
      if (_runsOn(candidate)) return candidate;
      candidate = candidate.add(const Duration(days: 1));
    }
    return null;
  }

  // Crear transacción a partir del gasto recurrente
  Transaction createTransaction() {
    double transactionAmount = amount;

    // Para gastos semanales, calculamos el monto diario
    if (frequency == RecurrenceFrequency.weekly && weekDays != null && weekDays!.isNotEmpty) {
      transactionAmount = amount / weekDays!.length;
    }

    return Transaction(
      id: 'recurring_${DateTime.now().millisecondsSinceEpoch}',
      amount: transactionAmount,
      type: TransactionType.expense,
      description: '$name - $description',
      date: DateTime.now(),
      expenseCategory: category,
      incomeCategory: null,
      accountId: accountId,
    );
  }

  // ACTUALIZADO - Obtener el ícono de la categoría con todas las nuevas categorías
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

  // ACTUALIZADO - Obtener el nombre de la categoría con todas las nuevas categorías
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
}