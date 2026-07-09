import '../../models/export_data.dart';

/// Contrato que deben implementar todos los exportadores de reportes.
///
/// El patrón Strategy permite agregar nuevos formatos (PDF, CSV) sin
/// modificar [ExportService]: basta con crear una nueva clase que
/// implemente [BaseExporter] y registrarla en `_resolveExporter`.
///
/// Responsabilidad única: recibir datos listos y devolver bytes del archivo.
/// El guardado en disco y el compartir son responsabilidad de [ExportService].
abstract class BaseExporter {
  /// Genera el archivo en el formato correspondiente y devuelve sus bytes.
  ///
  /// [data] ya contiene los datos filtrados y las métricas precalculadas.
  /// Las implementaciones deben ejecutar la generación pesada fuera del
  /// hilo principal (p. ej. con [Isolate.run]).
  Future<List<int>> generateBytes(ExportData data);

  /// Extensión del archivo generado (sin punto). Ej: `'xlsx'`, `'pdf'`, `'csv'`.
  String get fileExtension;

  /// MIME type del archivo generado.
  String get mimeType;
}
