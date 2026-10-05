import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/screens/add_transaction_screen.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/category_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';
import 'package:ahorro_app/utils/format_utils.dart';
import 'package:ahorro_app/widgets/calendar/calendar_day_sheet.dart';

import '../support/load_roboto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String accountId;
  final transactions = TransactionService();

  // Fechas fijas para que las pruebas no dependan del día en que se corren.
  final pastDay = DateTime(2025, 3, 10);
  final tooOldDay = DateTime(2019, 12, 31);
  final futureDay = DateTime.now().add(const Duration(days: 40));

  var counter = 0;
  Transaction expenseOn(
    DateTime day, {
    String description = 'Almuerzo',
    double amount = 12.5,
    ExpenseCategory category = ExpenseCategory.food,
  }) {
    counter++;
    return Transaction(
      id: 'cal_$counter',
      amount: amount,
      type: TransactionType.expense,
      description: description,
      date: DateTime(day.year, day.month, day.day, 12),
      expenseCategory: category,
      accountId: accountId,
    );
  }

  Transaction incomeOn(
    DateTime day, {
    String description = 'Sueldo',
    double amount = 900,
  }) {
    counter++;
    return Transaction(
      id: 'cal_$counter',
      amount: amount,
      type: TransactionType.income,
      description: description,
      date: DateTime(day.year, day.month, day.day, 9),
      incomeCategory: IncomeCategory.salary,
      accountId: accountId,
    );
  }

  void usePhone(WidgetTester tester, {double width = 360}) {
    tester.view.physicalSize = Size(width * 2, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // 392 dp: ancho de un teléfono actual. (El formulario de ingreso, que algunas
  // pruebas abren, desborda 2 px a 360 dp por un problema anterior ajeno a esto.)
  Future<void> openDay(
    WidgetTester tester,
    DateTime day, {
    double width = 392,
  }) async {
    usePhone(tester, width: width);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CalendarDaySheet.show(context, date: day),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

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

  group('Día sin movimientos: permite agregar', () {
    testWidgets('en vez de solo avisar, ofrece agregar un ingreso o un gasto', (
      tester,
    ) async {
      await openDay(tester, pastDay);

      expect(find.text('Sin movimientos este día'), findsOneWidget);
      expect(
        find.text('Agrega un ingreso o un gasto en esta fecha.'),
        findsOneWidget,
      );
      expect(find.text('Ingreso'), findsOneWidget);
      expect(find.text('Gasto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Gasto" abre el formulario de gasto con la fecha del día', (
      tester,
    ) async {
      await openDay(tester, pastDay);

      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();

      final form = tester.widget<AddTransactionScreen>(
        find.byType(AddTransactionScreen),
      );
      expect(form.initialType, TransactionType.expense);
      expect(form.initialDate, pastDay);
      expect(form.transactionToEdit, isNull);
      // La fecha elegida ya está cargada en el formulario.
      expect(
        find.textContaining(FormatUtils.formatDateFull(pastDay)),
        findsWidgets,
      );
    });

    testWidgets(
      '"Ingreso" abre el formulario de ingreso con la fecha del día',
      (tester) async {
        await openDay(tester, pastDay);

        await tester.tap(find.text('Ingreso'));
        await tester.pumpAndSettle();

        final form = tester.widget<AddTransactionScreen>(
          find.byType(AddTransactionScreen),
        );
        expect(form.initialType, TransactionType.income);
        expect(form.initialDate, pastDay);
      },
    );

    testWidgets('al volver del formulario, el panel sigue abierto', (
      tester,
    ) async {
      await openDay(tester, pastDay);

      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(AddTransactionScreen))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(CalendarDaySheet), findsOneWidget);
      expect(find.text('Sin movimientos este día'), findsOneWidget);
    });

    testWidgets('un día futuro no ofrece agregar y explica por qué', (
      tester,
    ) async {
      await openDay(tester, futureDay);

      expect(find.text('Ingreso'), findsNothing);
      expect(find.text('Gasto'), findsNothing);
      expect(
        find.text('Aún no puedes registrar movimientos en una fecha futura.'),
        findsOneWidget,
      );
    });

    testWidgets('antes de 2020 tampoco (el formulario no acepta esa fecha)', (
      tester,
    ) async {
      await openDay(tester, tooOldDay);

      expect(find.text('Gasto'), findsNothing);
      expect(
        find.text('Solo se pueden registrar movimientos desde 2020.'),
        findsOneWidget,
      );
    });
  });

  group('Día con movimientos: agregar, editar y eliminar', () {
    testWidgets('lista los movimientos y mantiene los botones de agregar', (
      tester,
    ) async {
      await transactions.addTransaction(expenseOn(pastDay));
      await transactions.addTransaction(incomeOn(pastDay));
      await openDay(tester, pastDay);

      expect(find.text('Almuerzo'), findsOneWidget);
      expect(find.text('Sueldo'), findsOneWidget);
      expect(find.text('2 movimientos'), findsOneWidget);
      expect(
        find.text('Toca un movimiento para editarlo o eliminarlo'),
        findsOneWidget,
      );
      expect(find.text('Ingreso'), findsOneWidget);
      expect(find.text('Gasto'), findsOneWidget);
    });

    testWidgets('también se puede agregar a un día que ya tiene movimientos', (
      tester,
    ) async {
      await transactions.addTransaction(expenseOn(pastDay));
      await openDay(tester, pastDay);

      await tester.tap(find.text('Ingreso'));
      await tester.pumpAndSettle();

      final form = tester.widget<AddTransactionScreen>(
        find.byType(AddTransactionScreen),
      );
      expect(form.initialType, TransactionType.income);
      expect(form.initialDate, pastDay);
    });

    testWidgets(
      'tocar un movimiento abre Editar / Eliminar sin cerrar el panel',
      (tester) async {
        await transactions.addTransaction(expenseOn(pastDay));
        await openDay(tester, pastDay);

        await tester.tap(find.text('Almuerzo'));
        await tester.pumpAndSettle();

        expect(find.text('Editar'), findsOneWidget);
        expect(find.text('Eliminar'), findsOneWidget);
        // El panel del día sigue debajo.
        expect(find.byType(CalendarDaySheet), findsOneWidget);
      },
    );

    testWidgets('Editar abre el formulario con ese movimiento', (tester) async {
      final tx = expenseOn(pastDay);
      await transactions.addTransaction(tx);
      await openDay(tester, pastDay);

      await tester.tap(find.text('Almuerzo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      final form = tester.widget<AddTransactionScreen>(
        find.byType(AddTransactionScreen),
      );
      expect(form.transactionToEdit?.id, tx.id);
      expect(form.initialType, TransactionType.expense);
    });

    testWidgets('Eliminar quita el movimiento y el panel se actualiza solo', (
      tester,
    ) async {
      final keep = incomeOn(pastDay);
      final remove = expenseOn(pastDay);
      await transactions.addTransaction(keep);
      await transactions.addTransaction(remove);
      await openDay(tester, pastDay);

      await tester.tap(find.text('Almuerzo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar transacción?'), findsOneWidget);
      await tester.tap(find.text('Eliminar')); // confirmar
      await tester.pumpAndSettle();

      expect(transactions.allTransactions.map((t) => t.id), [keep.id]);
      // El panel sigue abierto y ya no muestra el eliminado.
      expect(find.byType(CalendarDaySheet), findsOneWidget);
      expect(find.text('Almuerzo'), findsNothing);
      expect(find.text('Sueldo'), findsOneWidget);
      expect(find.text('1 movimiento'), findsOneWidget);
    });

    testWidgets(
      'al eliminar el último movimiento aparece el estado vacío con agregar',
      (tester) async {
        await transactions.addTransaction(expenseOn(pastDay));
        await openDay(tester, pastDay);

        await tester.tap(find.text('Almuerzo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        expect(find.text('Sin movimientos este día'), findsOneWidget);
        expect(find.text('Ingreso'), findsOneWidget);
        expect(find.text('Gasto'), findsOneWidget);
      },
    );

    testWidgets('cancelar la confirmación no elimina nada', (tester) async {
      await transactions.addTransaction(expenseOn(pastDay));
      await openDay(tester, pastDay);

      await tester.tap(find.text('Almuerzo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(transactions.allTransactions, hasLength(1));
      expect(find.text('Almuerzo'), findsOneWidget);
    });

    testWidgets('se actualiza solo cuando llegan movimientos nuevos', (
      tester,
    ) async {
      await openDay(tester, pastDay);
      expect(find.text('Sin movimientos este día'), findsOneWidget);

      await transactions.addTransaction(
        expenseOn(pastDay, description: 'Cena'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cena'), findsOneWidget);
      expect(find.text('1 movimiento'), findsOneWidget);
      expect(find.text('Sin movimientos este día'), findsNothing);
    });
  });

  group('Formulario con fecha inicial', () {
    testWidgets('AddTransactionScreen arranca en la fecha pedida', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: AddTransactionScreen(
            initialType: TransactionType.expense,
            initialDate: pastDay,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(FormatUtils.formatDateFull(pastDay)),
        findsWidgets,
      );
    });

    testWidgets('sin fecha inicial usa hoy (comportamiento de siempre)', (
      tester,
    ) async {
      usePhone(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: AddTransactionScreen(initialType: TransactionType.expense),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(FormatUtils.formatDateFull(DateTime.now())),
        findsWidgets,
      );
    });
  });

  group('Sin desbordes', () {
    testWidgets('montos enormes y nombres largos a 320 dp', (tester) async {
      await transactions.addTransaction(
        expenseOn(
          pastDay,
          description:
              'Compra gigante con un nombre bastante largo para probar',
          amount: 20000032.45,
          category: ExpenseCategory.entertainment,
        ),
      );
      await transactions.addTransaction(incomeOn(pastDay, amount: 1000000));
      await openDay(tester, pastDay, width: 320);

      expect(tester.takeException(), isNull);
      expect(find.byType(CalendarDaySheet), findsOneWidget);
    });

    testWidgets('estado vacío a 320 dp', (tester) async {
      await openDay(tester, pastDay, width: 320);
      expect(tester.takeException(), isNull);
    });
  });
}
