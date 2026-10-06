import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/financial_goal.dart';
import 'package:ahorro_app/screens/add_transaction_screen.dart';
import 'package:ahorro_app/screens/goals_screen.dart';
import 'package:ahorro_app/screens/tab_add_action.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/budget_service.dart';
import 'package:ahorro_app/services/category_service.dart';
import 'package:ahorro_app/services/goal_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';
import 'package:ahorro_app/widgets/goal_contributions_sheet.dart';

import '../support/load_roboto.dart';

/// Editar y eliminar los aportes de una meta desde la pantalla de Metas.
/// Cada cambio debe dejar meta, historial y balance iguales.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final accounts = AccountService();
  final transactions = TransactionService();
  final goals = GoalService();

  Future<FinancialGoal> createGoal({double target = 1000}) async {
    final now = DateTime.now();
    await goals.addGoal(
      FinancialGoal(
        name: 'Moto',
        description: '',
        targetAmount: target,
        startDate: now,
        targetDate: DateTime(now.year + 1, now.month, now.day),
        type: GoalType.purchase,
        createdAt: now,
        accountId: accounts.activeAccountId,
      ),
    );
    return goals.goals.single;
  }

  Future<void> pumpGoals(WidgetTester tester, {double width = 360}) async {
    tester.view.physicalSize = Size(width * 2, 4800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: TabHostScope(child: GoalsScreen())),
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.textContaining('· Ver y editar'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalContributionsSheet), findsOneWidget);
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(GoalContributionsSheet), matching: finder);

  setUpAll(() async {
    expect(await loadRoboto(), isTrue, reason: 'No se encontró Roboto');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await goals.loadGoals();
    await accounts.loadAccounts();
    await accounts.updateInitialBalance(accounts.activeAccountId, 1000);
    await transactions.loadTransactions();
    await CategoryService().loadCategories();
    await BudgetService().loadBudgets();
  });

  testWidgets('la tarjeta muestra cuántos aportes hay y abre la lista', (
    tester,
  ) async {
    final goal = await createGoal();
    await goals.addContribution(goal.id!, 100);
    await goals.addContribution(goal.id!, 200, note: 'Bono');
    await pumpGoals(tester);

    expect(find.text('2 aportes · Ver y editar'), findsOneWidget);
    await openSheet(tester);

    expect(inSheet(find.text('Aportes a Moto')), findsOneWidget);
    expect(inSheet(find.text('+100,00 \$')), findsOneWidget);
    expect(inSheet(find.text('+200,00 \$')), findsOneWidget);
    expect(inSheet(find.text('Bono')), findsOneWidget);
    expect(inSheet(find.text('Aporte a Moto')), findsOneWidget);
    expect(inSheet(find.textContaining('Ahorrado 300,00')), findsOneWidget);
    expect(inSheet(find.text('30.0%')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin aportes no aparece el acceso', (tester) async {
    await createGoal();
    await pumpGoals(tester);
    expect(find.textContaining('Ver y editar'), findsNothing);
  });

  testWidgets(
    'editar un aporte desde la meta: 200 → 350 actualiza meta, historial y balance',
    (tester) async {
      final goal = await createGoal();
      await goals.addContribution(goal.id!, 100);
      await goals.addContribution(goal.id!, 200, note: 'Bono');
      await pumpGoals(tester);
      await openSheet(tester);

      await tester.tap(inSheet(find.text('Bono')));
      await tester.pumpAndSettle();
      // Mismas opciones que en el historial.
      // .last: la hoja de acciones está encima (la tarjeta también dice "Editar").
      await tester.tap(find.text('Editar').last);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(AddTransactionScreen), findsOneWidget);
      expect(find.textContaining('Aporte a la meta "Moto"'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '350');
      await tester.tap(find.text('Guardar cambios'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // De vuelta en la lista, ya actualizada.
      expect(find.byType(AddTransactionScreen), findsNothing);
      expect(inSheet(find.text('+350,00 \$')), findsOneWidget);
      expect(inSheet(find.text('+200,00 \$')), findsNothing);
      expect(inSheet(find.textContaining('Ahorrado 450,00')), findsOneWidget);
      expect(inSheet(find.text('45.0%')), findsOneWidget);

      expect(goals.getGoalById(goal.id!)!.currentAmount, 450);
      expect(
        transactions.transactions.map((t) => t.amount).toSet(),
        {100.0, 350.0},
      );
      expect(transactions.totalBalance, 550);
    },
  );

  testWidgets('eliminar un aporte desde la meta', (tester) async {
    final goal = await createGoal();
    await goals.addContribution(goal.id!, 100);
    await goals.addContribution(goal.id!, 200, note: 'Bono');
    await pumpGoals(tester);
    await openSheet(tester);

    await tester.tap(inSheet(find.text('Bono')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();
    // El diálogo avisa que se descuenta de la meta.
    expect(find.textContaining('también se descontará'), findsOneWidget);
    await tester.tap(find.text('Eliminar').last);
    await tester.pumpAndSettle();

    expect(inSheet(find.text('Bono')), findsNothing);
    expect(inSheet(find.textContaining('Ahorrado 100,00')), findsOneWidget);
    expect(goals.getGoalById(goal.id!)!.currentAmount, 100);
    expect(transactions.transactions, hasLength(1));
    expect(transactions.totalBalance, 900);
  });

  testWidgets('"Aportar" desde la lista abre el diálogo de aporte', (
    tester,
  ) async {
    final goal = await createGoal();
    await goals.addContribution(goal.id!, 100);
    await pumpGoals(tester);
    await openSheet(tester);

    await tester.tap(inSheet(find.text('Aportar')));
    await tester.pumpAndSettle();
    expect(find.byType(GoalContributionsSheet), findsNothing);
    expect(find.text('Aportar a Moto'), findsOneWidget);
  });

  testWidgets('aporte antiguo sin movimiento: corregir el monto y quitarlo', (
    tester,
  ) async {
    final now = DateTime.now();
    final legacyDate = DateTime(now.year, now.month, 1, 10);
    SharedPreferences.setMockInitialValues({
      'accounts': json.encode(accounts.accounts.map((a) => a.toJson()).toList()),
      'active_account_id': accounts.activeAccountId,
      'goal_contributions_linked_v1': true,
      'financial_goals': json.encode([
        FinancialGoal(
          id: 'g1',
          name: 'Moto',
          description: '',
          targetAmount: 1000,
          startDate: legacyDate,
          targetDate: DateTime(now.year + 1, now.month, 1),
          type: GoalType.purchase,
          createdAt: legacyDate,
          accountId: accounts.activeAccountId,
        ).toJson(),
      ]),
      'goal_contributions': json.encode([
        GoalContribution(
          id: 'old',
          goalId: 'g1',
          amount: 200,
          date: legacyDate,
          accountId: accounts.activeAccountId,
        ).toJson(),
      ]),
    });
    await accounts.loadAccounts();
    await transactions.loadTransactions();
    await goals.loadGoals();

    await pumpGoals(tester);
    await openSheet(tester);
    expect(
      inSheet(find.textContaining('Sin movimiento en el historial')),
      findsOneWidget,
    );

    await tester.tap(inSheet(find.text('Aporte')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '250,5');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(goals.getGoalById('g1')!.currentAmount, 250.5);
    expect(inSheet(find.textContaining('Ahorrado 250,50')), findsOneWidget);

    await tester.tap(inSheet(find.text('Aporte')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar de la meta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(goals.getGoalById('g1')!.currentAmount, 0);
    expect(goals.getGoalContributions('g1'), isEmpty);
    // No había transacción: el historial no cambia.
    expect(transactions.allTransactions, isEmpty);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('sin desbordes a ${width.toInt()} dp con montos enormes', (
      tester,
    ) async {
      final goal = await createGoal(target: 999999999);
      await goals.addContribution(goal.id!, 20000032.45);
      await goals.addContribution(goal.id!, 0.01, note: 'Un aporte con una nota bastante larga para ver');
      await pumpGoals(tester, width: width);
      expect(tester.takeException(), isNull);
      await openSheet(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
