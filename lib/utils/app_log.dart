import 'package:flutter/foundation.dart';

/// Registro de errores SOLO para desarrollo.
///
/// En la app publicada (release) no escribe nada. Antes había ~95 `print()`
/// que dejaban en el registro del sistema (logcat) nombres de cuentas, ids,
/// montos y rutas de archivos, visibles para otras herramientas del teléfono.
abstract final class AppLog {
  /// Anota un error inesperado (normalmente desde un `catch`).
  static void error(String message, [Object? error]) {
    if (!kDebugMode) return;
    debugPrint(error == null ? message : '$message: $error');
  }
}
