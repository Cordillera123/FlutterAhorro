import 'package:flutter/material.dart';
import '../models/recurring_expense.dart';
import '../models/reminder.dart';
import '../utils/format_utils.dart';
import 'goal_service.dart';
import 'recurring_expense_service.dart';

/// Calcula los recordatorios en pantalla (gastos recurrentes próximos y
/// metas de ahorro que necesitan atención) a partir de datos ya cargados en
/// memoria por [RecurringExpenseService] y [GoalService].
///
/// No persiste nada ni programa notificaciones del sistema: se recalcula
/// cada vez que se llama, igual que las alertas del dashboard inteligente.
class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  final RecurringExpenseService _recurringExpenseService =
      RecurringExpenseService();
  final GoalService _goalService = GoalService();

  /// Ventana de aviso para gastos recurrentes: cuántos días hacia adelante
  /// se consideran "próximos".
  static const int recurringWindowDays = 3;

  /// Ventana de aviso para el vencimiento de metas.
  static const int goalDeadlineWindowDays = 7;

  List<Reminder> buildReminders() {
    final reminders = <Reminder>[
      ..._buildRecurringExpenseReminders(),
      ..._buildGoalReminders(),
    ];

    reminders.sort((a, b) {
      final byUrgency = a.urgency.index.compareTo(b.urgency.index);
      if (byUrgency != 0) return byUrgency;
      return a.dueDate.compareTo(b.dueDate);
    });

    return reminders;
  }

  List<Reminder> _buildRecurringExpenseReminders() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final reminders = <Reminder>[];

    for (final expense in _recurringExpenseService.activeRecurringExpenses) {
      final next = expense.nextOccurrence();
      if (next == null) continue;

      final daysUntil = next.difference(todayDate).inDays;
      if (daysUntil > recurringWindowDays) continue;

      reminders.add(
        Reminder(
          id: 'recurring_${expense.id}_${next.toIso8601String()}',
          type: ReminderType.recurringExpense,
          title: expense.name,
          message: _recurringMessage(expense, daysUntil),
          icon: Icons.event_repeat_rounded,
          urgency: _urgencyForDays(daysUntil),
          dueDate: next,
          referenceId: expense.id,
        ),
      );
    }

    return reminders;
  }

  String _recurringMessage(RecurringExpense expense, int daysUntil) {
    final amount = FormatUtils.formatMoney(expense.amount);
    final when = daysUntil == 1 ? 'mañana' : 'en $daysUntil días';
    return '$amount · ${expense.categoryName} · $when';
  }

  List<Reminder> _buildGoalReminders() {
    final reminders = <Reminder>[];

    for (final goal in _goalService.activeGoals) {
      // Las metas vencidas ya se reportan en las alertas del dashboard
      // (GoalOverdueAlertAnalyzer) — evitar duplicar el mismo aviso aquí.
      if (goal.isCompleted || goal.isOverdue) continue;

      if (goal.daysRemaining <= goalDeadlineWindowDays) {
        reminders.add(
          Reminder(
            id: 'goal_deadline_${goal.id}',
            type: ReminderType.goalDeadline,
            title: goal.name,
            message:
                '${goal.timeInfo} · faltan ${FormatUtils.formatMoney(goal.remainingAmount)}',
            icon: Icons.flag_rounded,
            urgency: _urgencyForDays(goal.daysRemaining),
            dueDate: goal.targetDate,
            referenceId: goal.id ?? '',
          ),
        );
      } else if (!goal.isOnTrack) {
        reminders.add(
          Reminder(
            id: 'goal_offtrack_${goal.id}',
            type: ReminderType.goalOffTrack,
            title: goal.name,
            message:
                'Vas atrasado — ${goal.suggestedContributionLabel} para llegar a tiempo',
            icon: Icons.trending_down_rounded,
            urgency: ReminderUrgency.upcoming,
            dueDate: goal.targetDate,
            referenceId: goal.id ?? '',
          ),
        );
      }
    }

    return reminders;
  }

  ReminderUrgency _urgencyForDays(int days) {
    if (days <= 1) return ReminderUrgency.tomorrow;
    if (days <= 7) return ReminderUrgency.thisWeek;
    return ReminderUrgency.upcoming;
  }
}
