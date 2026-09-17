import 'package:flutter/material.dart';
import '../../../../models/budget.dart';
import '../../../../models/dashboard/dashboard_analysis_context.dart';
import '../../../../models/dashboard/dashboard_opportunity.dart';
import '../../../../models/dashboard/message_trace.dart';
import '../../../../utils/format_utils.dart';
import '../../dashboard_analyzer.dart';

class ReduceCategoryOpportunityAnalyzer
    implements DashboardAnalyzer<DashboardOpportunity> {
  @override
  String get id => 'opp_reduce_category';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    final top = context.snapshot.topExpenseCategory;
    return top != null && top.amount >= 50;
  }

  @override
  DashboardOpportunity? analyze(DashboardAnalysisContext context) {
    final top = context.snapshot.topExpenseCategory!;
    const weeklyReduction = 20.0;
    final monthlySavings = weeklyReduction * 4.33;

    return DashboardOpportunity(
      id: '${id}_${top.key}',
      title: 'Reducir gastos',
      message:
          'Reduciendo ${FormatUtils.formatMoney(weeklyReduction)} semanales en ${top.displayName} ahorrarías aproximadamente ${FormatUtils.formatMoney(monthlySavings)} al mes',
      icon: Icons.restaurant_outlined,
      actionDescription:
          'Recorta ${FormatUtils.formatMoney(weeklyReduction)} por semana en ${top.displayName}',
      expectedBenefit:
          'Ahorro estimado de ${FormatUtils.formatMoney(monthlySavings)} al mes',
      impactAmount: monthlySavings,
      relatedCategoryKey: top.key,
      trace: MessageTrace(
        reason: 'Simulación de reducción fija sobre la categoría de mayor gasto',
        inputs: [
          DataPoint(label: 'Categoría', value: top.displayName),
          DataPoint(
            label: 'Gasto actual',
            value: FormatUtils.formatMoney(top.amount),
          ),
        ],
        formula: 'ahorro mensual ≈ reducción semanal × 4.33',
        impactDescription:
            'Ahorro de ${FormatUtils.formatMoney(monthlySavings)} mensual',
      ),
    );
  }
}

class BoostGoalOpportunityAnalyzer
    implements DashboardAnalyzer<DashboardOpportunity> {
  @override
  String get id => 'opp_boost_goal';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.activeGoals.any((g) => g.remainingAmount > 0);
  }

  @override
  DashboardOpportunity? analyze(DashboardAnalysisContext context) {
    final goal = context.activeGoals
        .where((g) => g.remainingAmount > 0)
        .reduce((a, b) => a.remainingAmount < b.remainingAmount ? a : b);

    const extraWeekly = 5.0;
    final currentWeekly = goal.id != null
        ? context.weeklyContributionRateForGoal(goal.id!)
        : goal.suggestedContributionAmount;
    if (currentWeekly <= 0) return null;

    final currentWeeks = goal.remainingAmount / currentWeekly;
    final newWeeks = goal.remainingAmount / (currentWeekly + extraWeekly);
    final weeksSaved = (currentWeeks - newWeeks).ceil();
    if (weeksSaved < 1) return null;

    return DashboardOpportunity(
      id: '${id}_${goal.id}',
      title: 'Acelerar meta',
      message:
          'Si aumentas tu ahorro semanal en ${FormatUtils.formatMoney(extraWeekly)}, terminarás "${goal.name}" $weeksSaved semanas antes',
      icon: Icons.savings_outlined,
      actionDescription:
          'Aporta ${FormatUtils.formatMoney(extraWeekly)} extra cada semana',
      expectedBenefit: '$weeksSaved semanas antes',
      impactDays: weeksSaved * 7,
      relatedGoalId: goal.id,
      trace: MessageTrace(
        reason: 'Simulación de aporte semanal adicional',
        inputs: [
          DataPoint(label: 'Meta', value: goal.name),
          DataPoint(
            label: 'Restante',
            value: FormatUtils.formatMoney(goal.remainingAmount),
          ),
        ],
        formula: 'semanas = restante / ahorro semanal',
        impactDescription: '$weeksSaved semanas menos',
      ),
    );
  }
}

class BudgetTrimOpportunityAnalyzer
    implements DashboardAnalyzer<DashboardOpportunity> {
  @override
  String get id => 'opp_budget_trim';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.snapshot.budgetProgress.any(
      (p) => p.status == BudgetStatus.safe && p.percentage < 0.5,
    );
  }

  @override
  DashboardOpportunity? analyze(DashboardAnalysisContext context) {
    final underused = context.snapshot.budgetProgress
        .where((p) => p.status == BudgetStatus.safe && p.percentage < 0.5)
        .toList()
      ..sort((a, b) => a.percentage.compareTo(b.percentage));

    if (underused.isEmpty) return null;
    final p = underused.first;
    final trimPct = 15.0;
    final savings = p.budget.amount * (trimPct / 100);

    return DashboardOpportunity(
      id: '${id}_${p.budget.id}',
      title: 'Optimizar presupuesto',
      message:
          'Tu presupuesto de ${p.budget.categoryName} puede reducirse un ${trimPct.toStringAsFixed(0)}% sin afectar tus gastos actuales',
      icon: Icons.tune_rounded,
      actionDescription:
          'Ajusta el límite de ${p.budget.categoryName} hacia abajo',
      expectedBenefit:
          'Liberarías ${FormatUtils.formatMoney(savings)} para otras metas',
      impactAmount: savings,
      relatedBudgetId: p.budget.id,
      trace: MessageTrace(
        reason: 'Presupuesto usa menos del 50% — margen para recortar',
        inputs: [
          DataPoint(
            label: 'Usado',
            value: '${(p.percentage * 100).toStringAsFixed(0)}%',
          ),
        ],
        formula: 'ahorro = límite × 15%',
        impactDescription: '${FormatUtils.formatMoney(savings)} liberados',
      ),
    );
  }
}

class RecordIncomeOpportunityAnalyzer
    implements DashboardAnalyzer<DashboardOpportunity> {
  @override
  String get id => 'opp_record_income';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.snapshot.incomeThisWeek <= 0 &&
        context.snapshot.expensesThisWeek > 0;
  }

  @override
  DashboardOpportunity? analyze(DashboardAnalysisContext context) {
    return DashboardOpportunity(
      id: id,
      title: 'Registrar ingresos',
      message:
          'No has registrado ingresos esta semana — hacerlo mejorará la precisión del análisis',
      icon: Icons.add_chart_rounded,
      actionDescription: 'Registra tus ingresos de esta semana',
      expectedBenefit: 'Análisis y proyecciones más precisos',
      trace: MessageTrace(
        reason: 'Hay gastos pero no ingresos en la semana actual',
        inputs: [
          DataPoint(label: 'Ingresos semana', value: FormatUtils.formatMoney(0)),
        ],
        formula: 'ingresos(semana) = 0',
        impactDescription: 'Mejor precisión en tasa de ahorro y proyecciones',
      ),
    );
  }
}

class BudgetAlertOpportunityAnalyzer
    implements DashboardAnalyzer<DashboardOpportunity> {
  @override
  String get id => 'opp_budget_alert';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.snapshot.budgetProgress.any(
      (p) =>
          p.status == BudgetStatus.warning ||
          p.status == BudgetStatus.danger,
    );
  }

  @override
  DashboardOpportunity? analyze(DashboardAnalysisContext context) {
    final pressured = context.snapshot.budgetProgress
        .where(
          (p) =>
              p.status == BudgetStatus.warning ||
              p.status == BudgetStatus.danger,
        )
        .toList()
      ..sort((a, b) => b.percentage.compareTo(a.percentage));

    if (pressured.isEmpty) return null;
    final p = pressured.first;
    final daysLeft = p.budget.daysRemaining.clamp(1, 365);
    final reduceDaily = p.remainingAmount / daysLeft;

    return DashboardOpportunity(
      id: '${id}_${p.budget.id}',
      title: 'Controlar presupuesto',
      message:
          'Tu presupuesto de ${p.budget.categoryName} está al ${(p.percentage * 100).toStringAsFixed(0)}% — reduce a ${FormatUtils.formatMoney(reduceDaily)} diarios para llegar a fin de mes',
      icon: Icons.warning_amber_rounded,
      actionDescription:
          'Limita ${p.budget.categoryName} a ${FormatUtils.formatMoney(reduceDaily)} por día',
      expectedBenefit: 'Evitar exceder el presupuesto',
      impactAmount: p.remainingAmount,
      relatedBudgetId: p.budget.id,
      trace: MessageTrace(
        reason: 'Presupuesto en zona de alerta (70%+)',
        inputs: [
          DataPoint(
            label: 'Restante',
            value: FormatUtils.formatMoney(p.remainingAmount),
          ),
          DataPoint(label: 'Días restantes', value: '$daysLeft'),
        ],
        formula: 'límite diario = restante / días restantes',
        impactDescription: 'Mantener el presupuesto dentro del límite',
      ),
    );
  }
}

class SavingsOpportunityAnalyzer
    implements DashboardAnalyzer<DashboardOpportunity> {
  @override
  String get id => 'opp_savings_pace';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.snapshot.currentMonthSavings > 0 &&
        context.snapshot.daysElapsedInMonth >= 7;
  }

  @override
  DashboardOpportunity? analyze(DashboardAnalysisContext context) {
    final s = context.snapshot;
    final weeklySavings = (s.currentMonthSavings / s.daysElapsedInMonth) * 7;
    final monthlyExtra = weeklySavings;

    return DashboardOpportunity(
      id: id,
      title: 'Mantener el ritmo',
      message:
          'Si mantienes el ritmo de esta semana, ahorrarías aproximadamente ${FormatUtils.formatMoney(monthlyExtra)} extra este mes',
      icon: Icons.trending_up_rounded,
      actionDescription: 'Mantén tus hábitos de gasto actuales',
      expectedBenefit:
          '${FormatUtils.formatMoney(monthlyExtra)} adicionales proyectados',
      impactAmount: monthlyExtra,
      trace: MessageTrace(
        reason: 'Extrapolación del ahorro semanal actual',
        inputs: [
          DataPoint(
            label: 'Ahorro acumulado',
            value: FormatUtils.formatMoney(s.currentMonthSavings),
          ),
        ],
        formula: 'ritmo semanal = (ahorro / días) × 7',
        impactDescription: FormatUtils.formatMoney(monthlyExtra),
      ),
    );
  }
}
