import '../../utils/format_utils.dart';

/// Utilidades compartidas del módulo dashboard (sin duplicar lógica de negocio).
class DashboardHelpers {
  DashboardHelpers._();

  static double growthPercentage(double current, double previous) {
    return FormatUtils.calculateGrowthPercentage(current, previous);
  }

  static const weekdayNames = {
    1: 'lunes',
    2: 'martes',
    3: 'miércoles',
    4: 'jueves',
    5: 'viernes',
    6: 'sábado',
    7: 'domingo',
  };

  static String weekdayLabel(int weekday) =>
      weekdayNames[weekday] ?? 'día $weekday';

  static int countConsecutiveMonthsWith(
    List<int> monthKeys,
    bool Function(int monthKey) predicate,
  ) {
    if (monthKeys.isEmpty) return 0;
    final sorted = List<int>.from(monthKeys)..sort((a, b) => b.compareTo(a));
    int count = 0;
    int? expected;
    for (final key in sorted) {
      if (!predicate(key)) break;
      if (expected == null) {
        expected = _previousMonthKey(key);
        count = 1;
      } else if (key == _nextExpectedFromNewest(key, count, sorted)) {
        count++;
      } else if (count == 1 && key == sorted.first) {
        count = 1;
        expected = _previousMonthKey(key);
      } else {
        break;
      }
    }
    return count;
  }

  static int _previousMonthKey(int key) {
    final year = key ~/ 100;
    final month = key % 100;
    final date = DateTime(year, month - 1);
    return date.year * 100 + date.month;
  }

  static int _nextExpectedFromNewest(int key, int count, List<int> sorted) {
    if (count >= sorted.length) return -1;
    return sorted[count];
  }

  static int consecutiveMonthsSavingsUp(
    Map<int, double> savingsByMonth,
    int currentKey,
  ) {
    final keys = savingsByMonth.keys.toList()..sort();
    if (keys.length < 2) return 0;

    int streak = 0;
    for (int i = keys.length - 1; i > 0; i--) {
      final current = savingsByMonth[keys[i]] ?? 0;
      final previous = savingsByMonth[keys[i - 1]] ?? 0;
      if (current > previous) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  static double clampScore(double value) => value.clamp(0.0, 100.0);
}
