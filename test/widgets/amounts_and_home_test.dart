import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/screens/charts_screen.dart';
import 'package:ahorro_app/screens/monthly_history_screen.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/category_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';
import 'package:ahorro_app/widgets/calendar/calendar_day_cell.dart';
import 'package:ahorro_app/widgets/calendar/calendar_month_grid.dart';
import 'package:ahorro_app/widgets/calendar/home_calendar_card.dart';
import 'package:ahorro_app/widgets/common/common.dart';
import 'package:ahorro_app/widgets/transaction_actions_sheet.dart';

import '../support/load_roboto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String accountId;
  final transactions = TransactionService();
  final categories = CategoryService();

  var counter = 0;
  Transaction expense(
    double amount, {
    String description = 'Gasto',
    ExpenseCategory? system,
    String? customId,
    String? customName,
    String? customEmoji,
    DateTime? date,
  }) {
    counter++;
    return Transaction(
      id: 'w_$counter',
      amount: amount,
      type: TransactionType.expense,
      description: description,
      date: date ?? DateTime.now(),
      expenseCategory: system,
      customCategoryId: customId,
      customCategoryName: customName,
      customCategoryEmoji: customEmoji,
      accountId: accountId,
    );
  }

  Transaction income(
    double amount, {
    String description = 'Ingreso',
    DateTime? date,
  }) {
    counter++;
    return Transaction(
      id: 'w_$counter',
      amount: amount,
      type: TransactionType.income,
      description: description,
      date: date ?? DateTime.now(),
      incomeCategory: IncomeCategory.salary,
      accountId: accountId,
    );
  }

  // 320 x 700 dp: un teléfono angosto, el peor caso para los desbordes.
  void useNarrowPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(640, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  setUpAll(() async {
    // Métricas de texto reales (si no, los desbordes medidos serían falsos).
    expect(
      await loadRoboto(),
      isTrue,
      reason: 'No se encontró Roboto en el SDK',
    );
    SharedPreferences.setMockInitialValues({});
    await AccountService().loadAccounts();
    accountId = AccountService().activeAccountId;
    await categories.loadCategories();
  });

  setUp(() async {
    await transactions.clearAllTransactions();
  });

  group('AmountText', () {
    testWidgets('reduce un monto enorme en vez de desbordar la fila', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 90,
                child: Row(
                  children: [
                    Expanded(
                      child: AmountText(
                        '-20.000.032,45 \$',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(FittedBox)).width,
        lessThanOrEqualTo(90),
      );
      // Una sola línea: no se parte en dos.
      expect(tester.widget<Text>(find.byType(Text)).maxLines, 1);
    });
  });

  group('Control del detector de desbordes', () {
    testWidgets('la fila original (chip -181818376.8%) sí desbordaba', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 238,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Septiembre 2026',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 14),
                              SizedBox(width: 4),
                              Text(
                                '7 transacciones',
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        '-181818376.8%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect(error.toString(), contains('overflowed'));
    });
  });

  group('Caso 5: valores altos no producen overflow', () {
    testWidgets(
      'Historial mensual con 20.000.032,45 y una categoría de nombre largo',
      (tester) async {
        useNarrowPhone(tester);
        final longName = await categories.addCategory(
          name: 'Categoría con un nombre larguísimo para probar el desborde',
          emoji: '🧪',
        );
        await transactions.addTransaction(income(11));
        await transactions.addTransaction(
          expense(
            20000032.45,
            customId: longName.id,
            customName: longName.name,
            customEmoji: longName.emoji,
          ),
        );

        await tester.pumpWidget(
          const MaterialApp(home: MonthlyHistoryScreen()),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(tester.takeException(), isNull);
        // La tasa de ahorro absurda se presenta acotada, no como -181818376,8%.
        expect(find.text('<-999%'), findsOneWidget);
        expect(find.textContaining('181818376'), findsNothing);
      },
    );

    testWidgets(
      'Historial mensual: mes con gastos y sin ingresos muestra "—"',
      (tester) async {
        useNarrowPhone(tester);
        await transactions.addTransaction(
          expense(1000000, system: ExpenseCategory.food),
        );

        await tester.pumpWidget(
          const MaterialApp(home: MonthlyHistoryScreen()),
        );
        await tester.pumpAndSettle(const Duration(seconds: 3));

        expect(tester.takeException(), isNull);
        expect(find.text('—'), findsOneWidget);
      },
    );

    testWidgets('Análisis gráfico con 20.000.032,45 en una categoría nueva', (
      tester,
    ) async {
      useNarrowPhone(tester);
      final big = await categories.addCategory(
        name: 'Maquinaria',
        emoji: '🏗️',
      );
      await transactions.addTransaction(
        expense(
          20000032.45,
          customId: big.id,
          customName: big.name,
          customEmoji: big.emoji,
        ),
      );
      await transactions.addTransaction(
        expense(28.7, system: ExpenseCategory.food),
      );

      await tester.pumpWidget(const MaterialApp(home: ChartsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
      expect(find.text('Maquinaria'), findsWidgets);
    });
  });

  group('Caso 1: el gráfico se actualiza solo con una categoría nueva', () {
    testWidgets('aparece al registrar un gasto y desaparece al eliminarlo', (
      tester,
    ) async {
      useNarrowPhone(tester);
      await transactions.addTransaction(
        expense(50, system: ExpenseCategory.food),
      );

      await tester.pumpWidget(const MaterialApp(home: ChartsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Alimentación'), findsWidgets);
      expect(find.text('Mascotas'), findsNothing);
      expect(find.text('1 categoría'), findsOneWidget);

      // Se crea la categoría y se registra un gasto MIENTRAS la pantalla está abierta.
      final pets = await categories.addCategory(name: 'Mascotas', emoji: '🐶');
      final petExpense = expense(
        25,
        customId: pets.id,
        customName: pets.name,
        customEmoji: pets.emoji,
      );
      await transactions.addTransaction(petExpense);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Mascotas'), findsWidgets);
      expect(find.text('2 categorías'), findsOneWidget);
      // 25 de 75 = 33,3 %; 50 de 75 = 66,7 % (la lista coincide con el total).
      expect(find.text('33.3%'), findsOneWidget);
      expect(find.text('66.7%'), findsOneWidget);

      // Una categoría sin gastos en el período deja de aparecer.
      await transactions.deleteTransaction(petExpense.id);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.text('Mascotas'), findsNothing);
      expect(find.text('1 categoría'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Calendario de Inicio', () {
    Future<void> pumpCard(WidgetTester tester) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: HomeCalendarCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // La celda de hoy se busca por su número de día, no por texto: el contador
    // de transacciones ("2") puede coincidir con el número del día (el día 2).
    Finder cellOfDay(int day) => find.byWidgetPredicate(
      (w) => w is CalendarDayCell && w.dayNumber == day,
    );

    // Cuántas veces aparece el texto "2" en la celda: el contador, más el
    // número del día si justo es el 2.
    Matcher countBadgeTwo(DateTime now) => findsNWidgets(now.day == 2 ? 2 : 1);

    testWidgets(
      'muestra la semana actual con indicadores de ingresos y gastos',
      (tester) async {
        final now = DateTime.now();
        await transactions.addTransaction(
          income(100, description: 'Sueldo de hoy'),
        );
        await transactions.addTransaction(
          expense(20, description: 'Café de hoy', system: ExpenseCategory.food),
        );

        await pumpCard(tester);

        expect(find.text('Calendario'), findsOneWidget);
        expect(find.byType(CalendarDayCell), findsNWidgets(7));
        expect(find.byType(CalendarMonthGrid), findsNothing);

        // Hoy tiene ingresos y gastos => contador "2" con los dos puntos.
        final todayCell = cellOfDay(now.day);
        expect(
          find.descendant(of: todayCell, matching: find.text('2')),
          countBadgeTwo(now),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'tocar un día abre sus transacciones y tocarlas abre Editar/Eliminar',
      (tester) async {
        final now = DateTime.now();
        await transactions.addTransaction(
          income(100, description: 'Sueldo de hoy'),
        );
        await transactions.addTransaction(
          expense(20, description: 'Café de hoy', system: ExpenseCategory.food),
        );

        await pumpCard(tester);
        await tester.tap(cellOfDay(now.day));
        await tester.pumpAndSettle();

        expect(find.text('Sueldo de hoy'), findsOneWidget);
        expect(find.text('Café de hoy'), findsOneWidget);

        await tester.tap(find.text('Café de hoy'));
        await tester.pumpAndSettle();

        expect(find.text('Editar'), findsOneWidget);
        expect(find.text('Eliminar'), findsOneWidget);
      },
    );

    testWidgets('el encabezado expande al mes completo y lo colapsa', (
      tester,
    ) async {
      await pumpCard(tester);

      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarMonthGrid), findsOneWidget);

      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarMonthGrid), findsNothing);
      expect(find.byType(CalendarDayCell), findsNWidgets(7));
    });

    testWidgets('se actualiza solo cuando cambian las transacciones', (
      tester,
    ) async {
      final now = DateTime.now();
      await pumpCard(tester);
      final todayCell = cellOfDay(now.day);
      // Sin movimientos no hay contador (solo el número del día, si es el 2).
      expect(
        find.descendant(of: todayCell, matching: find.text('2')),
        findsNWidgets(now.day == 2 ? 1 : 0),
      );

      await transactions.addTransaction(income(10));
      await transactions.addTransaction(
        expense(5, system: ExpenseCategory.food),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: todayCell, matching: find.text('2')),
        countBadgeTwo(now),
      );
    });
  });

  group('Acciones de una transacción reciente', () {
    Future<void> openSheet(WidgetTester tester, Transaction tx) async {
      useNarrowPhone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showTransactionActions(context, tx),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('muestra el detalle con Editar y Eliminar', (tester) async {
      final tx = expense(
        12.5,
        description: 'Almuerzo',
        system: ExpenseCategory.food,
      );
      await transactions.addTransaction(tx);
      await openSheet(tester, tx);

      expect(find.text('Almuerzo'), findsOneWidget);
      expect(find.textContaining('12,50'), findsOneWidget);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('Caso 4: eliminar quita la transacción de todas las fuentes', (
      tester,
    ) async {
      final tx = expense(
        12.5,
        description: 'Almuerzo',
        system: ExpenseCategory.food,
      );
      await transactions.addTransaction(tx);
      await openSheet(tester, tx);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar transacción?'), findsOneWidget);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(transactions.allTransactions.where((t) => t.id == tx.id), isEmpty);
      expect(transactions.totalExpenses, 0);
      expect(find.text('Transacción eliminada: Almuerzo'), findsOneWidget);
    });

    testWidgets('cancelar la confirmación no elimina nada', (tester) async {
      final tx = expense(
        8,
        description: 'Taxi',
        system: ExpenseCategory.transport,
      );
      await transactions.addTransaction(tx);
      await openSheet(tester, tx);

      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(
        transactions.allTransactions.where((t) => t.id == tx.id),
        hasLength(1),
      );
    });

    testWidgets('una transferencia solo se puede eliminar', (tester) async {
      final transfer = Transaction(
        id: 'w_transfer',
        amount: 50,
        type: TransactionType.transfer,
        description: 'Transferencia entre cuentas',
        date: DateTime.now(),
        accountId: accountId,
        transferId: 'transfer_1',
        isTransferOut: true,
      );
      await openSheet(tester, transfer);

      expect(find.text('Editar'), findsNothing);
      expect(find.text('Eliminar'), findsOneWidget);
      expect(find.textContaining('no se pueden editar'), findsOneWidget);
    });
  });
}
