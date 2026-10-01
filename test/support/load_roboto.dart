import 'dart:io';

import 'package:flutter/services.dart';

/// Carga Roboto (incluida en el SDK de Flutter) para que los tests de widgets
/// midan los textos con métricas reales.
///
/// Sin esto, `flutter test` dibuja todo con la fuente "Ahem", donde cada letra
/// ocupa un cuadrado completo: filas que en el teléfono caben de sobra
/// aparecen como `RenderFlex overflowed` y los tests de desborde dejan de
/// ser fiables.
///
/// Devuelve `false` si no encuentra los archivos de fuente.
Future<bool> loadRoboto() async {
  final dir = _materialFontsDir();
  if (dir == null) return false;

  const files = [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-black.ttf',
    'roboto-light.ttf',
  ];

  final loader = FontLoader('Roboto');
  var added = 0;
  for (final name in files) {
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    if (file.existsSync()) {
      final bytes = file.readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
      added++;
    }
  }
  if (added == 0) return false;
  await loader.load();
  return true;
}

Directory? _materialFontsDir() {
  final candidates = <String>[];

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) candidates.add(root);

  // flutter_tester vive en <flutter>/bin/cache/artifacts/engine/<plataforma>/
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    candidates.add(dir.path);
    dir = dir.parent;
  }

  for (final base in candidates) {
    for (final relative in [
      'bin/cache/artifacts/material_fonts',
      'artifacts/material_fonts',
      'material_fonts',
    ]) {
      final d = Directory('$base${Platform.pathSeparator}$relative'.replaceAll('/', Platform.pathSeparator));
      if (d.existsSync()) return d;
    }
  }
  return null;
}
