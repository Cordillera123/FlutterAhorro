import 'package:flutter/material.dart';
import '../../../../models/budget.dart';
import '../../../../models/financial_goal.dart';
import '../../../../models/dashboard/dashboard_analysis_context.dart';
import '../../../../models/dashboard/dashboard_enums.dart';
import '../../../../models/dashboard/dashboard_forecast.dart';
import '../../../../models/dashboard/message_trace.dart';
import '../../../../utils/format_utils.dart';
import '../../dashboard_analyzer.dart';
import '../../dashboard_helpers.dart';

class MonthEndSavingsForecastAnalyzer
    implements DashboardAnalyzer<DashboardForecast> {
  @override
  String get id => 'forecast_month_end_savings';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.hasMonthData &&
        context.snapshot.daysElapsedInMonth >= 7;
  }

  @override
  DashboardForecast? analyze(DashboardAnalysisContext context) {
    final s = context.snapshot;
    final projectedIncome =
        s.dailyAverageIncome * s.daysInMonth;
    final projectedExpenses =
        s.dailyAverageExpense * s.daysInMonth;
    final projectedSavings = projectedIncome - projectedExpenses;

    return DashboardForecast(
      id: id,
      title: 'Proyección de fin de mes',
      message:
          'Si continúas al ritmo actual, terminarás el mes con aproximadamente ${FormatUtils.formatMoney(projectedSavings)} de ahorro (flujo)',
      icon: Icons.insights_rounded,
      confidence: s.daysElapsedInMonth >= 15
          ? PredictionConfidence.high
          : PredictionConfidence.medium,
      projectedAmount: projectedSavings,
      trace: MessageTrace(
        reason: 'Extrapolación lineal del ritmo diario al total del mes',
        inputs: [
          DataPoint(
            label: 'Promedio ingreso/día',
            value: FormatUtils.formatMoney(s.dailyAverageIncome),
          ),
          DataPoint(
            label: 'Promedio gasto/día',
            value: FormatUtils.formatMoney(s.dailyAverageExpense),
          ),
          DataPoint(label: 'Días del mes', value: '${s.daysInMonth}'),
        ],
        formula:
            'proy. ahorro = (ingreso/día × días) − (gasto/día × días)',
      ),
    );
  }
}

class ExpenseTrendForecastAnalyzer
    implements DashboardAnalyzer<DashboardForecast> {
  @override
  String get id => 'forecast_expense_trend';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.hasPreviousMonthData &&
        context.snapshot.daysElapsedInMonth >= 7;
  }

  @override
  DashboardForecast? analyze(DashboardAnalysisContext context) {
    final s = context.snapshot;
    final projectedExpenses = s.dailyAverageExpense * s.daysInMonth;
    final growth = DashboardHelpers.growthPercentage(
      projectedExpenses,
      s.previousMonthExpenses,
    );
    if (growth.abs() < 5) return null;

    return DashboardForecast(
      id: id,
      title: 'Tendencia de gastos',
      message: growth > 0
          ? 'Si continúas con esta tendencia, gastarás un ${growth.toStringAsFixed(0)}% más que el mes pasado'
          : 'Si continúas con esta tendencia, gastarás un ${growth.abs().toStringAsFixed(0)}% menos que el mes pasado',
      icon: Icons.show_chart_rounded,
      confidence: PredictionConfidence.medium,
      projectedPercentage: growth,
      projectedAmount: projectedExpenses,
      trace: MessageTrace(
        reason: 'Proyección de gastos vs mes anterior',
        inputs: [
          DataPoint(
            label: 'Gastos proyectados',
            value: FormatUtils.formatMoney(projectedExpenses),
          ),
          DataPoint(
            label: 'Gastos mes anterior',
            value: FormatUtils.formatMoney(s.previousMonthExpenses),
          ),
        ],
        formula:
            'proy. gastos = promedio diario × días; comparar con anterior',
      ),
    );
  }
}

class GoalCompletionForecastAnalyzer
    implements DashboardAnalyzer<DashboardForecast> {
  @override
  String get id => 'forecast_goal_completion';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.activeGoals.any(
      (g) =>
          g.remainingAmount > 0 &&
          context.weeklyContributionRateForGoal(g.id!) > 0,
    );
  }

  @override
  DashboardForecast? analyze(DashboardAnalysisContext context) {
    FinancialGoal? bestGoal;
    int bestDaysDiff = 0;

    for (final goal in context.activeGoals) {
      if (goal.id == null || goal.remainingAmount <= 0) continue;
      final weeklyRate = context.weeklyContributionRateForGoal(goal.id!);
      if (weeklyRate <= 0) continue;
      final weeksNeeded = goal.remainingAmount / weeklyRate;
      final daysNeeded = (weeksNeeded * 7).ceil();
      final daysToTarget = goal.daysRemaining;
      final diff = daysToTarget - daysNeeded;
      if (bestGoal == null || diff.abs() > bestDaysDiff.abs()) {
        bestGoal = goal;
        bestDaysDiff = diff;
      }
    }

    if (bestGoal == null || bestDaysDiff == 0) return null;
    final earlier = bestDaysDiff > 0;

    return DashboardForecast(
      id: '${id}_${bestGoal.id}',
      title: 'Proyección de meta',
      message: earlier
          ? 'Si mantienes tu ritmo de ahorro, completarás "${bestGoal.name}" $bestDaysDiff días antes'
          : 'Al ritmo actual completarás "${bestGoal.name}" ${bestDaysDiff.abs()} días después de la fecha objetivo',
      icon: Icons.flag_rounded,
      confidence: PredictionConfidence.medium,
      projectedDays: bestDaysDiff.abs(),
      trace: MessageTrace(
        reason: 'Ritmo semanal de contribuciones extrapolado al monto restante',
        inputs: [
          DataPoint(label: 'Meta', value: bestGoal.name),
          DataPoint(
            label: 'Restante',
            value: FormatUtils.formatMoney(bestGoal.remainingAmount),
          ),
        ],
        formula: 'días = restante / (ahorro semanal / 7)',
      ),
    );
  }
}

class GoalExtraSavingsForecastAnalyzer
    implements DashboardAnalyzer<DashboardForecast> {
  @override
  String get id => 'forecast_goal_extra_savings';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.activeGoals.any((g) => g.remainingAmount > 0);
  }

  @override
  DashboardForecast? analyze(DashboardAnalysisContext context) {
    final goal = context.activeGoals
        .where((g) => g.remainingAmount > 0)
        .reduce((a, b) => a.remainingAmount < b.remainingAmount ? a : b);

    const extraWeekly = 5.0;
    final currentWeekly = goal.id != null
        ? context.weeklyContributionRateForGoal(goal.id!)
        : 0.0;
    final effectiveWeekly = (currentWeekly + extraWeekly).clamp(0.01, double.infinity);
    final currentDays = (goal.remainingAmount / (currentWeekly > 0 ? currentWeekly / 7 : 1)).ceil();
    final newDays = (goal.remainingAmount / (effectiveWeekly / 7)).ceil();
    final daysSaved = currentDays - newDays;
    if (daysSaved < 7 || currentWeekly <= 0) return null;

    return DashboardForecast(
      id: '${id}_${goal.id}',
      title: 'Acelerar meta',
      message:
          'Si aumentas tu ahorro semanal en ${FormatUtils.formatMoney(extraWeekly)}, terminarás "${goal.name}" $daysSaved días antes',
      icon: Icons.rocket_launch_outlined,
      confidence: PredictionConfidence.medium,
      projectedDays: daysSaved,
      trace: MessageTrace(
        reason: 'Simulación con ahorro semanal adicional fijo',
        inputs: [
          DataPoint(label: 'Ahorro extra/semana', value: FormatUtils.formatMoney(extraWeekly)),
          DataPoint(label: 'Meta', value: goal.name),
        ],
        formula: 'días_nuevos = restante / ((ritmo + extra) / 7)',
        impactDescription: 'Ahorro adicional de ${FormatUtils.formatMoney(extraWeekly * 4)} al mes aprox.',
      ),
    );
  }
}

class BudgetDepletionForecastAnalyzer
    implements DashboardAnalyzer<DashboardForecast> {
  @override
  String get id => 'forecast_budget_depletion';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.snapshot.budgetProgress.any(
      (p) =>
          p.remainingAmount > 0 &&
          p.dailySpendRate > 0 &&
          p.status != BudgetStatus.exceeded,
    );
  }

  @override
  DashboardForecast? analyze(DashboardAnalysisContext context) {
    final candidates = context.snapshot.budgetProgress
        .where(
          (p) =>
              p.remainingAmount > 0 &&
              p.dailySpendRate > 0 &&
              p.status != BudgetStatus.exceeded,
        )
        .toList()
      ..sort((a, b) => a.daysUntilDepleted.compareTo(b.daysUntilDepleted));

    if (candidates.isEmpty) return null;
    final p = candidates.first;
    if (p.daysUntilDepleted > 30) return null;

    return DashboardForecast(
      id: '${id}_${p.budget.id}',
      title: 'Agotamiento de presupuesto',
      message:
          'Tu presupuesto de ${p.budget.categoryName} se agotará en aproximadamente ${p.daysUntilDepleted} días al ritmo actual',
      icon: Icons.hourglass_bottom_rounded,
      confidence: PredictionConfidence.high,
      projectedDays: p.daysUntilDepleted,
      trace: MessageTrace(
        reason: 'Días restantes = monto restante / gasto diario promedio',
        inputs: [
          DataPoint(
            label: 'Restante',
            value: FormatUtils.formatMoney(p.remainingAmount),
          ),
          DataPoint(
            label: 'Gasto diario',
            value: FormatUtils.formatMoney(p.dailySpendRate),
          ),
        ],
        formula: 'días = restante / (gastado / días transcurridos)',
      ),
    );
  }
}

class BalanceProjectionForecastAnalyzer
    implements DashboardAnalyzer<DashboardForecast> {
  @override
  String get id => 'forecast_balance_projection';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.hasMonthData &&
        context.snapshot.daysElapsedInMonth >= 7;
  }

  @override
  DashboardForecast? analyze(DashboardAnalysisContext context) {
    final s = context.snapshot;
    final netDaily = s.dailyAverageIncome - s.dailyAverageExpense;
    final remainingDays = s.daysInMonth - s.daysElapsedInMonth;
    final projectedBalance = s.totalBalance + (netDaily * remainingDays);

    return DashboardForecast(
      id: id,
      title: 'Proyección de saldo',
      message:
          'Tu saldo podría ser aproximadamente ${FormatUtils.formatMoney(projectedBalance)} a fin de mes',
      icon: Icons.account_balance_wallet_outlined,
      confidence: PredictionConfidence.medium,
      projectedAmount: projectedBalance,
      trace: MessageTrace(
        reason: 'Saldo actual más flujo neto diario proyectado',
        inputs: [
          DataPoint(
            label: 'Saldo actual',
            value: FormatUtils.formatMoney(s.totalBalance),
          ),
          DataPoint(
            label: 'Flujo neto/día',
            value: FormatUtils.formatMoney(netDaily),
          ),
        ],
        formula: 'saldo fin = saldo + (ingreso−gasto)/día × días restantes',
      ),
    );
  }
}
