import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/budget.dart';
import 'package:ahorro_app/models/financial_goal.dart';
import 'package:ahorro_app/models/recurring_expense.dart';
import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/screens/add_recurring_expense_screen.dart';
import 'package:ahorro_app/screens/add_transaction_screen.dart';
import 'package:ahorro_app/screens/budget_screen.dart';
import 'package:ahorro_app/screens/create_goal_screen.dart';
import 'package:ahorro_app/screens/goals_screen.dart';
import 'package:ahorro_app/screens/history_screen.dart';
import 'package:ahorro_app/screens/main_navigation_screen.dart';
import 'package:ahorro_app/screens/manage_categories_screen.dart';
import 'package:ahorro_app/screens/recurring_expenses_screen.dart';
import 'package:ahorro_app/screens/settings_screen.dart';
import 'package:ahorro_app/screens/tab_add_action.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/budget_service.dart';
import 'package:ahorro_app/services/category_service.dart';
import 'package:ahorro_app/services/goal_service.dart';
import 'package:ahorro_app/services/recurring_expense_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';
import 'package:ahorro_app/widgets/budget_alert_listener.dart';
import 'package:ahorro_app/widgets/common/common.dart';

import '../support/load_roboto.dart';

/// Pruebas de interfaz de la auditoría: barra de selección fija en el
/// historial, botón "Agregar" en pantallas abiertas desde el menú, aportes con
/// coma decimal, edición de un aporte y porcentaje de presupuesto excedido.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final accounts = AccountService();
  final transactions = TransactionService();
  final goals = GoalService();
  final recurring = RecurringExpenseService();

  var seq = 0;
  Transaction expense(String description, double amount, {DateTime? date}) {
    seq++;
    return Transaction(
      id: 'ui_$seq',
      amount: amount,
      type: TransactionType.expense,
      description: description,
      date: date ?? DateTime.now(),
      expenseCategory: ExpenseCategory.food,
      accountId: accounts.activeAccountId,
    );
  }

  /// Opacidad con la que realmente se pinta [finder] (producto de las
  /// opacidades de sus ancestros). Un botón con opacidad 0 se puede tocar en
  /// una prueba, pero el usuario no lo ve.
  double effectiveOpacity(WidgetTester tester, Finder finder) {
    var opacity = 1.0;
    RenderObject? node = tester.renderObject(finder);
    while (node != null) {
      if (node is RenderOpacity) opacity *= node.opacity;
      if (node is RenderAnimatedOpacity) opacity *= node.opacity.value;
      node = node.parent;
    }
    return opacity;
  }

  void usePhone(WidgetTester tester, {double width = 360, double height = 780}) {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Abre [screen] como pantalla suelta (como desde el menú lateral).
  Future<void> pushStandalone(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => screen),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

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

  RecurringExpense daily(String id) {
    final now = DateTime.now();
    return RecurringExpense(
      id: id,
      name: 'Gasto $id',
      description: 'desc',
      amount: 5,
      category: ExpenseCategory.transport,
      frequency: RecurrenceFrequency.daily,
      startDate: DateTime(now.year, now.month, now.day + 1),
      createdAt: now,
      accountId: accounts.activeAccountId,
    );
  }

  setUpAll(() async {
    expect(await loadRoboto(), isTrue, reason: 'No se encontró Roboto');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await goals.loadGoals();
    await accounts.loadAccounts();
    await transactions.loadTransactions();
    await CategoryService().loadCategories();
    await BudgetService().loadBudgets();
    await recurring.loadRecurringExpenses();
  });

  group('Historial: barra de selección fija', () {
    testWidgets(
      'las acciones siguen visibles y funcionan después de hacer scroll',
      (tester) async {
        for (var i = 1; i <= 30; i++) {
          await transactions.addTransaction(expense('Gasto $i', i.toDouble()));
        }
        usePhone(tester);
        await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
        await tester.pumpAndSettle(const Duration(seconds: 3));

        await tester.scrollUntilVisible(
          find.text('Seleccionar'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Seleccionar'));
        await tester.pumpAndSettle();

        // Bien abajo en la lista.
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -2500),
        );
        await tester.pumpAndSettle();

        final row = find.textContaining('Gasto ').hitTestable().first;
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.text('1 seleccionada'), findsOneWidget);

        // La barra está arriba, visible y se puede tocar sin volver arriba.
        for (final tooltip in [
          'Cancelar selección',
          'Seleccionar todas',
          'Eliminar seleccionadas',
        ]) {
          final button = find.byTooltip(tooltip);
          expect(button.hitTestable(), findsOneWidget, reason: tooltip);
          expect(tester.getRect(button).top, greaterThanOrEqualTo(0));
          expect(tester.getRect(button).top, lessThan(120), reason: tooltip);
          // Visible de verdad (antes quedaban con opacidad 0 al colapsar).
          expect(
            effectiveOpacity(tester, button),
            greaterThan(0.9),
            reason: tooltip,
          );
        }

        await tester.tap(find.byTooltip('Seleccionar todas'));
        await tester.pumpAndSettle();
        expect(find.text('30 seleccionadas'), findsOneWidget);

        await tester.tap(find.byTooltip('Quitar selección'));
        await tester.pumpAndSettle();
        // Quitar todo cierra la barra de selección.
        await tester.tap(find.textContaining('Gasto ').hitTestable().first);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Eliminar seleccionadas'));
        await tester.pumpAndSettle();
        expect(find.text('¿Eliminar transacción?'), findsOneWidget);
        await tester.tap(find.text('Eliminar').last);
        await tester.pumpAndSettle();

        expect(transactions.transactions, hasLength(29));
        expect(find.byTooltip('Eliminar seleccionadas'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('un movimiento agregado desde otra pantalla aparece solo', (
      tester,
    ) async {
      await transactions.addTransaction(expense('Primero', 10));
      usePhone(tester, height: 2400);
      await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Primero'), findsOneWidget);

      // Como el botón "Agregar" o un gasto automático, sin tocar el historial.
      await transactions.addTransaction(expense('Nuevo desde Inicio', 25));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo desde Inicio'), findsOneWidget);
      expect(find.text('2 transacciones encontradas'), findsOneWidget);
    });

    testWidgets('abierto desde Inicio tiene flecha de volver', (tester) async {
      usePhone(tester);
      await pushStandalone(tester, const HistoryScreen());
      expect(find.byType(AppBackButton), findsOneWidget);
      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsNothing);
    });
  });

  group('Gastos recurrentes desde el menú lateral', () {
    for (final count in [0, 1, 3]) {
      testWidgets('con $count gasto(s) el botón Agregar está y funciona', (
        tester,
      ) async {
        for (var i = 0; i < count; i++) {
          await recurring.addRecurringExpense(daily('r$i'));
        }
        usePhone(tester);
        await pushStandalone(tester, const RecurringExpensesScreen());

        final fab = find.widgetWithText(FloatingActionButton, 'Agregar');
        expect(fab, findsOneWidget);
        expect(find.byType(AppBackButton), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(fab);
        await tester.pumpAndSettle(const Duration(seconds: 3));
        expect(find.byType(AddRecurringExpenseScreen), findsOneWidget);
      });
    }

    testWidgets('dentro de las pestañas no duplica el botón global', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(
        const MaterialApp(home: TabHostScope(child: RecurringExpensesScreen())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byType(AppBackButton), findsNothing);
    });
  });

  group('Metas', () {
    testWidgets('desde un recordatorio también tiene botón Agregar', (
      tester,
    ) async {
      usePhone(tester);
      await pushStandalone(tester, const GoalsScreen());
      final fab = find.widgetWithText(FloatingActionButton, 'Agregar');
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(CreateGoalScreen), findsOneWidget);
    });

    testWidgets('aportar "10,50" guarda 10,50 (no 1050)', (tester) async {
      final goal = await createGoal();
      usePhone(tester, height: 2400);
      await tester.pumpWidget(
        const MaterialApp(home: TabHostScope(child: GoalsScreen())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('Aportar').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '10,50');
      await tester.pump();
      expect(find.text('10.50'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Aportar'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(goals.getGoalById(goal.id!)!.currentAmount, 10.5);
      expect(transactions.transactions.single.amount, 10.5);
    });

    testWidgets('aportar sin monto avisa en vez de no hacer nada', (
      tester,
    ) async {
      await createGoal();
      usePhone(tester, height: 2400);
      await tester.pumpWidget(
        const MaterialApp(home: TabHostScope(child: GoalsScreen())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.text('Aportar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Aportar'));
      await tester.pumpAndSettle();
      expect(find.text('Ingresa un monto mayor a 0'), findsOneWidget);
      expect(transactions.transactions, isEmpty);
    });

    testWidgets('una meta alcanzada sigue visible en "Metas Completadas"', (
      tester,
    ) async {
      final goal = await createGoal(target: 100);
      await goals.addContribution(goal.id!, 100);
      usePhone(tester, height: 2400);
      await tester.pumpWidget(
        const MaterialApp(home: TabHostScope(child: GoalsScreen())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Metas Completadas (1)'), findsOneWidget);
      expect(find.text('Moto'), findsOneWidget);
      // En una meta completada no hay "Aportar" ni "Pausar/Reanudar".
      expect(find.text('Reanudar'), findsNothing);
      expect(find.text('Editar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'editar un aporte avisa que es de una meta y no deja cambiar el tipo',
      (tester) async {
        final goal = await createGoal();
        await goals.addContribution(goal.id!, 100);
        final contribution = transactions.transactions.single;

        usePhone(tester, height: 2400);
        await tester.pumpWidget(
          MaterialApp(
            home: AddTransactionScreen(
              initialType: TransactionType.expense,
              transactionToEdit: contribution,
            ),
          ),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(find.textContaining('Aporte a la meta "Moto"'), findsOneWidget);
        await tester.tap(find.text('Ingreso'));
        await tester.pump();
        expect(find.text('Editar Gasto'), findsOneWidget);
        expect(find.textContaining('no se puede cambiar su tipo'), findsOneWidget);
      },
    );
  });

  group('Menú lateral de Inicio', () {
    Future<void> openDrawer(WidgetTester tester) async {
      usePhone(tester);
      await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      await tester.tap(find.byIcon(Icons.menu_rounded).first);
      await tester.pumpAndSettle();
    }

    testWidgets('la última opción no queda tapada por el botón Agregar', (
      tester,
    ) async {
      await openDrawer(tester);
      final drawerList = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.drag(drawerList, const Offset(0, -2000));
      await tester.pumpAndSettle();

      final settings = find.text('Configuración');
      final fabRect = tester.getRect(find.byType(FloatingActionButton));
      // Todo el menú (hasta la versión, al final) se puede subir por encima
      // del botón; antes la versión quedaba siempre debajo de él.
      expect(
        tester.getRect(find.text('Versión 1.0.0')).bottom,
        lessThanOrEqualTo(fabRect.top),
      );
      expect(
        tester.getRect(settings).bottom,
        lessThan(fabRect.top - 16),
        reason: 'Configuración debe quedar holgadamente sobre el botón',
      );
      await tester.tap(settings);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('"Categorías de gastos" abre las categorías', (tester) async {
      await openDrawer(tester);
      await tester.tap(find.text('Categorías de gastos'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(ManageCategoriesScreen), findsOneWidget);
    });
  });

  group('Alerta del presupuesto', () {
    Future<void> createFoodBudget() async {
      final dates = BudgetService.generateBudgetDates(
        BudgetPeriod.monthly,
        DateTime.now(),
      );
      await BudgetService().addBudget(
        Budget(
          name: 'Comida',
          amount: 100,
          period: BudgetPeriod.monthly,
          category: ExpenseCategory.food,
          startDate: dates['start']!,
          endDate: dates['end']!,
          alertThreshold: 0.8,
          createdAt: DateTime.now(),
          accountId: accounts.activeAccountId,
        ),
      );
    }

    testWidgets('el aviso aparece al cruzar el porcentaje', (tester) async {
      await createFoodBudget();
      usePhone(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: BudgetAlertListener(child: Scaffold(body: SizedBox())),
        ),
      );

      await transactions.addTransaction(expense('Súper', 85));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Alerta de presupuesto'), findsOneWidget);
      expect(find.textContaining('ya usaste el 85 %'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'guardando desde el formulario el aviso sigue visible al volver',
      (tester) async {
        await createFoodBudget();
        usePhone(tester, height: 2400);
        await tester.pumpWidget(
          MaterialApp(
            home: BudgetAlertListener(
              child: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddTransactionScreen(
                            initialType: TransactionType.expense,
                          ),
                        ),
                      ),
                      child: const Text('nuevo'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('nuevo'));
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await tester.enterText(find.byType(TextFormField).first, '120');
        await tester.enterText(find.byType(TextFormField).at(1), 'Mercado');
        await tester.tap(find.text('Alimentación').first);
        await tester.pump();
        await tester.tap(find.text('Agregar Gasto').last);
        // Animación de éxito y regreso.
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(AddTransactionScreen), findsNothing);
        expect(find.text('Presupuesto excedido'), findsOneWidget);
        expect(find.textContaining('Te pasaste por 20,00'), findsOneWidget);
      },
    );

    testWidgets('la tarjeta indica que se llegó a la alerta', (tester) async {
      await createFoodBudget();
      await transactions.addTransaction(expense('Súper', 85));
      usePhone(tester, height: 2400);
      await tester.pumpWidget(
        const MaterialApp(home: TabHostScope(child: BudgetsScreen())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Alerta: ya usaste el 85% (aviso al 80%)'), findsOneWidget);

      // Por debajo de la alerta, la nota desaparece.
      await transactions.updateTransaction(
        transactions.transactions.single.copyWith(amount: 40),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Alerta: ya usaste'), findsNothing);
    });
  });

  group('Presupuestos', () {
    testWidgets('un presupuesto excedido muestra el porcentaje real (150 %)', (
      tester,
    ) async {
      final dates = BudgetService.generateBudgetDates(
        BudgetPeriod.monthly,
        DateTime.now(),
      );
      await BudgetService().addBudget(
        Budget(
          name: 'Comida',
          amount: 500,
          period: BudgetPeriod.monthly,
          category: ExpenseCategory.food,
          startDate: dates['start']!,
          endDate: dates['end']!,
          createdAt: DateTime.now(),
          accountId: accounts.activeAccountId,
        ),
      );
      await transactions.addTransaction(expense('Súper', 750));

      usePhone(tester, height: 2400);
      await tester.pumpWidget(
        const MaterialApp(home: TabHostScope(child: BudgetsScreen())),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('150%'), findsOneWidget);
      expect(find.text('Presupuesto excedido'), findsOneWidget);

      // Editar el gasto actualiza la tarjeta sin salir de la pantalla.
      await transactions.updateTransaction(
        transactions.transactions.single.copyWith(amount: 250),
      );
      await tester.pumpAndSettle();
      expect(find.text('50%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
