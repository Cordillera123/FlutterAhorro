import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/region.dart';
import 'package:ahorro_app/services/region_service.dart';
import 'package:ahorro_app/utils/format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RegionService', () {
    test('por defecto (sin datos guardados) es Ecuador', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RegionService();
      await service.load();
      expect(service.current, Region.ecuador);
    });

    test('setRegion persiste y notifica a los listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final service = RegionService();
      await service.load();

      var notified = false;
      service.addListener(() => notified = true);

      await service.setRegion(Region.colombia);

      expect(service.current, Region.colombia);
      expect(notified, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('region_selected'), 'colombia');
    });

    test('load() recupera la región previamente guardada', () async {
      SharedPreferences.setMockInitialValues({'region_selected': 'colombia'});
      final service = RegionService();
      await service.load();
      expect(service.current, Region.colombia);

      // Dejar el singleton en un estado neutro para no afectar otros tests.
      await service.setRegion(Region.ecuador);
    });

    test(
      'setRegion con la misma región no notifica innecesariamente',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = RegionService();
        await service.load(); // Ecuador por defecto

        var notifyCount = 0;
        service.addListener(() => notifyCount++);

        await service.setRegion(Region.ecuador);
        expect(notifyCount, 0);
      },
    );
  });

  group('Region — datos por región', () {
    test('Ecuador usa locale es_EC y moneda USD', () {
      expect(Region.ecuador.localeCode, 'es_EC');
      expect(Region.ecuador.currencyCode, 'USD');
    });

    test('Colombia usa locale es_CO y moneda COP', () {
      expect(Region.colombia.localeCode, 'es_CO');
      expect(Region.colombia.currencyCode, 'COP');
    });
  });

  group('FormatUtils.formatMoney — reacciona a la región activa', () {
    test(
      'el monto formateado incluye el símbolo de moneda de la región',
      () async {
        SharedPreferences.setMockInitialValues({});
        final service = RegionService();
        await service.load();
        await service.setRegion(Region.ecuador);

        final formatted = FormatUtils.formatMoney(1234.5);
        expect(formatted.contains('\$'), true);
        expect(
          formatted.contains('1234') ||
              formatted.contains('1.234') ||
              formatted.contains('1,234'),
          true,
        );

        await service.setRegion(Region.colombia);
      },
    );
  });
}
