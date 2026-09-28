import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ahorro_app/widgets/common/common.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('AppCard', () {
    testWidgets('renderiza su contenido', (tester) async {
      await tester.pumpWidget(_wrap(const AppCard(child: Text('hola'))));
      expect(find.text('hola'), findsOneWidget);
    });

    test('standardShadow expone una sombra sutil', () {
      final shadow = AppCard.standardShadow;
      expect(shadow.length, 1);
      expect(shadow.first.blurRadius, 10);
    });
  });

  group('SectionHeader', () {
    testWidgets('muestra el título dado', (tester) async {
      await tester.pumpWidget(_wrap(const SectionHeader('Mi sección')));
      expect(find.text('Mi sección'), findsOneWidget);
    });
  });

  group('AppListTile', () {
    testWidgets('con icon muestra el ícono y dispara onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          AppListTile(
            icon: Icons.settings,
            title: 'Configuración',
            subtitle: 'Ajustes de la app',
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.text('Configuración'), findsOneWidget);
      // Chevron automático cuando hay onTap y no se pasa trailing.
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      expect(tapped, true);
    });

    testWidgets('con emoji muestra el emoji en vez de un ícono', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const AppListTile(emoji: '🇪🇨', title: 'Ecuador', subtitle: 'USD'),
        ),
      );
      expect(find.text('🇪🇨'), findsOneWidget);
    });

    testWidgets('sin onTap no muestra chevron automático', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppListTile(
            icon: Icons.info,
            title: 'Solo info',
            subtitle: 'Sin acción',
          ),
        ),
      );
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });
  });

  group('AppPrimaryButton', () {
    testWidgets('dispara onPressed al tocar', (tester) async {
      var pressed = false;
      await tester.pumpWidget(
        _wrap(
          AppPrimaryButton(label: 'Guardar', onPressed: () => pressed = true),
        ),
      );

      expect(find.text('Guardar'), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(pressed, true);
    });

    testWidgets('con onPressed null no responde al toque', (tester) async {
      await tester.pumpWidget(
        _wrap(const AppPrimaryButton(label: 'Deshabilitado', onPressed: null)),
      );

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
    });

    testWidgets('loading muestra el spinner y oculta el texto', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AppPrimaryButton(
            label: 'Guardando...',
            loading: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Guardando...'), findsNothing);
    });

    testWidgets(
      'loading conserva el degradado — no se pone gris mientras carga',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            AppPrimaryButton(
              label: 'Guardando...',
              loading: true,
              onPressed:
                  null, // como en pantallas reales: se anula durante la carga
              gradientColors: const [Colors.blue, Colors.indigo],
            ),
          ),
        );

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.gradient, isNotNull);
        expect(decoration.color, isNull);
      },
    );

    testWidgets(
      'deshabilitado sin loading sí se pone gris (fondo y texto legible)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            const AppPrimaryButton(label: 'Deshabilitado', onPressed: null),
          ),
        );

        final container = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.gradient, isNull);
        expect(decoration.color, isNotNull);

        final text = tester.widget<Text>(find.text('Deshabilitado'));
        expect(text.style?.color, isNot(Colors.white));
      },
    );
  });

  group('QuickActionCard', () {
    testWidgets('muestra título/subtítulo y dispara onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          QuickActionCard(
            icon: Icons.add,
            title: 'Nueva meta',
            subtitle: 'Crea un objetivo',
            gradientColors: const [Colors.blue, Colors.indigo],
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('Nueva meta'), findsOneWidget);
      await tester.tap(find.byType(QuickActionCard));
      expect(tapped, true);
    });
  });

  group('AppEmptyState', () {
    testWidgets('sin CTA no muestra ningún botón', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Sin datos',
            message: 'Todavía no hay nada aquí',
          ),
        ),
      );

      expect(find.text('Sin datos'), findsOneWidget);
      expect(find.byType(AppPrimaryButton), findsNothing);
    });

    testWidgets('con CTA muestra el botón y dispara onCta', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          AppEmptyState(
            icon: Icons.inbox_outlined,
            title: 'Sin datos',
            message: 'Todavía no hay nada aquí',
            ctaLabel: 'Agregar',
            onCta: () => tapped = true,
          ),
        ),
      );

      expect(find.byType(AppPrimaryButton), findsOneWidget);
      await tester.tap(find.text('Agregar'));
      expect(tapped, true);
    });
  });

  group('AppBackButton', () {
    testWidgets('dispara el onPressed explícito en vez del pop por defecto', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(AppBackButton(onPressed: () => tapped = true)),
      );

      await tester.tap(find.byType(IconButton));
      expect(tapped, true);
    });
  });

  group('showAppConfirmDialog', () {
    testWidgets('cancelar devuelve false', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context,
                  title: '¿Eliminar?',
                  message: 'Esta acción no se puede deshacer.',
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('¿Eliminar?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result, false);
    });

    testWidgets('confirmar devuelve true', (tester) async {
      bool? result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showAppConfirmDialog(
                  context,
                  title: '¿Eliminar?',
                  message: 'Esta acción no se puede deshacer.',
                  confirmLabel: 'Sí, eliminar',
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sí, eliminar'));
      await tester.pumpAndSettle();
      expect(result, true);
    });
  });

  group('AmountInputFormatter', () {
    final formatter = const AmountInputFormatter();

    TextEditingValue apply(String oldText, String newText) {
      return formatter.formatEditUpdate(
        TextEditingValue(text: oldText),
        TextEditingValue(text: newText),
      );
    }

    test('permite vacío', () {
      expect(apply('12', '').text, '');
    });

    test('permite dígitos con hasta 2 decimales', () {
      expect(apply('10', '10.5').text, '10.5');
      expect(apply('10.5', '10.55').text, '10.55');
    });

    test('rechaza un tercer decimal', () {
      expect(apply('10.55', '10.555').text, '10.55');
    });

    test('rechaza caracteres no numéricos', () {
      expect(apply('10', '10a').text, '10');
    });

    test('rechaza montos por encima del tope', () {
      final formatter999 = const AmountInputFormatter(maxValue: 100);
      final result = formatter999.formatEditUpdate(
        const TextEditingValue(text: '10'),
        const TextEditingValue(text: '1000'),
      );
      expect(result.text, '10');
    });
  });
}
