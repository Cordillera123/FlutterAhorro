import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/screens/onboarding_screen.dart';
import 'package:ahorro_app/services/onboarding_service.dart';

void main() {
  Future<void> pumpOnboarding(
    WidgetTester tester, {
    required VoidCallback onFinished,
  }) async {
    SharedPreferences.setMockInitialValues({});
    await OnboardingService().load();
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onFinished: onFinished)),
    );
  }

  testWidgets('Omitir marca el tutorial como visto y llama a onFinished', (
    tester,
  ) async {
    var finished = false;
    await pumpOnboarding(tester, onFinished: () => finished = true);

    expect(find.text('1 de 7'), findsOneWidget);
    await tester.tap(find.text('Omitir'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
    expect(OnboardingService().shouldShow, isFalse);
  });

  testWidgets(
    'Siguiente recorre las 7 pantallas y la última muestra Comenzar',
    (tester) async {
      var finished = false;
      await pumpOnboarding(tester, onFinished: () => finished = true);

      for (var i = 0; i < 6; i++) {
        await tester.tap(find.text('Siguiente'));
        await tester.pumpAndSettle();
      }

      expect(find.text('7 de 7'), findsOneWidget);
      expect(find.text('Comenzar'), findsOneWidget);
      expect(find.text('Omitir'), findsNothing);
      expect(finished, isFalse);

      await tester.tap(find.text('Comenzar'));
      await tester.pumpAndSettle();

      expect(finished, isTrue);
      expect(OnboardingService().shouldShow, isFalse);
    },
  );
}
