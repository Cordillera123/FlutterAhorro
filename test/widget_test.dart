import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ahorro_app/main.dart';

void main() {
  testWidgets('Ahorro app loads without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AhorroApp());

    // Verify that the app loads the home screen
    expect(find.byType(AhorroApp), findsOneWidget);

    // El splash programa su navegación con temporizadores (2,8 s): se
    // desmonta la app y se dejan correr, para que la prueba no termine con
    // temporizadores pendientes (antes fallaba por eso).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
