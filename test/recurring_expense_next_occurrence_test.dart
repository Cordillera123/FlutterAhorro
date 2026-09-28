import 'package:flutter_test/flutter_test.dart';
import 'package:ahorro_app/models/recurring_expense.dart';
import 'package:ahorro_app/models/transaction.dart';

RecurringExpense _expense({
  String id = 'r1',
  RecurrenceFrequency frequency = RecurrenceFrequency.daily,
  required DateTime startDate,
  DateTime? endDate,
  DateTime? lastProcessed,
  bool isActive = true,
  int? customDays,
  List<WeekDay>? weekDays,
  int? monthlyDay,
}) {
  return RecurringExpense(
    id: id,
    name: 'Gasto de prueba',
    description: 'desc',
    amount: 10,
    category: ExpenseCategory.other,
    frequency: frequency,
    customDays: customDays,
    weekDays: weekDays,
    monthlyDay: monthlyDay,
    startDate: startDate,
    endDate: endDate,
    isActive: isActive,
    createdAt: startDate,
    lastProcessed: lastProcessed,
    accountId: 'acc',
  );
}

// Réplica local de la conversión weekday→WeekDay del modelo, solo para
// construir datos de prueba sin depender de una fecha fija del calendario.
WeekDay _toWeekDay(int weekday) {
  switch (weekday) {
    case 1: return WeekDay.monday;
    case 2: return WeekDay.tuesday;
    case 3: return WeekDay.wednesday;
    case 4: return WeekDay.thursday;
    case 5: return WeekDay.friday;
    case 6: return WeekDay.saturday;
    default: return WeekDay.sunday;
  }
}

void main() {
  // Fecha de referencia arbitraria; todo lo demás se deriva sumando días
  // para no depender de la duración de los meses del calendario.
  final base = DateTime(2026, 1, 1);

  group('nextOccurrence — diario', () {
    test('la próxima ocurrencia es el día siguiente a "from"', () {
      final from = base.add(const Duration(days: 30));
      final e = _expense(frequency: RecurrenceFrequency.daily, startDate: base);
      expect(e.nextOccurrence(from: from), from.add(const Duration(days: 1)));
    });

    test('nunca devuelve una fecha igual o anterior a "from"', () {
      final from = base.add(const Duration(days: 30));
      final e = _expense(frequency: RecurrenceFrequency.daily, startDate: base);
      final next = e.nextOccurrence(from: from);
      expect(next!.isAfter(from), true);
    });

    test('respeta la fecha de fin', () {
      final from = base.add(const Duration(days: 30));
      final e = _expense(
        frequency: RecurrenceFrequency.daily,
        startDate: base,
        endDate: from,
      );
      expect(e.nextOccurrence(from: from), isNull);
    });

    test('un gasto inactivo no tiene próxima ocurrencia', () {
      final e = _expense(
        frequency: RecurrenceFrequency.daily,
        startDate: base,
        isActive: false,
      );
      expect(e.nextOccurrence(from: base.add(const Duration(days: 30))), isNull);
    });
  });

  group('nextOccurrence — semanal', () {
    test('con todos los días marcados, se comporta como diario', () {
      final from = base.add(const Duration(days: 30));
      final e = _expense(
        frequency: RecurrenceFrequency.weekly,
        weekDays: WeekDay.values,
        startDate: base,
      );
      expect(e.nextOccurrence(from: from), from.add(const Duration(days: 1)));
    });

    test('con un solo día marcado, salta a la misma fecha la semana siguiente', () {
      final from = base.add(const Duration(days: 30));
      final e = _expense(
        frequency: RecurrenceFrequency.weekly,
        weekDays: [_toWeekDay(from.weekday)],
        startDate: base,
      );
      expect(e.nextOccurrence(from: from), from.add(const Duration(days: 7)));
    });

    test('sin días configurados, no hay próxima ocurrencia', () {
      final e = _expense(
        frequency: RecurrenceFrequency.weekly,
        weekDays: const [],
        startDate: base,
      );
      expect(e.nextOccurrence(from: base, horizonDays: 30), isNull);
    });
  });

  group('nextOccurrence — mensual', () {
    test('encuentra el mismo día del mes siguiente', () {
      final from = DateTime(2026, 3, 15);
      final e = _expense(
        frequency: RecurrenceFrequency.monthly,
        monthlyDay: 15,
        startDate: base,
      );
      expect(e.nextOccurrence(from: from), DateTime(2026, 4, 15));
    });

    test('sin día configurado, no hay próxima ocurrencia', () {
      final e = _expense(
        frequency: RecurrenceFrequency.monthly,
        monthlyDay: null,
        startDate: base,
      );
      expect(e.nextOccurrence(from: base, horizonDays: 60), isNull);
    });
  });

  group('nextOccurrence — personalizado (cada X días)', () {
    test('sin lastProcessed, es periódico desde startDate', () {
      final from = base.add(const Duration(days: 25));
      final e = _expense(
        frequency: RecurrenceFrequency.custom,
        customDays: 10,
        startDate: base,
      );
      // Múltiplos de 10 desde base: ...20, 30... el primero después del
      // día 25 es el día 30.
      expect(e.nextOccurrence(from: from), base.add(const Duration(days: 30)));
    });

    test('con lastProcessed, la próxima es lastProcessed + customDays', () {
      final lastProcessed = base.add(const Duration(days: 5));
      final from = base.add(const Duration(days: 8));
      final e = _expense(
        frequency: RecurrenceFrequency.custom,
        customDays: 10,
        startDate: base,
        lastProcessed: lastProcessed,
      );
      expect(e.nextOccurrence(from: from), lastProcessed.add(const Duration(days: 10)));
    });
  });
}
