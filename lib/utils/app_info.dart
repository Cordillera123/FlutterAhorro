/// Datos de identidad de la app. El nombre que ve la persona vive aquí, en un
/// único lugar, para no repetirlo en cada pantalla.
///
/// OJO: es solo el nombre *visible*. El nombre del paquete de Dart
/// (`ahorro_app` en `pubspec.yaml`, de donde salen los `package:ahorro_app/...`)
/// y el identificador de Android (`applicationId`) son internos y no se
/// tocan al cambiar el nombre: cambiarlos rompería las importaciones y haría
/// que Android trate la app como una distinta (sin los datos ya guardados).
class AppInfo {
  AppInfo._();

  /// Nombre de la app tal como se muestra al usuario.
  static const String name = 'PiggyFy';
}
