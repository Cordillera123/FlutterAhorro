import 'package:flutter/material.dart';
import '../../../../models/budget.dart';
import '../../../../models/dashboard/dashboard_alert.dart';
import '../../../../models/dashboard/dashboard_analysis_context.dart';
import '../../../../models/dashboard/dashboard_enums.dart';
import '../../../../models/dashboard/message_trace.dart';
import '../../../../utils/format_utils.dart';
import '../../dashboard_analyzer.dart';

class BudgetExceededAlertAnalyzer implements DashboardAnalyzer<DashboardAlert> {
  @override
  String get id => 'alert_budget_exceeded';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.snapshot.budgetProgress.any(
      (p) => p.status == BudgetStatus.exceeded,
    );
  }

  @override
  DashboardAlert? analyze(DashboardAnalysisContext context) {
    final exceeded =
        context.snapshot.budgetProgress
            .where((p) => p.status == BudgetStatus.exceeded)
            .toList()
          ..sort((a, b) => b.spentAmount.compareTo(a.spentAmount));
    if (exceeded.isEmpty) return null;
    final p = exceeded.first;
    final over = p.spentAmount - p.budget.amount;
    return DashboardAlert(
      id: '${id}_${p.budget.id}',
      title: 'Presupuesto excedido',
      message:
          'Has excedido el presupuesto de ${p.budget.categoryName} por ${FormatUtils.formatMoney(over)}',
      icon: Icons.error_outline_rounded,
      severity: AlertSeverity.critical,
      trace: MessageTrace(
        reason:
            'El gasto en la categoría supera el límite del presupuesto activo',
        inputs: [
          DataPoint(
            label: 'Gastado',
            value: FormatUtils.formatMoney(p.spentAmount),
          ),
          DataPoint(
            label: 'Límite',
            value: FormatUtils.formatMoney(p.budget.amount),
          ),
        ],
        formula: 'excedente = gastado − límite',
      ),
    );
  }
}

class BudgetDangerAlertAnalyzer implements DashboardAnalyzer<DashboardAlert> {
  @override
  String get id => 'alert_budget_danger';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.snapshot.budgetProgress.any(
      (p) => p.status == BudgetStatus.danger,
    );
  }

  @override
  DashboardAlert? analyze(DashboardAnalysisContext context) {
    final danger =
        context.snapshot.budgetProgress
            .where((p) => p.status == BudgetStatus.danger)
            .toList()
          ..sort((a, b) => b.percentage.compareTo(a.percentage));
    if (danger.isEmpty) return null;
    final p = danger.first;
    return DashboardAlert(
      id: '${id}_${p.budget.id}',
      title: 'Presupuesto al límite',
      message:
          'Tu presupuesto de ${p.budget.categoryName} está al ${(p.percentage * 100).toStringAsFixed(0)}% — quedan ${FormatUtils.formatMoney(p.remainingAmount)}',
      icon: Icons.warning_amber_rounded,
      severity: AlertSeverity.warning,
      trace: MessageTrace(
        reason: 'El presupuesto alcanzó el 90% o más de su límite',
        inputs: [
          DataPoint(
            label: 'Porcentaje usado',
            value: '${(p.percentage * 100).toStringAsFixed(0)}%',
          ),
          DataPoint(
            label: 'Restante',
            value: FormatUtils.formatMoney(p.remainingAmount),
          ),
        ],
        formula: 'porcentaje = gastado / límite',
      ),
    );
  }
}

class NoIncomeWeekAlertAnalyzer implements DashboardAnalyzer<DashboardAlert> {
  @override
  String get id => 'alert_no_income_week';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.hasMonthData &&
        context.snapshot.incomeThisWeek <= 0 &&
        context.snapshot.expensesThisWeek > 0;
  }

  @override
  DashboardAlert? analyze(DashboardAnalysisContext context) {
    return DashboardAlert(
      id: id,
      title: 'Sin ingresos esta semana',
      message:
          'No has registrado ingresos esta semana, pero sí ${FormatUtils.formatMoney(context.snapshot.expensesThisWeek)} en gastos',
      icon: Icons.money_off_rounded,
      severity: AlertSeverity.warning,
      trace: MessageTrace(
        reason: 'No hay ingresos registrados en la semana calendario actual',
        inputs: [
          DataPoint(
            label: 'Ingresos semana',
            value: FormatUtils.formatMoney(0),
          ),
          DataPoint(
            label: 'Gastos semana',
            value: FormatUtils.formatMoney(context.snapshot.expensesThisWeek),
          ),
        ],
        formula: 'suma(ingresos desde el lunes) = 0',
      ),
    );
  }
}

class GoalOverdueAlertAnalyzer implements DashboardAnalyzer<DashboardAlert> {
  @override
  String get id => 'alert_goal_overdue';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.activeGoals.any((g) => g.isOverdue);
  }

  @override
  DashboardAlert? analyze(DashboardAnalysisContext context) {
    final overdue = context.activeGoals.where((g) => g.isOverdue).toList();
    if (overdue.isEmpty) return null;
    final goal = overdue.first;
    return DashboardAlert(
      id: '${id}_${goal.id}',
      title: 'Meta vencida',
      message:
          'La meta "${goal.name}" venció y te faltan ${FormatUtils.formatMoney(goal.remainingAmount)}',
      icon: Icons.flag_outlined,
      severity: AlertSeverity.critical,
      trace: MessageTrace(
        reason: 'La fecha objetivo de la meta ya pasó sin completarse',
        inputs: [
          DataPoint(label: 'Meta', value: goal.name),
          DataPoint(
            label: 'Restante',
            value: FormatUtils.formatMoney(goal.remainingAmount),
          ),
        ],
        formula: 'hoy > fechaObjetivo ∧ progreso < 100%',
      ),
    );
  }
}

class InactivityAlertAnalyzer implements DashboardAnalyzer<DashboardAlert> {
  @override
  String get id => 'alert_inactivity';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.snapshot.daysSinceLastTransaction >= 7;
  }

  @override
  DashboardAlert? analyze(DashboardAnalysisContext context) {
    final days = context.snapshot.daysSinceLastTransaction;
    return DashboardAlert(
      id: id,
      title: 'Inactividad en registros',
      message: 'Llevas $days días sin registrar movimientos',
      icon: Icons.event_busy_rounded,
      severity: days >= 14 ? AlertSeverity.critical : AlertSeverity.warning,
      trace: MessageTrace(
        reason: 'No hay transacciones recientes en la cuenta activa',
        inputs: [DataPoint(label: 'Días sin movimientos', value: '$days')],
        formula: 'días = hoy − fecha(última transacción)',
      ),
    );
  }
}

class NegativeSavingsAlertAnalyzer
    implements DashboardAnalyzer<DashboardAlert> {
  @override
  String get id => 'alert_negative_savings';

  @override
  bool canAnalyze(DashboardAnalysisContext context) {
    return context.hasMonthData &&
        context.snapshot.currentMonthIncome > 0 &&
        context.snapshot.currentMonthSavings < 0;
  }

  @override
  DashboardAlert? analyze(DashboardAnalysisContext context) {
    final deficit = context.snapshot.currentMonthSavings.abs();
    return DashboardAlert(
      id: id,
      title: 'Gastos superan ingresos',
      message:
          'Este mes tus gastos superan tus ingresos por ${FormatUtils.formatMoney(deficit)}',
      icon: Icons.trending_down_rounded,
      severity: AlertSeverity.critical,
      trace: MessageTrace(
        reason: 'El flujo mensual (ingresos − gastos) es negativo',
        inputs: [
          DataPoint(
            label: 'Ingresos',
            value: FormatUtils.formatMoney(context.snapshot.currentMonthIncome),
          ),
          DataPoint(
            label: 'Gastos',
            value: FormatUtils.formatMoney(
              context.snapshot.currentMonthExpenses,
            ),
          ),
        ],
        formula: 'ahorro = ingresos − gastos',
      ),
    );
  }
}
