import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/screens/add_transaction_screen.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/category_service.dart';

import '../support/load_roboto.dart';

/// El formulario de Agregar ingreso/gasto no debe desbordar en ninguno de los
/// anchos de teléfono habituales. (Antes, con la fuente real, el de ingreso
/// desbordaba 2 px a 360 dp y más a 320 dp: las casillas de categorías eran
/// más bajas que su contenido y la etiqueta "Ingreso" no cabía a 320 dp.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  const widths = [320.0, 360.0, 375.0, 392.0, 411.0, 430.0];

  for (final type in TransactionType.values.where(
    (t) => t != TransactionType.transfer,
  )) {
    for (final width in widths) {
      testWidgets(
        'formulario de ${type.name} sin desbordes a ${width.toInt()} dp',
        (tester) async {
          tester.view.physicalSize = Size(width * 2, 3600);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(home: AddTransactionScreen(initialType: type)),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'en pantallas anchas las casillas de ingreso conservan el emoji a tamaño completo',
    (tester) async {
      tester.view.physicalSize = const Size(411 * 2, 3600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: AddTransactionScreen(initialType: TransactionType.income),
        ),
      );
      await tester.pumpAndSettle();

      // El emoji de "Freelance" (no seleccionado) mide 24: el FittedBox solo
      // actúa cuando la casilla es demasiado baja, no aquí.
      final fitted = find
          .ancestor(of: find.text('💻'), matching: find.byType(FittedBox))
          .first;
      final box = tester.renderObject<RenderBox>(fitted);
      final emoji = tester.renderObject<RenderBox>(find.text('💻'));
      expect(emoji.size.height, closeTo(box.size.height, 0.5));
    },
  );
}
