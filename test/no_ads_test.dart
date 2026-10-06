import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La app no muestra anuncios: ni el SDK de AdMob ni su configuración.
void main() {
  test('sin SDK de anuncios en las dependencias', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('google_mobile_ads')),
    );
    expect(
      File('pubspec.lock').readAsStringSync(),
      isNot(contains('google_mobile_ads')),
    );
  });

  test('sin ID de AdMob en Android', () {
    expect(
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      isNot(contains('com.google.android.gms.ads')),
    );
    expect(
      File('android/app/build.gradle.kts').readAsStringSync().toLowerCase(),
      isNot(contains('admob')),
    );
  });

  test('sin código de anuncios en lib/', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) {
          final code = f.readAsStringSync();
          return code.contains('google_mobile_ads') ||
              code.contains('BannerAd') ||
              code.contains('AdsService');
        })
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });
}
