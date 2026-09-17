import 'package:flutter/material.dart';
import '../../../../models/dashboard/dashboard_analysis_context.dart';
import '../../../../models/dashboard/dashboard_enums.dart';
import '../../../../models/dashboard/dashboard_observation.dart';
import '../../../../models/dashboard/message_trace.dart';
import '../../../../utils/format_utils.dart';
import '../../dashboard_analyzer.dart';
import '../../dashboard_helpers.dart';

class ExpenseVsPreviousObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_expense_vs_previous';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.hasPreviousMonthData &&
        context.snapshot.previousMonthExpenses > 0;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final s = context.snapshot;
    final growth = DashboardHelpers.growthPercentage(
      s.currentMonthExpenses,
      s.previousMonthExpenses,
    );
    if (growth.abs() < 5) return null;

    final less = growth < 0;
    return DashboardObservation(
      id: id,
      title: less ? 'Gastos en descenso' : 'Gastos en aumento',
      message: less
          ? 'Gastaste un ${growth.abs().toStringAsFixed(0)}% menos que el mes anterior'
          : 'Gastaste un ${growth.toStringAsFixed(0)}% más que el mes anterior',
      icon: less ? Icons.trending_down_rounded : Icons.trending_up_rounded,
      dimension: ObservationDimension.trend,
      numericValue: growth,
      trace: MessageTrace(
        reason: 'Comparación de gastos del mes actual vs mes anterior',
        inputs: [
          DataPoint(
            label: 'Gastos mes actual',
            value: FormatUtils.formatMoney(s.currentMonthExpenses),
          ),
          DataPoint(
            label: 'Gastos mes anterior',
            value: FormatUtils.formatMoney(s.previousMonthExpenses),
          ),
        ],
        formula: '((actual − anterior) / anterior) × 100',
      ),
    );
  }
}

class IncomeVsPreviousObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_income_vs_previous';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.hasPreviousMonthData &&
        context.snapshot.previousMonthIncome > 0;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final s = context.snapshot;
    final growth = DashboardHelpers.growthPercentage(
      s.currentMonthIncome,
      s.previousMonthIncome,
    );
    if (growth.abs() < 5) return null;

    return DashboardObservation(
      id: id,
      title: growth > 0 ? 'Ingresos en alza' : 'Ingresos en baja',
      message: growth > 0
          ? 'Tus ingresos crecieron un ${growth.toStringAsFixed(0)}%'
          : 'Tus ingresos bajaron un ${growth.abs().toStringAsFixed(0)}%',
      icon: growth > 0
          ? Icons.trending_up_rounded
          : Icons.trending_down_rounded,
      dimension: ObservationDimension.trend,
      numericValue: growth,
      trace: MessageTrace(
        reason: 'Comparación de ingresos mensuales',
        inputs: [
          DataPoint(
            label: 'Ingresos actuales',
            value: FormatUtils.formatMoney(s.currentMonthIncome),
          ),
          DataPoint(
            label: 'Ingresos anteriores',
            value: FormatUtils.formatMoney(s.previousMonthIncome),
          ),
        ],
        formula: '((actual − anterior) / anterior) × 100',
      ),
    );
  }
}

class BestSavingsMonthObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_best_savings_month';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    final best = context.snapshot.bestSavingsMonth;
    if (best == null) return false;
    return best.monthKey == context.snapshot.currentMonthKey &&
        best.savings > 0 &&
        context.snapshot.monthlyHistory.length >= 2;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    return DashboardObservation(
      id: id,
      title: 'Récord de ahorro',
      message: 'Este es tu mejor mes de ahorro desde que usas la aplicación',
      icon: Icons.emoji_events_outlined,
      dimension: ObservationDimension.monthly,
      trace: MessageTrace(
        reason: 'El ahorro del mes actual es el máximo en el historial',
        inputs: [
          DataPoint(
            label: 'Ahorro actual',
            value: FormatUtils.formatMoney(
              context.snapshot.currentMonthSavings,
            ),
          ),
        ],
        formula: 'max(ahorro mensual histórico) = mes actual',
      ),
    );
  }
}

class SavingsStreakObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_savings_streak';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    final history = context.snapshot.sortedMonthlyHistory;
    if (history.length < 3) return false;
    final savings = {for (final m in history) m.monthKey: m.savings};
    return _streak(savings) >= 3;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final history = context.snapshot.sortedMonthlyHistory;
    final savings = {for (final m in history) m.monthKey: m.savings};
    final streak = _streak(savings);
    if (streak < 3) return null;
    return DashboardObservation(
      id: id,
      title: 'Racha de ahorro',
      message:
          'Has aumentado tu ahorro durante $streak meses consecutivos',
      icon: Icons.local_fire_department_rounded,
      dimension: ObservationDimension.trend,
      numericValue: streak.toDouble(),
      trace: MessageTrace(
        reason: 'Cada mes el ahorro superó al mes previo',
        inputs: [DataPoint(label: 'Meses consecutivos', value: '$streak')],
        formula: 'ahorro(mesᵢ) > ahorro(mesᵢ₋₁) durante N meses',
      ),
    );
  }

  int _streak(Map<int, double> savings) {
    final keys = savings.keys.toList()..sort();
    if (keys.length < 2) return 0;
    int streak = 0;
    for (int i = keys.length - 1; i > 0; i--) {
      if ((savings[keys[i]] ?? 0) > (savings[keys[i - 1]] ?? 0)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }
}

class GoalNearObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_goal_near';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.activeGoals.any(
      (g) => g.remainingAmount > 0 && g.progressPercentage >= 0.85,
    );
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final near = context.activeGoals
        .where((g) => g.remainingAmount > 0 && g.progressPercentage >= 0.85)
        .toList()
      ..sort((a, b) => a.remainingAmount.compareTo(b.remainingAmount));
    if (near.isEmpty) return null;
    final goal = near.first;
    return DashboardObservation(
      id: '${id}_${goal.id}',
      title: 'Meta casi completa',
      message:
          'Solo te faltan ${FormatUtils.formatMoney(goal.remainingAmount)} para completar "${goal.name}"',
      icon: Icons.flag_circle_outlined,
      dimension: ObservationDimension.goal,
      trace: MessageTrace(
        reason: 'La meta superó el 85% de progreso',
        inputs: [
          DataPoint(label: 'Meta', value: goal.name),
          DataPoint(
            label: 'Restante',
            value: FormatUtils.formatMoney(goal.remainingAmount),
          ),
        ],
        formula: 'restante = objetivo − acumulado',
      ),
    );
  }
}

class WeekendSpendingObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_weekend_spending';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    final s = context.snapshot;
    if (s.currentMonthExpenses <= 0) return false;
    final weekend = (s.expensesByWeekday[6] ?? 0) + (s.expensesByWeekday[7] ?? 0);
    final weekdays = s.currentMonthExpenses - weekend;
    return weekend > weekdays * 0.6 && weekend > 0;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final s = context.snapshot;
    final weekend = (s.expensesByWeekday[6] ?? 0) + (s.expensesByWeekday[7] ?? 0);
    final pct = (weekend / s.currentMonthExpenses) * 100;
    return DashboardObservation(
      id: id,
      title: 'Patrón de fin de semana',
      message:
          'Tus gastos aumentan principalmente los fines de semana (${pct.toStringAsFixed(0)}% del total)',
      icon: Icons.weekend_outlined,
      dimension: ObservationDimension.pattern,
      numericValue: pct,
      trace: MessageTrace(
        reason: 'Los gastos de sábado y domingo concentran gran parte del mes',
        inputs: [
          DataPoint(
            label: 'Gastos fin de semana',
            value: FormatUtils.formatMoney(weekend),
          ),
        ],
        formula: 'gastos(sáb+dom) / gastos(mes)',
      ),
    );
  }
}

class PeakWeekdayObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_peak_weekday';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.snapshot.expensesByWeekday.values.any((v) => v > 0);
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final weekdays = context.snapshot.expensesByWeekday;
    if (weekdays.isEmpty) return null;
    final peak = weekdays.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (peak.value <= 0) return null;
    final pct = (peak.value / context.snapshot.currentMonthExpenses) * 100;
    if (pct < 15) return null;
    return DashboardObservation(
      id: id,
      title: 'Día de mayor gasto',
      message:
          'El ${DashboardHelpers.weekdayLabel(peak.key)} es el día donde más dinero gastas',
      icon: Icons.calendar_today_rounded,
      dimension: ObservationDimension.pattern,
      numericValue: pct,
      trace: MessageTrace(
        reason: 'Día de la semana con mayor suma de gastos en el mes',
        inputs: [
          DataPoint(
            label: DashboardHelpers.weekdayLabel(peak.key),
            value: FormatUtils.formatMoney(peak.value),
          ),
        ],
        formula: 'argmax(gastos por weekday)',
      ),
    );
  }
}

class MonthEndLoadObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_month_end_load';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    final lastWeek = context.snapshot.expensesByWeekOfMonth[5] ??
        context.snapshot.expensesByWeekOfMonth[4];
    if (lastWeek == null) return false;
    return lastWeek.percentageOfMonth >= 35;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final week5 = context.snapshot.expensesByWeekOfMonth[5];
    final week4 = context.snapshot.expensesByWeekOfMonth[4];
    final target = week5 ?? week4!;
    return DashboardObservation(
      id: id,
      title: 'Concentración de fin de mes',
      message:
          'La última semana del mes concentra el ${target.percentageOfMonth.toStringAsFixed(0)}% de tus gastos',
      icon: Icons.date_range_rounded,
      dimension: ObservationDimension.pattern,
      numericValue: target.percentageOfMonth,
      trace: MessageTrace(
        reason: 'Gastos de la semana 4-5 superan el 35% del mes',
        inputs: [
          DataPoint(
            label: 'Porcentaje',
            value: '${target.percentageOfMonth.toStringAsFixed(0)}%',
          ),
        ],
        formula: 'gastos(semana₅) / gastos(mes)',
      ),
    );
  }
}

class DominantIncomeObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_dominant_income';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    final top = context.snapshot.topIncomeSource;
    return top != null && top.percentageOfIncome >= 50;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final top = context.snapshot.topIncomeSource!;
    return DashboardObservation(
      id: id,
      title: 'Fuente principal de ingresos',
      message:
          'La mayor parte de tus ingresos proviene de ${top.displayName} (${top.percentageOfIncome.toStringAsFixed(0)}%)',
      icon: Icons.payments_outlined,
      dimension: ObservationDimension.category,
      numericValue: top.percentageOfIncome,
      trace: MessageTrace(
        reason: 'Una categoría de ingreso concentra más del 50%',
        inputs: [
          DataPoint(label: 'Fuente', value: top.displayName),
          DataPoint(
            label: 'Monto',
            value: FormatUtils.formatMoney(top.amount),
          ),
        ],
        formula: 'ingresos(categoría) / ingresos(totales)',
      ),
    );
  }
}

class DominantExpenseObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_dominant_expense';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    final top = context.snapshot.topExpenseCategory;
    return top != null && top.percentageOfExpenses >= 25;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final top = context.snapshot.topExpenseCategory!;
    return DashboardObservation(
      id: id,
      title: 'Categoría dominante',
      message:
          '${top.displayName} representa el ${top.percentageOfExpenses.toStringAsFixed(0)}% de tus gastos',
      icon: Icons.pie_chart_outline_rounded,
      dimension: ObservationDimension.category,
      numericValue: top.percentageOfExpenses,
      trace: MessageTrace(
        reason: 'La categoría con mayor gasto supera el 25% del total',
        inputs: [
          DataPoint(label: 'Categoría', value: top.displayName),
          DataPoint(label: 'Monto', value: FormatUtils.formatMoney(top.amount)),
        ],
        formula: 'gastos(categoría) / gastos(totales)',
      ),
    );
  }
}

class DailyAverageChangeObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_daily_avg_change';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.hasPreviousMonthData &&
        context.snapshot.previousMonthDailyAverageExpense > 0;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final s = context.snapshot;
    final growth = DashboardHelpers.growthPercentage(
      s.dailyAverageExpense,
      s.previousMonthDailyAverageExpense,
    );
    if (growth.abs() < 8) return null;
    return DashboardObservation(
      id: id,
      title: 'Cambio en gasto diario',
      message: growth > 0
          ? 'Tu gasto promedio diario aumentó un ${growth.toStringAsFixed(0)}%'
          : 'Tu gasto promedio diario disminuyó un ${growth.abs().toStringAsFixed(0)}%',
      icon: Icons.speed_rounded,
      dimension: ObservationDimension.trend,
      numericValue: growth,
      trace: MessageTrace(
        reason: 'Comparación del promedio diario de gastos',
        inputs: [
          DataPoint(
            label: 'Promedio actual',
            value: FormatUtils.formatMoney(s.dailyAverageExpense),
          ),
          DataPoint(
            label: 'Promedio mes anterior',
            value: FormatUtils.formatMoney(s.previousMonthDailyAverageExpense),
          ),
        ],
        formula: 'gastos(mes) / días transcurridos',
      ),
    );
  }
}

class CategoryReductionObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_category_reduction';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    if (!context.hasPreviousMonthData) return false;
    final s = context.snapshot;
    for (final cat in s.expensesByCategory.values) {
      final prev = s.categoryExpensesForMonth(s.previousMonthKey, cat.key);
      if (prev > 0 && cat.amount < prev * 0.85) return true;
    }
    return false;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final s = context.snapshot;
    String? bestName;
    double bestReduction = 0;
    for (final cat in s.expensesByCategory.values) {
      final prev = s.categoryExpensesForMonth(s.previousMonthKey, cat.key);
      if (prev <= 0) continue;
      final reduction = ((prev - cat.amount) / prev) * 100;
      if (reduction > bestReduction && reduction >= 10) {
        bestReduction = reduction;
        bestName = cat.displayName;
      }
    }
    if (bestName == null) return null;
    return DashboardObservation(
      id: '${id}_$bestName',
      title: 'Reducción por categoría',
      message:
          'Has reducido tus gastos en $bestName un ${bestReduction.toStringAsFixed(0)}%',
      icon: Icons.arrow_downward_rounded,
      dimension: ObservationDimension.category,
      numericValue: bestReduction,
      trace: MessageTrace(
        reason: 'Gasto en categoría bajó más del 10% vs mes anterior',
        inputs: [DataPoint(label: 'Categoría', value: bestName)],
        formula: '((anterior − actual) / anterior) × 100',
      ),
    );
  }
}

class RegistrationStreakObservationAnalyzer
    implements DashboardAnalyzer<DashboardObservation> {
  @override
  String get id => 'obs_registration_streak';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.snapshot.currentStreakDays >= 7;
  }

  @override
  DashboardObservation? analyze(DashboardAnalysisContext context) {
    final days = context.snapshot.currentStreakDays;
    return DashboardObservation(
      id: id,
      title: 'Racha de registro',
      message: 'Llevas $days días consecutivos registrando movimientos',
      icon: Icons.check_circle_outline_rounded,
      dimension: ObservationDimension.habit,
      numericValue: days.toDouble(),
      trace: MessageTrace(
        reason: 'Días consecutivos con al menos un movimiento',
        inputs: [DataPoint(label: 'Días', value: '$days')],
        formula: 'racha desde hoy hacia atrás sin huecos',
      ),
    );
  }
}
