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

  test('el paquete de Dart no cambió y Android usa el ID de Play Store', () {
    // El nombre del paquete de Dart rompería todas las importaciones si
    // cambiara. El ID de Android es el definitivo para Google Play: una vez
    // publicada la app NO se puede cambiar (Play no acepta com.example.*).
    expect(
      File('pubspec.yaml').readAsStringSync(),
      startsWith('name: ahorro_app'),
    );
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "com.piggyfy.app"'));
    expect(gradle, contains('namespace = "com.piggyfy.app"'));
    expect(gradle, isNot(contains('com.example')));
    expect(
      File(
        'android/app/src/main/kotlin/com/piggyfy/app/MainActivity.kt',
      ).readAsStringSync(),
      startsWith('package com.piggyfy.app'),
    );
  });

  test('la clave de firma y sus contraseñas están fuera de control de versiones', () {
    final ignore = File('android/.gitignore').readAsStringSync();
    expect(ignore, contains('key.properties'));
    expect(ignore, contains('*.jks'));
    expect(ignore, contains('*.keystore'));
  });

  test('la etiqueta de Android muestra PiggyFy', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      contains('android:label="PiggyFy"'),
    );
  });
}
