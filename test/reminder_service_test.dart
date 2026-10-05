import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/financial_goal.dart';
import 'package:ahorro_app/models/recurring_expense.dart';
import 'package:ahorro_app/models/reminder.dart';
import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/goal_service.dart';
import 'package:ahorro_app/services/recurring_expense_service.dart';
import 'package:ahorro_app/services/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderService.buildReminders', () {
    late String accountId;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final accountService = AccountService();
      await accountService.loadAccounts();
      accountId = accountService.activeAccountId;
      await RecurringExpenseService().loadRecurringExpenses();
      await GoalService().loadGoals();
    });

    test(
      'un gasto recurrente diario aparece como recordatorio de mañana',
      () async {
        await RecurringExpenseService().addRecurringExpense(
          RecurringExpense(
            id: 'rec_daily',
            name: 'Suscripción diaria',
            description: '',
            amount: 5,
            category: ExpenseCategory.entertainment,
            frequency: RecurrenceFrequency.daily,
            startDate: DateTime.now().subtract(const Duration(days: 365)),
            createdAt: DateTime.now(),
            accountId: accountId,
          ),
        );

        final reminders = ReminderService().buildReminders();
        final match = reminders.where((r) => r.referenceId == 'rec_daily');

        expect(match.length, 1);
        expect(match.first.type, ReminderType.recurringExpense);
        expect(match.first.urgency, ReminderUrgency.tomorrow);
      },
    );

    test(
      'un gasto recurrente fuera de la ventana de 3 días no genera recordatorio',
      () async {
        await RecurringExpenseService().addRecurringExpense(
          RecurringExpense(
            id: 'rec_far',
            name: 'Pago cada 30 días',
            description: '',
            amount: 5,
            category: ExpenseCategory.other,
            frequency: RecurrenceFrequency.custom,
            customDays: 30,
            startDate: DateTime.now(),
            createdAt: DateTime.now(),
            accountId: accountId,
          ),
        );

        final reminders = ReminderService().buildReminders();
        expect(reminders.where((r) => r.referenceId == 'rec_far'), isEmpty);
      },
    );

    test('un gasto recurrente inactivo no genera recordatorio', () async {
      await RecurringExpenseService().addRecurringExpense(
        RecurringExpense(
          id: 'rec_inactive',
          name: 'Gasto pausado',
          description: '',
          amount: 5,
          category: ExpenseCategory.other,
          frequency: RecurrenceFrequency.daily,
          startDate: DateTime.now().subtract(const Duration(days: 10)),
          createdAt: DateTime.now(),
          accountId: accountId,
          isActive: false,
        ),
      );

      final reminders = ReminderService().buildReminders();
      expect(reminders.where((r) => r.referenceId == 'rec_inactive'), isEmpty);
    });

    test(
      'una meta con fecha límite próxima genera un recordatorio de vencimiento',
      () async {
        await GoalService().addGoal(
          FinancialGoal(
            name: 'Meta próxima a vencer',
            description: '',
            targetAmount: 1000,
            currentAmount: 100,
            startDate: DateTime.now().subtract(const Duration(days: 10)),
            targetDate: DateTime.now().add(const Duration(days: 5)),
            type: GoalType.savings,
            createdAt: DateTime.now(),
            accountId: accountId,
          ),
        );

        final reminders = ReminderService().buildReminders();
        final match = reminders.where(
          (r) =>
              r.type == ReminderType.goalDeadline &&
              r.title == 'Meta próxima a vencer',
        );
        expect(match.length, 1);
      },
    );

    test(
      'una meta vencida no genera recordatorio (ya la cubre la alerta del dashboard)',
      () async {
        await GoalService().addGoal(
          FinancialGoal(
            name: 'Meta ya vencida',
            description: '',
            targetAmount: 1000,
            currentAmount: 100,
            startDate: DateTime.now().subtract(const Duration(days: 60)),
            targetDate: DateTime.now().subtract(const Duration(days: 1)),
            type: GoalType.savings,
            createdAt: DateTime.now(),
            accountId: accountId,
          ),
        );

        final reminders = ReminderService().buildReminders();
        expect(reminders.where((r) => r.title == 'Meta ya vencida'), isEmpty);
      },
    );

    test('una meta completada no genera recordatorio', () async {
      await GoalService().addGoal(
        FinancialGoal(
          name: 'Meta completada',
          description: '',
          targetAmount: 500,
          currentAmount: 500,
          startDate: DateTime.now().subtract(const Duration(days: 30)),
          targetDate: DateTime.now().add(const Duration(days: 2)),
          type: GoalType.savings,
          createdAt: DateTime.now(),
          accountId: accountId,
        ),
      );

      final reminders = ReminderService().buildReminders();
      expect(reminders.where((r) => r.title == 'Meta completada'), isEmpty);
    });

    test(
      'una meta atrasada de ritmo (pero con fecha lejana) genera un recordatorio',
      () async {
        await GoalService().addGoal(
          FinancialGoal(
            name: 'Meta atrasada',
            description: '',
            targetAmount: 1200,
            currentAmount: 0, // 0% de progreso muy avanzado el período
            startDate: DateTime.now().subtract(const Duration(days: 60)),
            targetDate: DateTime.now().add(const Duration(days: 60)),
            type: GoalType.savings,
            createdAt: DateTime.now(),
            accountId: accountId,
          ),
        );

        final reminders = ReminderService().buildReminders();
        final match = reminders.where(
          (r) =>
              r.type == ReminderType.goalOffTrack && r.title == 'Meta atrasada',
        );
        expect(match.length, 1);
      },
    );

    test('una meta al día y con fecha lejana no genera recordatorio', () async {
      await GoalService().addGoal(
        FinancialGoal(
          name: 'Meta al día',
          description: '',
          targetAmount: 1000,
          currentAmount: 900, // muy por delante del ritmo esperado
          startDate: DateTime.now().subtract(const Duration(days: 10)),
          targetDate: DateTime.now().add(const Duration(days: 50)),
          type: GoalType.savings,
          createdAt: DateTime.now(),
          accountId: accountId,
        ),
      );

      final reminders = ReminderService().buildReminders();
      expect(reminders.where((r) => r.title == 'Meta al día'), isEmpty);
    });

    test(
      'los recordatorios se ordenan por urgencia y luego por fecha',
      () async {
        final reminders = ReminderService().buildReminders();
        for (var i = 1; i < reminders.length; i++) {
          final prev = reminders[i - 1];
          final curr = reminders[i];
          final urgencyOk = prev.urgency.index <= curr.urgency.index;
          expect(urgencyOk, true);
          if (prev.urgency == curr.urgency) {
            expect(prev.dueDate.isAfter(curr.dueDate), false);
          }
        }
      },
    );
  });
}
