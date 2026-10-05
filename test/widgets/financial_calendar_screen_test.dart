import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/screens/add_transaction_screen.dart';
import 'package:ahorro_app/screens/financial_calendar_screen.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/category_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';
import 'package:ahorro_app/widgets/calendar/calendar_day_cell.dart';
import 'package:ahorro_app/widgets/calendar/calendar_day_sheet.dart';

import '../support/load_roboto.dart';

/// El calendario COMPLETO (Historial > calendario) abre el mismo panel del
/// día que la tarjeta de Inicio: agregar, editar y eliminar desde ahí.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String accountId;
  final transactions = TransactionService();

  var counter = 0;
  Transaction expenseOn(DateTime day, {String description = 'Almuerzo'}) {
    counter++;
    return Transaction(
      id: 'fc_$counter',
      amount: 12.5,
      type: TransactionType.expense,
      description: description,
      date: DateTime(day.year, day.month, day.day, 12),
      expenseCategory: ExpenseCategory.food,
      accountId: accountId,
    );
  }

  Future<void> pumpCalendar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(392 * 2, 2200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: FinancialCalendarScreen()));
    await tester.pumpAndSettle(const Duration(seconds: 3));
  }

  Finder cell(int day) =>
      find.byWidgetPredicate((w) => w is CalendarDayCell && w.dayNumber == day);

  setUpAll(() async {
    expect(
      await loadRoboto(),
      isTrue,
      reason: 'No se encontró Roboto en el SDK',
    );
    SharedPreferences.setMockInitialValues({});
    await AccountService().loadAccounts();
    accountId = AccountService().activeAccountId;
    await CategoryService().loadCategories();
  });

  setUp(() async {
    await transactions.clearAllTransactions();
  });

  // Hoy siempre existe en el mes visible; se usa un día "pasado o de hoy" que
  // exista sin depender de la fecha en que se corra la prueba.
  testWidgets('hoy: el panel ofrece agregar un ingreso o un gasto', (
    tester,
  ) async {
    final today = DateTime.now();
    await pumpCalendar(tester);

    await tester.tap(cell(today.day));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDaySheet), findsOneWidget);
    expect(find.text('Ingreso'), findsOneWidget);
    expect(find.text('Gasto'), findsOneWidget);

    await tester.tap(find.text('Gasto'));
    await tester.pumpAndSettle();
    final form = tester.widget<AddTransactionScreen>(
      find.byType(AddTransactionScreen),
    );
    expect(form.initialType, TransactionType.expense);
    expect(form.initialDate?.day, today.day);
  });

  testWidgets('hoy con un movimiento: tocarlo permite editar o eliminar', (
    tester,
  ) async {
    final today = DateTime.now();
    final tx = expenseOn(today);
    await transactions.addTransaction(tx);
    await pumpCalendar(tester);

    await tester.tap(cell(today.day));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Almuerzo'));
    await tester.pumpAndSettle();

    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar')); // confirmar
    await tester.pumpAndSettle();

    expect(transactions.allTransactions, isEmpty);
    expect(find.byType(CalendarDaySheet), findsOneWidget);
    expect(find.text('Sin movimientos este día'), findsOneWidget);
    expect(find.text('Ingreso'), findsOneWidget);
  });
}
