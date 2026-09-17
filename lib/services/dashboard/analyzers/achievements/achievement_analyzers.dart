import 'package:flutter/material.dart';
import '../../../../models/budget.dart';
import '../../../../models/dashboard/dashboard_analysis_context.dart';
import '../../../../models/dashboard/dashboard_enums.dart';
import '../../../../models/dashboard/dashboard_snapshot.dart';
import '../../../../models/dashboard/message_trace.dart';
import '../../../../models/financial_goal.dart';
import '../../../../utils/format_utils.dart';
import 'achievement_base.dart';

export 'achievement_base.dart';

/// Meses cerrados del historial. El mes en curso se excluye de cualquier
/// comparación de tendencia porque está incompleto y produciría logros
/// falsos (p. ej. "bajaste tus gastos" el día 2 del mes).
List<MonthAggregate> _completedMonths(DashboardAnalysisContext context) {
  final current = context.snapshot.currentMonthKey;
  return context.snapshot.sortedMonthlyHistory
      .where((m) => m.monthKey != current && m.transactionCount > 0)
      .toList();
}

// ─────────────────────────────────────────────────────────────────────────
// Primeros pasos
// ─────────────────────────────────────────────────────────────────────────

class MovementsAchievementAnalyzer extends TieredAchievementAnalyzer {
  @override
  String get id => 'ach_movements';

  @override
  AchievementGroup get group => AchievementGroup.firstSteps;

  @override
  IconData get icon => Icons.edit_note_rounded;

  @override
  String get unit => 'movimientos';

  @override
  String get traceReason => 'Total de movimientos registrados en la cuenta';

  @override
  String get traceFormula => 'count(transacciones)';

  @override
  double currentValue(DashboardAnalysisContext context) =>
      context.snapshot.totalTransactionCount.toDouble();

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 1,
          title: 'Primer movimiento',
          goal: '1 movimiento registrado',
          celebration: 'Registraste tu primer movimiento. ¡Así empieza todo!',
        ),
        AchievementTier(
          threshold: 10,
          title: 'Tomando ritmo',
          goal: '10 movimientos registrados',
          celebration: 'Ya llevas {v} movimientos registrados',
        ),
        AchievementTier(
          threshold: 50,
          title: 'Registrador constante',
          goal: '50 movimientos registrados',
          celebration: '{v} movimientos registrados: tienes el hábito',
        ),
        AchievementTier(
          threshold: 100,
          title: 'Centenario',
          goal: '100 movimientos registrados',
          celebration: 'Superaste los 100 movimientos registrados',
        ),
        AchievementTier(
          threshold: 250,
          title: 'Maestro del registro',
          goal: '250 movimientos registrados',
          celebration: '{v} movimientos: tu historial es muy sólido',
        ),
        AchievementTier(
          threshold: 500,
          title: 'Leyenda del registro',
          goal: '500 movimientos registrados',
          celebration: '{v} movimientos registrados. Impresionante',
        ),
      ];
}

class FirstIncomeAchievementAnalyzer extends SingleAchievementAnalyzer {
  @override
  String get id => 'ach_first_income';

  @override
  AchievementGroup get group => AchievementGroup.firstSteps;

  @override
  IconData get icon => Icons.paid_rounded;

  @override
  String get title => 'Primer ingreso';

  @override
  String get lockedHint => 'Registra tu primer ingreso';

  @override
  String get traceReason => 'Existe al menos un ingreso registrado';

  @override
  String get traceFormula => 'sum(ingresos) > 0';

  @override
  bool isUnlocked(DashboardAnalysisContext context) =>
      context.snapshot.monthlyHistory.values.any((m) => m.income > 0);

  @override
  String unlockedMessage(DashboardAnalysisContext context) =>
      'Registraste tu primer ingreso. Ya puedes medir cuánto ahorras';
}

class FirstBudgetAchievementAnalyzer extends SingleAchievementAnalyzer {
  @override
  String get id => 'ach_first_budget';

  @override
  AchievementGroup get group => AchievementGroup.budgets;

  @override
  IconData get icon => Icons.shield_outlined;

  @override
  String get title => 'Primer presupuesto';

  @override
  String get lockedHint => 'Crea tu primer presupuesto';

  @override
  String get traceReason => 'La cuenta tiene al menos un presupuesto creado';

  @override
  String get traceFormula => 'count(presupuestos) ≥ 1';

  @override
  bool isUnlocked(DashboardAnalysisContext context) =>
      context.allAccountBudgets.isNotEmpty;

  @override
  String unlockedMessage(DashboardAnalysisContext context) =>
      'Creaste tu primer presupuesto: ya tienes un límite que te cuida';
}

class FirstGoalAchievementAnalyzer extends SingleAchievementAnalyzer {
  @override
  String get id => 'ach_first_goal';

  @override
  AchievementGroup get group => AchievementGroup.goals;

  @override
  IconData get icon => Icons.flag_outlined;

  @override
  String get title => 'Primera meta';

  @override
  String get lockedHint => 'Crea tu primera meta de ahorro';

  @override
  String get traceReason => 'La cuenta tiene al menos una meta creada';

  @override
  String get traceFormula => 'count(metas) ≥ 1';

  @override
  bool isUnlocked(DashboardAnalysisContext context) =>
      context.allAccountGoals.isNotEmpty;

  @override
  String unlockedMessage(DashboardAnalysisContext context) =>
      'Creaste tu primera meta. Ahorrar con un objetivo funciona mejor';
}

// ─────────────────────────────────────────────────────────────────────────
// Constancia
// ─────────────────────────────────────────────────────────────────────────

class RegistrationStreakAchievementAnalyzer extends TieredAchievementAnalyzer {
  @override
  String get id => 'ach_streak';

  @override
  AchievementGroup get group => AchievementGroup.consistency;

  @override
  IconData get icon => Icons.local_fire_department_rounded;

  @override
  String get unit => 'días';

  @override
  String get traceReason => 'Días consecutivos registrando movimientos';

  @override
  String get traceFormula => 'días seguidos con al menos 1 movimiento';

  @override
  double currentValue(DashboardAnalysisContext context) =>
      context.snapshot.currentStreakDays.toDouble();

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 3,
          title: 'Racha encendida',
          goal: '3 días seguidos',
          celebration: '{v} días seguidos registrando. La constancia empieza aquí',
        ),
        AchievementTier(
          threshold: 7,
          title: 'Una semana seguida',
          goal: '7 días seguidos',
          celebration: 'Llevas {v} días seguidos sin fallar',
        ),
        AchievementTier(
          threshold: 15,
          title: 'Quincena imparable',
          goal: '15 días seguidos',
          celebration: '{v} días consecutivos registrando movimientos',
        ),
        AchievementTier(
          threshold: 30,
          title: 'Un mes sin fallar',
          goal: '30 días seguidos',
          celebration: '{v} días seguidos. Esto ya es un hábito',
        ),
        AchievementTier(
          threshold: 60,
          title: 'Dos meses de racha',
          goal: '60 días seguidos',
          celebration: '{v} días consecutivos. Muy pocos llegan aquí',
        ),
        AchievementTier(
          threshold: 100,
          title: '100 días de racha',
          goal: '100 días seguidos',
          celebration: '{v} días seguidos registrando. Eres imparable',
        ),
      ];
}

class ActiveMonthAchievementAnalyzer extends TieredAchievementAnalyzer {
  @override
  String get id => 'ach_active_month';

  @override
  AchievementGroup get group => AchievementGroup.consistency;

  @override
  IconData get icon => Icons.bolt_rounded;

  @override
  String get unit => 'este mes';

  @override
  String get traceReason => 'Movimientos registrados durante el mes en curso';

  @override
  String get traceFormula => 'count(transacciones del mes)';

  @override
  double currentValue(DashboardAnalysisContext context) {
    final current =
        context.snapshot.monthlyHistory[context.snapshot.currentMonthKey];
    return (current?.transactionCount ?? 0).toDouble();
  }

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 10,
          title: 'Mes activo',
          goal: '10 movimientos en el mes',
          celebration: 'Registraste {v} movimientos este mes',
        ),
        AchievementTier(
          threshold: 25,
          title: 'Mes muy activo',
          goal: '25 movimientos en el mes',
          celebration: '{v} movimientos este mes. Control total',
        ),
        AchievementTier(
          threshold: 50,
          title: 'Mes imparable',
          goal: '50 movimientos en el mes',
          celebration: '{v} movimientos en un solo mes',
        ),
      ];
}

class MonthsUsingAchievementAnalyzer extends TieredAchievementAnalyzer {
  @override
  String get id => 'ach_months_using';

  @override
  AchievementGroup get group => AchievementGroup.consistency;

  @override
  IconData get icon => Icons.calendar_month_rounded;

  @override
  String get unit => 'meses';

  @override
  String get traceReason => 'Meses distintos con movimientos registrados';

  @override
  String get traceFormula => 'count(meses con al menos 1 movimiento)';

  @override
  double currentValue(DashboardAnalysisContext context) => context
      .snapshot.monthlyHistory.values
      .where((m) => m.transactionCount > 0)
      .length
      .toDouble();

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 1,
          title: 'Tu primer mes',
          goal: '1 mes con movimientos',
          celebration: 'Completaste tu primer mes llevando tus finanzas',
        ),
        AchievementTier(
          threshold: 3,
          title: 'Tres meses contigo',
          goal: '3 meses con movimientos',
          celebration: 'Llevas {v} meses registrando tus finanzas',
        ),
        AchievementTier(
          threshold: 6,
          title: 'Medio año',
          goal: '6 meses con movimientos',
          celebration: '{v} meses cuidando tu dinero',
        ),
        AchievementTier(
          threshold: 12,
          title: 'Un año completo',
          goal: '12 meses con movimientos',
          celebration: 'Un año entero de historial financiero',
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────
// Ahorro
// ─────────────────────────────────────────────────────────────────────────

class MonthlySavingsAchievementAnalyzer extends TieredAchievementAnalyzer {
  @override
  String get id => 'ach_monthly_savings';

  @override
  AchievementGroup get group => AchievementGroup.savings;

  @override
  IconData get icon => Icons.savings_rounded;

  @override
  AchievementValueFormat get format => AchievementValueFormat.money;

  @override
  String get traceReason => 'Mejor ahorro conseguido en un solo mes';

  @override
  String get traceFormula => 'max(ingresos − gastos) por mes';

  @override
  double currentValue(DashboardAnalysisContext context) {
    var best = 0.0;
    for (final month in context.snapshot.monthlyHistory.values) {
      if (month.savings > best) best = month.savings;
    }
    return best;
  }

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 100,
          title: 'Primer ahorro de \$100',
          goal: '\$100 ahorrados en un mes',
          celebration: 'Tu mejor mes cerró con {v} ahorrados',
        ),
        AchievementTier(
          threshold: 500,
          title: 'Ahorrador consolidado',
          goal: '\$500 ahorrados en un mes',
          celebration: 'Llegaste a {v} de ahorro en un solo mes',
        ),
        AchievementTier(
          threshold: 1000,
          title: 'Mil en un mes',
          goal: '\$1.000 ahorrados en un mes',
          celebration: 'Ahorraste {v} en un mes. Excelente',
        ),
        AchievementTier(
          threshold: 5000,
          title: 'Gran ahorrador',
          goal: '\$5.000 ahorrados en un mes',
          celebration: '{v} de ahorro en un solo mes',
        ),
      ];
}

class TotalSavingsAchievementAnalyzer extends TieredAchievementAnalyzer {
  @override
  String get id => 'ach_total_savings';

  @override
  AchievementGroup get group => AchievementGroup.savings;

  @override
  IconData get icon => Icons.account_balance_rounded;

  @override
  AchievementValueFormat get format => AchievementValueFormat.money;

  @override
  String get traceReason => 'Suma del ahorro de todos tus meses en positivo';

  @override
  String get traceFormula => 'Σ (ingresos − gastos) de los meses con ahorro';

  @override
  double currentValue(DashboardAnalysisContext context) {
    var total = 0.0;
    for (final month in context.snapshot.monthlyHistory.values) {
      if (month.savings > 0) total += month.savings;
    }
    return total;
  }

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 100,
          title: 'Primeros \$100 acumulados',
          goal: '\$100 de ahorro acumulado',
          celebration: 'Acumulaste {v} de ahorro',
        ),
        AchievementTier(
          threshold: 500,
          title: 'Colchón en marcha',
          goal: '\$500 de ahorro acumulado',
          celebration: 'Ya llevas {v} ahorrados en total',
        ),
        AchievementTier(
          threshold: 2000,
          title: 'Colchón sólido',
          goal: '\$2.000 de ahorro acumulado',
          celebration: '{v} de ahorro acumulado',
        ),
        AchievementTier(
          threshold: 10000,
          title: 'Patrimonio en construcción',
          goal: '\$10.000 de ahorro acumulado',
          celebration: 'Acumulaste {v}. Un logro enorme',
        ),
      ];
}

class SavingsRateAchievementAnalyzer extends TieredAchievementAnalyzer {
  @override
  String get id => 'ach_savings_rate';

  @override
  AchievementGroup get group => AchievementGroup.savings;

  @override
  IconData get icon => Icons.percent_rounded;

  @override
  AchievementValueFormat get format => AchievementValueFormat.percent;

  @override
  String get traceReason => 'Porcentaje de tus ingresos que estás ahorrando';

  @override
  String get traceFormula => '(ingresos − gastos) ÷ ingresos × 100';

  @override
  double currentValue(DashboardAnalysisContext context) {
    if (context.snapshot.currentMonthIncome <= 0) return 0;
    final rate = context.snapshot.savingsRate * 100;
    return rate > 0 ? rate : 0;
  }

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 10,
          title: 'Ahorras el 10%',
          goal: '10% de tasa de ahorro',
          celebration: 'Estás ahorrando el {v} de tus ingresos',
        ),
        AchievementTier(
          threshold: 20,
          title: 'Ahorras el 20%',
          goal: '20% de tasa de ahorro',
          celebration: 'Ahorras el {v} de lo que ingresas. Muy saludable',
        ),
        AchievementTier(
          threshold: 30,
          title: 'Ahorras el 30%',
          goal: '30% de tasa de ahorro',
          celebration: '{v} de tus ingresos van al ahorro',
        ),
        AchievementTier(
          threshold: 50,
          title: 'Ahorras la mitad',
          goal: '50% de tasa de ahorro',
          celebration: 'Ahorras el {v} de tus ingresos. Nivel experto',
        ),
      ];
}

class PositiveMonthsAchievementAnalyzer extends TieredAchievementAnalyzer {
  @override
  String get id => 'ach_positive_months';

  @override
  AchievementGroup get group => AchievementGroup.savings;

  @override
  IconData get icon => Icons.check_circle_outline_rounded;

  @override
  String get unit => 'meses';

  @override
  String get traceReason => 'Meses cerrados en los que ahorraste dinero';

  @override
  String get traceFormula => 'count(meses con ingresos > gastos)';

  @override
  double currentValue(DashboardAnalysisContext context) => context
      .snapshot.monthlyHistory.values
      .where((m) => m.transactionCount > 0 && m.savings > 0)
      .length
      .toDouble();

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 1,
          title: 'Primer mes en verde',
          goal: '1 mes con ahorro',
          celebration: 'Cerraste un mes gastando menos de lo que ingresaste',
        ),
        AchievementTier(
          threshold: 3,
          title: 'Tres meses en verde',
          goal: '3 meses con ahorro',
          celebration: '{v} meses cerrados con ahorro positivo',
        ),
        AchievementTier(
          threshold: 6,
          title: 'Medio año en verde',
          goal: '6 meses con ahorro',
          celebration: '{v} meses ahorrando. Vas muy bien',
        ),
        AchievementTier(
          threshold: 12,
          title: 'Un año en verde',
          goal: '12 meses con ahorro',
          celebration: '{v} meses en positivo. Dominas tus finanzas',
        ),
      ];
}

class SavingsRecordAchievementAnalyzer extends SingleAchievementAnalyzer {
  @override
  String get id => 'ach_savings_record';

  @override
  AchievementGroup get group => AchievementGroup.savings;

  @override
  IconData get icon => Icons.emoji_events_rounded;

  @override
  String get title => 'Nuevo récord de ahorro';

  @override
  String get lockedHint => 'Supera tu mejor mes de ahorro';

  @override
  String get traceReason => 'El ahorro del mes actual es el máximo registrado';

  @override
  String get traceFormula => 'ahorro(mes actual) = max(histórico)';

  @override
  bool isUnlocked(DashboardAnalysisContext context) {
    final best = context.snapshot.bestSavingsMonth;
    return best != null &&
        best.monthKey == context.snapshot.currentMonthKey &&
        best.savings > 0 &&
        context.snapshot.monthlyHistory.length >= 2;
  }

  @override
  String unlockedMessage(DashboardAnalysisContext context) =>
      'Este mes superaste tu mejor ahorro histórico con '
      '${FormatUtils.formatMoney(context.snapshot.currentMonthSavings)}';

  @override
  List<DataPoint> traceInputs(DashboardAnalysisContext context) => [
        DataPoint(
          label: 'Ahorro del mes',
          value: FormatUtils.formatMoney(context.snapshot.currentMonthSavings),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────
// Presupuestos
// ─────────────────────────────────────────────────────────────────────────

class BudgetStreakAchievementAnalyzer extends TieredAchievementAnalyzer {
  @override
  String get id => 'ach_budget_streak';

  @override
  AchievementGroup get group => AchievementGroup.budgets;

  @override
  IconData get icon => Icons.verified_outlined;

  @override
  String get unit => 'meses';

  @override
  String get traceReason =>
      'Meses cerrados consecutivos sin superar ningún presupuesto mensual';

  @override
  String get traceFormula => 'gastos(categoría, mes) ≤ límite del presupuesto';

  @override
  double currentValue(DashboardAnalysisContext context) {
    final monthlyBudgets = context.snapshot.budgetProgress
        .where((p) => p.budget.period == BudgetPeriod.monthly)
        .toList();
    if (monthlyBudgets.isEmpty) return 0;

    final months = _completedMonths(context);
    if (months.isEmpty) return 0;

    var streak = 0;
    for (var i = months.length - 1; i >= 0; i--) {
      final key = months[i].monthKey;
      final allSafe = monthlyBudgets.every((p) {
        final spent = context.snapshot
            .categoryExpensesForMonth(key, _budgetCategoryKey(p.budget));
        return spent <= p.budget.amount;
      });
      if (!allSafe) break;
      streak++;
    }
    return streak.toDouble();
  }

  String _budgetCategoryKey(Budget budget) {
    if (budget.hasCustomCategory) return 'custom:${budget.customCategoryId}';
    return 'system:${budget.category.name}';
  }

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 1,
          title: 'Presupuesto cumplido',
          goal: '1 mes respetando tus presupuestos',
          celebration: 'Cerraste un mes sin pasarte de ningún presupuesto',
        ),
        AchievementTier(
          threshold: 3,
          title: 'Racha de presupuestos',
          goal: '3 meses respetando tus presupuestos',
          celebration: '{v} meses seguidos cumpliendo tus presupuestos',
        ),
        AchievementTier(
          threshold: 6,
          title: 'Disciplina de acero',
          goal: '6 meses respetando tus presupuestos',
          celebration: '{v} meses consecutivos sin excederte',
        ),
        AchievementTier(
          threshold: 12,
          title: 'Un año bajo control',
          goal: '12 meses respetando tus presupuestos',
          celebration: '{v} meses seguidos dentro del presupuesto',
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────
// Metas
// ─────────────────────────────────────────────────────────────────────────

class GoalsCompletedAchievementAnalyzer extends TieredAchievementAnalyzer {
  @override
  String get id => 'ach_goals_completed';

  @override
  AchievementGroup get group => AchievementGroup.goals;

  @override
  IconData get icon => Icons.military_tech_rounded;

  @override
  String get unit => 'metas';

  @override
  String get traceReason => 'Metas que alcanzaron el 100% de su objetivo';

  @override
  String get traceFormula => 'count(metas con estado completado)';

  @override
  double currentValue(DashboardAnalysisContext context) => context
      .allAccountGoals
      .where((g) => g.status == GoalStatus.completed)
      .length
      .toDouble();

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 1,
          title: 'Primera meta completada',
          goal: '1 meta completada',
          celebration: 'Completaste tu primera meta de ahorro',
        ),
        AchievementTier(
          threshold: 3,
          title: 'Cazador de metas',
          goal: '3 metas completadas',
          celebration: 'Ya completaste {v} metas',
        ),
        AchievementTier(
          threshold: 5,
          title: 'Coleccionista de metas',
          goal: '5 metas completadas',
          celebration: '{v} metas cumplidas. Sabes terminar lo que empiezas',
        ),
        AchievementTier(
          threshold: 10,
          title: 'Imparable',
          goal: '10 metas completadas',
          celebration: '{v} metas completadas. Increíble',
        ),
      ];
}

class GoalNearAchievementAnalyzer extends SingleAchievementAnalyzer {
  @override
  String get id => 'ach_goal_near';

  @override
  AchievementGroup get group => AchievementGroup.goals;

  @override
  IconData get icon => Icons.sports_score_rounded;

  @override
  String get title => 'Meta a la vista';

  @override
  String get lockedHint => 'Lleva alguna meta al 75% de su objetivo';

  @override
  String get traceReason => 'Alguna meta activa superó el 75% de progreso';

  @override
  String get traceFormula => 'progreso(meta) ≥ 75%';

  FinancialGoal? _closest(DashboardAnalysisContext context) {
    final candidates = context.activeGoals
        .where((g) => g.progressPercentage >= 0.75)
        .toList()
      ..sort((a, b) => b.progressPercentage.compareTo(a.progressPercentage));
    return candidates.isEmpty ? null : candidates.first;
  }

  @override
  bool isUnlocked(DashboardAnalysisContext context) =>
      _closest(context) != null;

  @override
  String unlockedMessage(DashboardAnalysisContext context) {
    final goal = _closest(context)!;
    final percent = (goal.progressPercentage * 100).toStringAsFixed(0);
    return 'Tu meta "${goal.name}" ya va en el $percent%';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Crecimiento
// ─────────────────────────────────────────────────────────────────────────

/// Base de las rachas mes a mes (ahorro, gastos, ingresos). Solo considera
/// meses cerrados para no comparar un mes incompleto con uno completo.
abstract class _MonthlyStreakAchievementAnalyzer
    extends TieredAchievementAnalyzer {
  bool improved(MonthAggregate current, MonthAggregate previous);

  @override
  double currentValue(DashboardAnalysisContext context) {
    final months = _completedMonths(context);
    if (months.length < 2) return 0;

    var streak = 0;
    for (var i = months.length - 1; i > 0; i--) {
      if (!improved(months[i], months[i - 1])) break;
      streak++;
    }
    return streak.toDouble();
  }
}

class SavingsUpStreakAchievementAnalyzer
    extends _MonthlyStreakAchievementAnalyzer {
  @override
  String get id => 'ach_savings_up_streak';

  @override
  AchievementGroup get group => AchievementGroup.growth;

  @override
  IconData get icon => Icons.trending_up_rounded;

  @override
  String get unit => 'meses';

  @override
  String get traceReason => 'Meses cerrados consecutivos aumentando tu ahorro';

  @override
  String get traceFormula => 'ahorro(mes) > ahorro(mes anterior)';

  @override
  bool improved(MonthAggregate current, MonthAggregate previous) =>
      current.savings > previous.savings;

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 2,
          title: 'Ahorro en ascenso',
          goal: '2 meses aumentando el ahorro',
          celebration: '{v} meses seguidos ahorrando más que el anterior',
        ),
        AchievementTier(
          threshold: 3,
          title: 'Tendencia al alza',
          goal: '3 meses aumentando el ahorro',
          celebration: '{v} meses consecutivos mejorando tu ahorro',
        ),
        AchievementTier(
          threshold: 6,
          title: 'Escalada de ahorro',
          goal: '6 meses aumentando el ahorro',
          celebration: '{v} meses seguidos subiendo tu ahorro',
        ),
      ];
}

class ExpenseDownStreakAchievementAnalyzer
    extends _MonthlyStreakAchievementAnalyzer {
  @override
  String get id => 'ach_expense_down_streak';

  @override
  AchievementGroup get group => AchievementGroup.growth;

  @override
  IconData get icon => Icons.trending_down_rounded;

  @override
  String get unit => 'meses';

  @override
  String get traceReason => 'Meses cerrados consecutivos reduciendo tus gastos';

  @override
  String get traceFormula => 'gastos(mes) < gastos(mes anterior)';

  @override
  bool improved(MonthAggregate current, MonthAggregate previous) =>
      current.expenses < previous.expenses;

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 1,
          title: 'Recorte inteligente',
          goal: '1 mes gastando menos',
          celebration: 'Cerraste un mes gastando menos que el anterior',
        ),
        AchievementTier(
          threshold: 3,
          title: 'Gastos a la baja',
          goal: '3 meses gastando menos',
          celebration: '{v} meses seguidos reduciendo tus gastos',
        ),
        AchievementTier(
          threshold: 6,
          title: 'Maestro del recorte',
          goal: '6 meses gastando menos',
          celebration: '{v} meses consecutivos bajando tus gastos',
        ),
      ];
}

class IncomeUpStreakAchievementAnalyzer
    extends _MonthlyStreakAchievementAnalyzer {
  @override
  String get id => 'ach_income_up_streak';

  @override
  AchievementGroup get group => AchievementGroup.growth;

  @override
  IconData get icon => Icons.rocket_launch_rounded;

  @override
  String get unit => 'meses';

  @override
  String get traceReason =>
      'Meses cerrados consecutivos aumentando tus ingresos';

  @override
  String get traceFormula => 'ingresos(mes) > ingresos(mes anterior)';

  @override
  bool improved(MonthAggregate current, MonthAggregate previous) =>
      current.income > previous.income;

  @override
  List<AchievementTier> get tiers => const [
        AchievementTier(
          threshold: 2,
          title: 'Ingresos al alza',
          goal: '2 meses aumentando ingresos',
          celebration: '{v} meses seguidos aumentando tus ingresos',
        ),
        AchievementTier(
          threshold: 3,
          title: 'Crecimiento sostenido',
          goal: '3 meses aumentando ingresos',
          celebration: '{v} meses consecutivos ganando más',
        ),
        AchievementTier(
          threshold: 6,
          title: 'Despegue',
          goal: '6 meses aumentando ingresos',
          celebration: '{v} meses seguidos creciendo en ingresos',
        ),
      ];
}

class IncomeDiversityAchievementAnalyzer extends SingleAchievementAnalyzer {
  @override
  String get id => 'ach_income_diversity';

  @override
  AchievementGroup get group => AchievementGroup.growth;

  @override
  IconData get icon => Icons.hub_outlined;

  @override
  String get title => 'Ingresos diversificados';

  @override
  String get lockedHint =>
      'Consigue una segunda fuente de ingresos este mes';

  @override
  String get traceReason =>
      'Más de una fuente de ingresos y ninguna concentra más del 70%';

  @override
  String get traceFormula => 'count(fuentes) ≥ 2 y max(% de fuente) < 70%';

  @override
  bool isUnlocked(DashboardAnalysisContext context) {
    final sources = context.snapshot.incomeBySource.values;
    if (sources.length < 2) return false;
    final top = context.snapshot.topIncomeSource;
    return top != null && top.percentageOfIncome < 70;
  }

  @override
  String unlockedMessage(DashboardAnalysisContext context) {
    final count = context.snapshot.incomeBySource.length;
    return 'Tienes $count fuentes de ingreso y ninguna domina tus finanzas';
  }
}
