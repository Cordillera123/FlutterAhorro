import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guardián: la app no debe escribir datos en el registro del sistema
/// (logcat) de la versión publicada. Los errores se anotan con `AppLog`, que
/// solo escribe en modo desarrollo.
void main() {
  // Único lugar que puede usar debugPrint: AppLog.
  const debugPrintAllowed = {'lib/utils/app_log.dart'};

  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  String rel(File f) => f.path.replaceAll('\\', '/');

  test('no hay print() en lib/', () {
    final offenders = <String>[];
    for (final file in files) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (RegExp(r'(^|[^\w.])print\(').hasMatch(code)) {
          offenders.add('${rel(file)}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('debugPrint solo en AppLog', () {
    final offenders = <String>[];
    for (final file in files) {
      if (debugPrintAllowed.contains(rel(file))) continue;
      if (file.readAsStringSync().contains('debugPrint(')) {
        offenders.add(rel(file));
      }
    }
    expect(offenders, isEmpty);
  });
}
