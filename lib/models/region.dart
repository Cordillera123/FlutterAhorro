/// Región/país configurable de la app: controla el locale de formato de
/// números y fechas del sistema, y la moneda mostrada en montos.
///
/// La app no está atada estructuralmente a un solo país — agregar una
/// región nueva es un caso más en este enum, no un cambio de arquitectura.
enum Region { ecuador, colombia }

extension RegionData on Region {
  String get displayName {
    switch (this) {
      case Region.ecuador:
        return 'Ecuador';
      case Region.colombia:
        return 'Colombia';
    }
  }

  String get flagEmoji {
    switch (this) {
      case Region.ecuador:
        return '🇪🇨';
      case Region.colombia:
        return '🇨🇴';
    }
  }

  /// Código de idioma para `Locale` y `NumberFormat` (ISO 639-1).
  String get languageCode => 'es';

  /// Código de país para `Locale` (ISO 3166-1 alpha-2).
  String get countryCode {
    switch (this) {
      case Region.ecuador:
        return 'EC';
      case Region.colombia:
        return 'CO';
    }
  }

  /// Locale completo usado por `NumberFormat` (ej. `es_EC`).
  String get localeCode => '${languageCode}_$countryCode';

  String get currencyCode {
    switch (this) {
      case Region.ecuador:
        return 'USD';
      case Region.colombia:
        return 'COP';
    }
  }

  String get currencyName {
    switch (this) {
      case Region.ecuador:
        return 'Dólar estadounidense';
      case Region.colombia:
        return 'Peso colombiano';
    }
  }

  String get currencySymbol => '\$';
}
