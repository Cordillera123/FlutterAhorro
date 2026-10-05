import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/region.dart';
import 'package:ahorro_app/screens/add_recurring_expense_screen.dart';
import 'package:ahorro_app/screens/create_budget_screen.dart';
import 'package:ahorro_app/screens/create_goal_screen.dart';
import 'package:ahorro_app/screens/main_navigation_screen.dart';
import 'package:ahorro_app/screens/region_settings_screen.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/category_service.dart';
import 'package:ahorro_app/services/region_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';
import 'package:ahorro_app/utils/app_refresh.dart';
import 'package:ahorro_app/utils/format_utils.dart';

import '../support/load_roboto.dart';

class _Money extends StatelessWidget {
  const _Money();

  @override
  Widget build(BuildContext context) => Text(FormatUtils.formatMoney(5));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final regionService = RegionService();

  void useTallPhone(
    WidgetTester tester, {
    double width = 360,
    double height = 3200,
  }) {
    tester.view.physicalSize = Size(width * 2, height * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  setUpAll(() async {
    expect(
      await loadRoboto(),
      isTrue,
      reason: 'No se encontró Roboto en el SDK',
    );
    SharedPreferences.setMockInitialValues({});
    await AccountService().loadAccounts();
    await CategoryService().loadCategories();
  });

  setUp(() async {
    await regionService.setRegion(Region.ecuador);
    await TransactionService().clearAllTransactions();
  });

  group('Configuración > Región y moneda', () {
    testWidgets('lista todas las monedas con un ejemplo de su formato', (
      tester,
    ) async {
      useTallPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: RegionSettingsScreen()));
      await tester.pumpAndSettle();

      for (final region in Region.values) {
        expect(
          find.text(region.displayName),
          findsOneWidget,
          reason: '$region',
        );
      }
      expect(find.textContaining('Euro (EUR)'), findsOneWidget);
      expect(find.textContaining('Yen japonés (JPY)'), findsOneWidget);
      expect(find.textContaining('Sol peruano (PEN)'), findsOneWidget);
      // Ejemplo de cada formato (1234,5 → ...).
      expect(find.textContaining('S/'), findsWidgets);
      expect(find.textContaining('£1,234.50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'cambiar de moneda avisa que no se convierte y se puede cancelar',
      (tester) async {
        useTallPhone(tester);
        await tester.pumpWidget(
          const MaterialApp(home: RegionSettingsScreen()),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Eurozona'));
        await tester.pumpAndSettle();

        expect(find.text('¿Cambiar a Euro?'), findsOneWidget);
        expect(find.textContaining('NO se convierten'), findsOneWidget);
        expect(find.textContaining('10,00 €'), findsOneWidget);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(regionService.current, Region.ecuador);
      },
    );

    testWidgets('confirmar aplica la nueva moneda', (tester) async {
      useTallPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: RegionSettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Japón'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambiar'));
      await tester.pumpAndSettle();

      expect(regionService.current, Region.japan);
      expect(FormatUtils.currencySymbol, '¥');
    });

    testWidgets('cambiar de país con la misma moneda no pide confirmación', (
      tester,
    ) async {
      useTallPhone(tester);
      await tester.pumpWidget(const MaterialApp(home: RegionSettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Estados Unidos'));
      await tester.pumpAndSettle();

      expect(find.textContaining('¿Cambiar a'), findsNothing);
      expect(regionService.current, Region.unitedStates);
    });
  });

  group('Refresco al cambiar de moneda', () {
    testWidgets('rebuildEntireApp actualiza pantallas ya construidas', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _Money())),
      );
      expect(find.text('5,00 \$'), findsOneWidget);

      await regionService.setRegion(Region.eurozone);
      await tester.pump();
      // Sin refrescar, el widget const sigue mostrando la moneda anterior...
      expect(find.text('5,00 \$'), findsOneWidget);

      // ...y con rebuildEntireApp se actualiza.
      rebuildEntireApp();
      await tester.pump();
      expect(find.text('5,00 €'), findsOneWidget);
    });
  });

  group('Botón flotante "Agregar" en las cinco pestañas', () {
    Future<void> pumpMain(WidgetTester tester) async {
      useTallPhone(tester, height: 900);
      await tester.pumpWidget(const MaterialApp(home: MainNavigationScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    // Las etiquetas de la barra inferior son lo último del árbol con ese texto.
    Future<void> goTo(WidgetTester tester, String label) async {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    testWidgets('el mismo botón está en todas las pestañas', (tester) async {
      await pumpMain(tester);

      for (final tab in [
        'Inicio',
        'Presupuestos',
        'Metas',
        'Historial',
        'Automático',
      ]) {
        await goTo(tester, tab);
        expect(find.byType(FloatingActionButton), findsOneWidget, reason: tab);
        expect(
          find.descendant(
            of: find.byType(FloatingActionButton),
            matching: find.text('Agregar'),
          ),
          findsOneWidget,
          reason: tab,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'Presupuestos, Metas y Automático ya no tienen botones "+" extra',
      (tester) async {
        await pumpMain(tester);

        await goTo(tester, 'Presupuestos');
        // Solo queda el "+" del botón flotante.
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);

        await goTo(tester, 'Metas');
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
        expect(find.text('Nueva Meta'), findsNothing);

        await goTo(tester, 'Automático');
        expect(find.byTooltip('Agregar gasto recurrente'), findsNothing);
      },
    );

    testWidgets('cada pestaña crea lo suyo con el botón', (tester) async {
      await pumpMain(tester);

      expect(find.byTooltip('Agregar transacción'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Nueva Transacción'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10)); // cierra el menú
      await tester.pumpAndSettle();

      await goTo(tester, 'Metas');
      expect(find.byTooltip('Crear meta'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(CreateGoalScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(CreateGoalScreen))).pop();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await goTo(tester, 'Presupuestos');
      expect(find.byTooltip('Crear presupuesto'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(CreateBudgetScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(CreateBudgetScreen))).pop();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await goTo(tester, 'Automático');
      expect(find.byTooltip('Crear gasto automático'), findsOneWidget);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(AddRecurringExpenseScreen), findsOneWidget);
    });
  });
}
