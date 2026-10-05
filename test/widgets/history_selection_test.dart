import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/account.dart';
import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/screens/history_screen.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/category_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';

import '../support/load_roboto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String accountId;
  final transactions = TransactionService();

  var counter = 0;
  Transaction tx(
    String description,
    double amount, {
    TransactionType type = TransactionType.expense,
  }) {
    counter++;
    return Transaction(
      id: 'h_$counter',
      amount: amount,
      type: type,
      description: description,
      date: DateTime.now(),
      expenseCategory: type == TransactionType.expense
          ? ExpenseCategory.food
          : null,
      incomeCategory: type == TransactionType.income
          ? IncomeCategory.salary
          : null,
      accountId: accountId,
    );
  }

  Future<void> seedFour() async {
    await transactions.addTransaction(tx('Café', 3.5));
    await transactions.addTransaction(tx('Taxi', 8));
    await transactions.addTransaction(tx('Cine', 12));
    await transactions.addTransaction(
      tx('Sueldo', 900, type: TransactionType.income),
    );
  }

  // Pantalla alta (para que la lista perezosa construya todas las filas) y de
  // ancho configurable (320 dp = el peor caso para los desbordes).
  Future<void> pumpHistory(WidgetTester tester, {double width = 360}) async {
    tester.view.physicalSize = Size(width * 2, 4800);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HistoryScreen()));
    await tester.pumpAndSettle(const Duration(seconds: 3));
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

  group('Servicio: borrar por IDs', () {
    test('solo elimina los IDs pedidos', () async {
      await seedFour();
      final ids = transactions.transactions
          .where((t) => t.description == 'Café' || t.description == 'Taxi')
          .map((t) => t.id)
          .toList();

      await transactions.deleteTransactionsByIds(ids);

      expect(transactions.allTransactions.map((t) => t.description).toSet(), {
        'Cine',
        'Sueldo',
      });
    });

    test(
      'borrar una pata de una transferencia borra también su pareja',
      () async {
        final other = await AccountService().addAccount(
          name: 'Ahorros',
          type: AccountType.savings,
        );
        await transactions.createTransfer(
          fromAccountId: accountId,
          toAccountId: other.id,
          amount: 25,
          date: DateTime.now(),
        );
        await transactions.addTransaction(tx('Café', 3.5));
        expect(
          transactions.allTransactions.where((t) => t.isTransfer),
          hasLength(2),
        );

        // Solo se pide el ID de la pata de la cuenta activa...
        final outLeg = transactions.allTransactions.firstWhere(
          (t) => t.isTransfer && t.accountId == accountId,
        );
        await transactions.deleteTransactionsByIds([outLeg.id]);

        // ...y la otra mitad (en la otra cuenta) no queda huérfana.
        expect(
          transactions.allTransactions.where((t) => t.isTransfer),
          isEmpty,
        );
        expect(transactions.allTransactions.single.description, 'Café');
      },
    );
  });

  group('Historial: tocar, mantener presionado y seleccionar', () {
    testWidgets('ya no se puede deslizar: no hay Dismissible', (tester) async {
      await seedFour();
      await pumpHistory(tester);

      expect(find.text('Taxi'), findsOneWidget);
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('tocar una transacción abre Editar / Eliminar', (tester) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.tap(find.text('Taxi'));
      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('eliminar desde el menú actualiza la lista', (tester) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.tap(find.text('Taxi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar')); // confirmar en el diálogo
      await tester.pumpAndSettle();

      expect(find.text('Taxi'), findsNothing);
      expect(find.text('Café'), findsOneWidget);
      expect(transactions.allTransactions, hasLength(3));
    });

    testWidgets('mantener presionado inicia la selección con esa fila', (
      tester,
    ) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.longPress(find.text('Taxi'));
      await tester.pumpAndSettle();

      expect(find.text('1 seleccionada'), findsOneWidget);
      // No se abrió el menú de acciones.
      expect(find.text('Editar'), findsNothing);
      // Las acciones de selección reemplazan a las normales.
      expect(find.byTooltip('Cancelar selección'), findsOneWidget);
      expect(find.byTooltip('Seleccionar todas'), findsOneWidget);
      expect(find.byTooltip('Eliminar seleccionadas'), findsOneWidget);
      expect(find.byTooltip('Eliminar todas'), findsNothing);
    });

    testWidgets('en modo selección, tocar marca y desmarca (no abre el menú)', (
      tester,
    ) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.longPress(find.text('Taxi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cine'));
      await tester.pumpAndSettle();
      expect(find.text('2 seleccionadas'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);

      await tester.tap(find.text('Cine'));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionada'), findsOneWidget);
    });

    testWidgets('desmarcar la última cierra el modo selección', (tester) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.longPress(find.text('Taxi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taxi'));
      await tester.pumpAndSettle();

      expect(find.text('Historial'), findsOneWidget);
      expect(find.byTooltip('Eliminar todas'), findsOneWidget);
    });

    testWidgets('el botón Seleccionar entra al modo sin elegir ninguna', (
      tester,
    ) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();

      expect(find.text('Selecciona'), findsOneWidget);
      // Sin selección no se puede eliminar todavía.
      await tester.tap(find.byTooltip('Eliminar seleccionadas'));
      await tester.pumpAndSettle();
      expect(find.textContaining('¿Eliminar'), findsNothing);

      await tester.tap(find.text('Café'));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionada'), findsOneWidget);
    });

    testWidgets('Seleccionar todas / Quitar selección', (tester) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleccionar todas'));
      await tester.pumpAndSettle();
      expect(find.text('4 seleccionadas'), findsOneWidget);
      expect(find.text('Quitar selección'), findsOneWidget);

      await tester.tap(find.text('Quitar selección'));
      await tester.pumpAndSettle();
      expect(find.text('Selecciona'), findsOneWidget);
    });

    testWidgets('cancelar (X) sale del modo y limpia la selección', (
      tester,
    ) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.longPress(find.text('Taxi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cancelar selección'));
      await tester.pumpAndSettle();

      expect(find.text('Historial'), findsOneWidget);
      expect(transactions.allTransactions, hasLength(4));
    });

    testWidgets('el botón Atrás cierra primero el modo selección', (
      tester,
    ) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.longPress(find.text('Taxi'));
      await tester.pumpAndSettle();
      expect(find.text('1 seleccionada'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Historial'), findsOneWidget);
      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('cambiar el filtro desmarca lo que deja de estar visible', (
      tester,
    ) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.longPress(find.text('Taxi')); // gasto
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sueldo')); // ingreso
      await tester.pumpAndSettle();
      expect(find.text('2 seleccionadas'), findsOneWidget);

      await tester.tap(find.text('Gastos')); // chip de filtro
      await tester.pumpAndSettle();

      // El ingreso ya no se ve, así que ya no está seleccionado.
      expect(find.text('Sueldo'), findsNothing);
      expect(find.text('1 seleccionada'), findsOneWidget);
    });
  });

  group('Historial: eliminar varias', () {
    testWidgets('selección parcial: confirmación simple con la cantidad', (
      tester,
    ) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.longPress(find.text('Taxi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cine'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Eliminar seleccionadas'));
      await tester.pumpAndSettle();

      expect(find.text('¿Eliminar 2 transacciones?'), findsOneWidget);
      // Todavía no se borró nada.
      expect(transactions.allTransactions, hasLength(4));

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(transactions.allTransactions.map((t) => t.description).toSet(), {
        'Café',
        'Sueldo',
      });
      expect(find.text('2 transacciones eliminadas'), findsOneWidget);
      // Sale del modo selección y la lista se refresca.
      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Taxi'), findsNothing);
      expect(find.text('Café'), findsOneWidget);
    });

    testWidgets('cancelar la confirmación conserva todo (y la selección)', (
      tester,
    ) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.longPress(find.text('Taxi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Eliminar seleccionadas'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar transacción?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(transactions.allTransactions, hasLength(4));
      expect(find.text('1 seleccionada'), findsOneWidget);
    });

    testWidgets(
      'seleccionar TODAS usa la misma doble confirmación de "Eliminar todas"',
      (tester) async {
        await seedFour();
        await pumpHistory(tester);

        await tester.tap(find.text('Seleccionar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Seleccionar todas'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Eliminar seleccionadas'));
        await tester.pumpAndSettle();

        // Paso 1: aviso.
        expect(
          find.text('¿Eliminar transacciones de esta cuenta?'),
          findsOneWidget,
        );
        expect(find.textContaining('las 4 transacciones'), findsOneWidget);
        await tester.tap(find.text('Continuar'));
        await tester.pumpAndSettle();

        // Paso 2: escribir ELIMINAR. Sin escribirlo el botón está deshabilitado.
        expect(find.text('Confirmación Final'), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Eliminar Todo'),
              )
              .onPressed,
          isNull,
        );
        await tester.enterText(find.byType(TextField).last, 'ELIMINAR');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar Todo'));
        await tester.pumpAndSettle();

        expect(transactions.allTransactions, isEmpty);
        expect(
          find.text('Todas las transacciones han sido eliminadas'),
          findsOneWidget,
        );
        expect(find.text('Historial'), findsOneWidget);
      },
    );

    testWidgets('el botón "Eliminar todas" del encabezado conserva su flujo', (
      tester,
    ) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.tap(find.byTooltip('Eliminar todas'));
      await tester.pumpAndSettle();
      expect(
        find.text('¿Eliminar transacciones de esta cuenta?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'eliminar');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar Todo'));
      await tester.pumpAndSettle();

      expect(transactions.allTransactions, isEmpty);
    });

    testWidgets('con filtro activo, "todas" son solo las visibles', (
      tester,
    ) async {
      await seedFour();
      await pumpHistory(tester);

      await tester.tap(find.text('Gastos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleccionar todas'));
      await tester.pumpAndSettle();
      expect(find.text('3 seleccionadas'), findsOneWidget);

      await tester.tap(find.byTooltip('Eliminar seleccionadas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'ELIMINAR');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar Todo'));
      await tester.pumpAndSettle();

      // El ingreso, que no estaba visible, sobrevive.
      expect(transactions.allTransactions.map((t) => t.description), [
        'Sueldo',
      ]);
    });

    testWidgets(
      'al borrar una transferencia seleccionada se avisa y se borran ambas patas',
      (tester) async {
        final other = await AccountService().addAccount(
          name: 'Ahorros 2',
          type: AccountType.savings,
        );
        await transactions.createTransfer(
          fromAccountId: accountId,
          toAccountId: other.id,
          amount: 40,
          date: DateTime.now(),
        );
        await transactions.addTransaction(tx('Café', 3.5));
        await transactions.addTransaction(tx('Taxi', 8));
        await pumpHistory(tester);

        await tester.longPress(find.text('Transferencia entre cuentas'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Eliminar seleccionadas'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Las transferencias se eliminan completas'),
          findsOneWidget,
        );
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();

        expect(
          transactions.allTransactions.where((t) => t.isTransfer),
          isEmpty,
        );
        expect(transactions.allTransactions, hasLength(2));
      },
    );
  });

  group('Historial: sin desbordes', () {
    testWidgets('modo normal y selección a 320 dp con montos enormes', (
      tester,
    ) async {
      await transactions.addTransaction(
        tx('Compra gigante con un nombre bastante largo', 20000032.45),
      );
      await transactions.addTransaction(
        tx('Sueldo', 1000000, type: TransactionType.income),
      );
      await pumpHistory(tester, width: 320);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Seleccionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seleccionar todas'));
      await tester.pumpAndSettle();

      expect(find.text('2 seleccionadas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
