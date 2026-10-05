import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/region.dart';
import 'package:ahorro_app/services/region_service.dart';
import 'package:ahorro_app/utils/excel_formatter.dart';
import 'package:ahorro_app/utils/format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final regionService = RegionService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await regionService.setRegion(Region.ecuador);
  });

  group('Catálogo de monedas', () {
    test('incluye las monedas más importantes, sin repetir regiones', () {
      final codes = Region.values.map((r) => r.currencyCode).toSet();
      expect(
        codes,
        containsAll(<String>[
          'USD',
          'EUR',
          'GBP',
          'JPY',
          'CHF',
          'CAD',
          'MXN',
          'COP',
          'PEN',
          'ARS',
          'CLP',
          'BRL',
          'BOB',
          'UYU',
          'PYG',
          'CRC',
          'DOP',
        ]),
      );
      expect(Region.values.length, 18);
      expect(Region.values.first, Region.ecuador);
      // Nombres para mostrar únicos.
      expect(
        Region.values.map((r) => r.displayName).toSet().length,
        Region.values.length,
      );
    });

    test('toda región tiene datos completos y formatea sin errores', () {
      for (final region in Region.values) {
        expect(region.displayName, isNotEmpty, reason: '$region');
        expect(region.flagEmoji, isNotEmpty, reason: '$region');
        expect(region.currencyName, isNotEmpty, reason: '$region');
        expect(region.currencyCode.length, 3, reason: '$region');
        expect(region.currencySymbol, isNotEmpty, reason: '$region');
        expect(region.numberLocale, isNotEmpty, reason: '$region');

        final text = FormatUtils.formatMoneyIn(region, 20000032.45);
        expect(
          text,
          contains(region.currencySymbol),
          reason: '${region.currencyCode} → $text',
        );
        // Los 8 dígitos significativos siempre están (con cualquier separador).
        expect(
          text.replaceAll(RegExp(r'[^0-9]'), ''),
          region.decimalDigits == 0 ? '20000032' : '2000003245',
          reason: '${region.currencyCode} → $text',
        );
      }
    });

    test('el formato de cada moneda sigue su convención', () {
      String f(Region r, double a) => FormatUtils.formatMoneyIn(r, a);
      const nbsp = ' ';

      // Ecuador conserva el formato de siempre.
      expect(f(Region.ecuador, 20000032.45), '20.000.032,45$nbsp\$');
      expect(f(Region.mexico, 1234.5), '\$1,234.50');
      expect(f(Region.unitedStates, 1234.5), '\$1,234.50');
      expect(f(Region.brazil, 1234.5), 'R\$${nbsp}1.234,50');
      expect(f(Region.unitedKingdom, 1234.5), '£1,234.50');
      // Perú y R. Dominicana escriben con punto decimal.
      expect(f(Region.peru, 1234.5), 'S/1,234.50');
      expect(f(Region.dominicanRepublic, 1234.5), 'RD\$1,234.50');
      // El resto de Latinoamérica: coma decimal y símbolo al final.
      expect(f(Region.argentina, 1234.5), '1.234,50${nbsp}\$');
      expect(f(Region.colombia, 1234.5), '1.234,50${nbsp}\$');
      expect(f(Region.eurozone, 12345.5), '12.345,50$nbsp€');
      // Monedas sin decimales.
      expect(f(Region.japan, 1234.5).replaceAll(RegExp(r'[^0-9]'), ''), '1235');
      expect(f(Region.chile, 1500), isNot(contains(',00')));
      expect(f(Region.chile, 1500), isNot(contains('.00')));
      expect(f(Region.paraguay, 1500), contains('₲'));
    });

    test('la moneda activa cambia formatMoney, el resumen y el hint', () async {
      expect(FormatUtils.currencySymbol, '\$');
      expect(FormatUtils.amountHint(), '\$0.00');
      expect(FormatUtils.formatMoney(10), '10,00 \$');

      await regionService.setRegion(Region.eurozone);
      expect(FormatUtils.currencySymbol, '€');
      expect(FormatUtils.amountHint(), '€0.00');
      expect(FormatUtils.formatMoney(10), '10,00 €');

      await regionService.setRegion(Region.japan);
      expect(FormatUtils.amountHint(), '¥0');
      expect(FormatUtils.amountHint(decimals: false), '¥0');
      expect(
        FormatUtils.formatMoney(1000).replaceAll(RegExp(r'[^0-9]'), ''),
        '1000',
      );
    });

    test(
      'formatMoneyShort y formatMoneyCompact usan el símbolo activo',
      () async {
        await regionService.setRegion(Region.peru);
        expect(FormatUtils.formatMoneyShort(20000000), contains('S/'));
        expect(FormatUtils.formatMoneyCompact(2500000), startsWith('S/2.5'));
        expect(FormatUtils.formatMoneyCompact(5000), startsWith('S/5'));
      },
    );

    test('el ícono de dinero acompaña a la moneda', () async {
      expect(FormatUtils.currencyIcon, Icons.attach_money_rounded);
      await regionService.setRegion(Region.eurozone);
      expect(FormatUtils.currencyIcon, Icons.euro_rounded);
      await regionService.setRegion(Region.unitedKingdom);
      expect(FormatUtils.currencyIcon, Icons.currency_pound_rounded);
      await regionService.setRegion(Region.japan);
      expect(FormatUtils.currencyIcon, Icons.currency_yen_rounded);
      await regionService.setRegion(Region.switzerland);
      expect(FormatUtils.currencyIcon, Icons.currency_franc_rounded);
      await regionService.setRegion(Region.peru);
      expect(FormatUtils.currencyIcon, Icons.payments_rounded);
    });

    test('parseAmount ignora el símbolo de la moneda activa', () async {
      await regionService.setRegion(Region.peru);
      expect(FormatUtils.parseAmount('S/1,250.50'), 1250.5);
      expect(FormatUtils.parseAmount('\$300'), 300);
      await regionService.setRegion(Region.eurozone);
      expect(FormatUtils.parseAmount('€45.75'), 45.75);
    });
  });

  group('Reportes', () {
    test('Excel usa el símbolo y los decimales de la moneda activa', () async {
      expect(ExcelFormatter.formatMoney(1234.5), '\$1,234.50');

      await regionService.setRegion(Region.eurozone);
      expect(ExcelFormatter.formatMoney(1234.5), '€1,234.50');
      expect(ExcelFormatter.formatMoneyWithSign(-1234.5), '-€1,234.50');

      await regionService.setRegion(Region.japan);
      expect(ExcelFormatter.formatMoney(1234.5), '¥1,235');
      expect(ExcelFormatter.formatMoney(double.nan), '¥0');
    });
  });

  group('Preferencia guardada', () {
    test('se guarda y se recupera la región elegida', () async {
      await regionService.setRegion(Region.mexico);
      await regionService.load();
      expect(regionService.current, Region.mexico);

      // Las regiones originales siguen resolviéndose por su nombre guardado.
      SharedPreferences.setMockInitialValues({'region_selected': 'colombia'});
      await regionService.load();
      expect(regionService.current, Region.colombia);

      SharedPreferences.setMockInitialValues({
        'region_selected': 'inexistente',
      });
      await regionService.load();
      expect(
        regionService.current,
        Region.ecuador,
      ); // valor desconocido: por defecto
    });
  });
}
