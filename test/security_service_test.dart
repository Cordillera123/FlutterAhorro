import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ahorro_app/services/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = SecurityService();

  // Backing store en memoria fresco antes de cada test, más un reset
  // explícito del estado en memoria del singleton (disableLock dejа
  // todo en su estado "apagado" conocido), para que los tests no
  // dependan del orden de ejecución.
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await service.disableLock();
  });

  group('SecurityService — PIN', () {
    test(
      'setPin habilita el bloqueo y permite verificar el PIN correcto',
      () async {
        await service.setPin('1234');

        expect(service.isLockEnabled, true);
        expect(service.hasPin, true);
        expect(await service.verifyPin('1234'), true);
      },
    );

    test('verifyPin rechaza un PIN incorrecto', () async {
      await service.setPin('1234');
      expect(await service.verifyPin('0000'), false);
    });

    test('verifyPin sin PIN configurado devuelve false (no lanza)', () async {
      expect(await service.verifyPin('1234'), false);
    });

    test('el PIN nunca se guarda en texto plano', () async {
      await service.setPin('1234');
      const storage = FlutterSecureStorage();
      final all = await storage.readAll();
      final storedValues = all.values.join(' ');
      expect(storedValues.contains('1234'), false);
    });

    test('cambiar el PIN invalida el anterior', () async {
      await service.setPin('1234');
      await service.setPin('5678');

      expect(await service.verifyPin('1234'), false);
      expect(await service.verifyPin('5678'), true);
    });

    test('disableLock borra el PIN y desactiva biometría', () async {
      await service.setPin('1234');
      await service.setBiometricEnabled(true);

      await service.disableLock();

      expect(service.isLockEnabled, false);
      expect(service.hasPin, false);
      expect(service.isBiometricEnabled, false);
      expect(await service.verifyPin('1234'), false);
    });
  });

  group('SecurityService — preferencias', () {
    test('setHideBalances persiste el valor', () async {
      await service.setHideBalances(true);
      expect(service.hideBalances, true);

      await service.setHideBalances(false);
      expect(service.hideBalances, false);
    });

    test('setBiometricEnabled persiste el valor', () async {
      await service.setBiometricEnabled(true);
      expect(service.isBiometricEnabled, true);
    });
  });
}
