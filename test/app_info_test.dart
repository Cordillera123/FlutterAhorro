import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ahorro_app/utils/app_info.dart';

void main() {
  test('el nombre visible de la app es PiggyFy', () {
    expect(AppInfo.name, 'PiggyFy');
  });

  test('el nombre antiguo ya no aparece en textos visibles de lib/', () {
    final old = RegExp(
      r'Mi App de Ahorro|Mi Ahorro|AhorroApp_|de AhorroApp\b|a AhorroApp\b',
    );
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final text = entity.readAsStringSync();
      if (old.hasMatch(text)) offenders.add(entity.path);
    }
    expect(offenders, isEmpty, reason: 'Quedan textos con el nombre antiguo');
  });

  test(
    'los identificadores internos NO cambiaron (paquete y applicationId)',
    () {
      // Cambiarlos rompería las importaciones y haría que Android trate la app
      // como otra (sin los datos guardados).
      expect(
        File('pubspec.yaml').readAsStringSync(),
        startsWith('name: ahorro_app'),
      );
      expect(
        File('android/app/build.gradle.kts').readAsStringSync(),
        contains('applicationId = "com.example.ahorro_app"'),
      );
    },
  );

  test('la etiqueta de Android muestra PiggyFy', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="PiggyFy"'),
    );
  });
}
