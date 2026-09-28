import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/services/onboarding_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingService', () {
    test('instalación nueva: el tutorial se muestra', () async {
      SharedPreferences.setMockInitialValues({});
      final service = OnboardingService();
      await service.load();
      expect(service.shouldShow, isTrue);
    });

    test(
      'después de completarlo no vuelve a mostrarse, ni al reabrir la app',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = OnboardingService();
        await service.load();

        await service.markCompleted();
        expect(service.shouldShow, isFalse);

        // Simula reabrir la app: vuelve a leer desde disco.
        await service.load();
        expect(service.shouldShow, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('onboarding_completed'), isTrue);
      },
    );

    test('si ya estaba marcado como visto, no se muestra', () async {
      SharedPreferences.setMockInitialValues({'onboarding_completed': true});
      final service = OnboardingService();
      await service.load();
      expect(service.shouldShow, isFalse);
    });
  });
}
