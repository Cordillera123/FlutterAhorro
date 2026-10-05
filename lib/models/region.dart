/// Región/país configurable de la app: controla el formato de números del
/// sistema y la moneda mostrada en montos.
///
/// La app no está atada estructuralmente a un solo país — agregar una
/// región nueva es un caso más en este enum (y su fila en [_regionInfo]), no
/// un cambio de arquitectura.
///
/// Se guarda por `name`, así que no se deben renombrar los valores ya
/// existentes (`ecuador`, `colombia`, ...) o se perdería la preferencia
/// guardada de quien ya la eligió. El orden de declaración es el orden en que
/// se muestran en Configuración.
enum Region {
  ecuador,
  unitedStates,
  eurozone,
  colombia,
  mexico,
  peru,
  argentina,
  chile,
  brazil,
  bolivia,
  uruguay,
  paraguay,
  costaRica,
  dominicanRepublic,
  unitedKingdom,
  canada,
  japan,
  switzerland,
}

/// Datos fijos de una región. Se mantienen en una sola tabla (en vez de un
/// `switch` por propiedad) para que agregar o revisar una moneda sea tocar
/// una única fila.
class _RegionInfo {
  final String displayName;
  final String flagEmoji;

  /// País del `Locale` de la interfaz (el idioma siempre es español).
  final String countryCode;

  /// Locale con el que `NumberFormat` separa miles/decimales y posiciona el
  /// símbolo, según la convención de esa moneda (ej. `es_MX`, `pt_BR`).
  ///
  /// `intl` solo trae datos para algunos locales; cuando no existe el pedido
  /// (ej. `es_EC`, `es_AR`) usa el español genérico: miles con punto,
  /// decimales con coma y el símbolo al final. Eso es lo correcto para
  /// Ecuador, Colombia, Argentina, Chile, etc. Por eso Perú y República
  /// Dominicana (que escriben `1,234.50`) piden `es_MX`, que sí existe.
  final String numberLocale;

  final String currencyCode;
  final String currencyName;
  final String currencySymbol;

  /// Decimales con los que se muestra la moneda (0 para CLP, PYG y JPY).
  final int decimalDigits;

  const _RegionInfo({
    required this.displayName,
    required this.flagEmoji,
    required this.countryCode,
    required this.numberLocale,
    required this.currencyCode,
    required this.currencyName,
    required this.currencySymbol,
    this.decimalDigits = 2,
  });
}

const Map<Region, _RegionInfo> _regionInfo = {
  Region.ecuador: _RegionInfo(
    displayName: 'Ecuador',
    flagEmoji: '🇪🇨',
    countryCode: 'EC',
    numberLocale: 'es_EC',
    currencyCode: 'USD',
    currencyName: 'Dólar estadounidense',
    currencySymbol: '\$',
  ),
  Region.unitedStates: _RegionInfo(
    displayName: 'Estados Unidos',
    flagEmoji: '🇺🇸',
    countryCode: 'US',
    numberLocale: 'es_US',
    currencyCode: 'USD',
    currencyName: 'Dólar estadounidense',
    currencySymbol: '\$',
  ),
  Region.eurozone: _RegionInfo(
    displayName: 'Eurozona',
    flagEmoji: '🇪🇺',
    countryCode: 'ES',
    numberLocale: 'es_ES',
    currencyCode: 'EUR',
    currencyName: 'Euro',
    currencySymbol: '€',
  ),
  Region.colombia: _RegionInfo(
    displayName: 'Colombia',
    flagEmoji: '🇨🇴',
    countryCode: 'CO',
    numberLocale: 'es_CO',
    currencyCode: 'COP',
    currencyName: 'Peso colombiano',
    currencySymbol: '\$',
  ),
  Region.mexico: _RegionInfo(
    displayName: 'México',
    flagEmoji: '🇲🇽',
    countryCode: 'MX',
    numberLocale: 'es_MX',
    currencyCode: 'MXN',
    currencyName: 'Peso mexicano',
    currencySymbol: '\$',
  ),
  Region.peru: _RegionInfo(
    displayName: 'Perú',
    flagEmoji: '🇵🇪',
    countryCode: 'PE',
    numberLocale: 'es_MX',
    currencyCode: 'PEN',
    currencyName: 'Sol peruano',
    currencySymbol: 'S/',
  ),
  Region.argentina: _RegionInfo(
    displayName: 'Argentina',
    flagEmoji: '🇦🇷',
    countryCode: 'AR',
    numberLocale: 'es_AR',
    currencyCode: 'ARS',
    currencyName: 'Peso argentino',
    currencySymbol: '\$',
  ),
  Region.chile: _RegionInfo(
    displayName: 'Chile',
    flagEmoji: '🇨🇱',
    countryCode: 'CL',
    numberLocale: 'es_CL',
    currencyCode: 'CLP',
    currencyName: 'Peso chileno',
    currencySymbol: '\$',
    decimalDigits: 0,
  ),
  Region.brazil: _RegionInfo(
    displayName: 'Brasil',
    flagEmoji: '🇧🇷',
    countryCode: 'BR',
    numberLocale: 'pt_BR',
    currencyCode: 'BRL',
    currencyName: 'Real brasileño',
    currencySymbol: 'R\$',
  ),
  Region.bolivia: _RegionInfo(
    displayName: 'Bolivia',
    flagEmoji: '🇧🇴',
    countryCode: 'BO',
    numberLocale: 'es_BO',
    currencyCode: 'BOB',
    currencyName: 'Boliviano',
    currencySymbol: 'Bs',
  ),
  Region.uruguay: _RegionInfo(
    displayName: 'Uruguay',
    flagEmoji: '🇺🇾',
    countryCode: 'UY',
    numberLocale: 'es_UY',
    currencyCode: 'UYU',
    currencyName: 'Peso uruguayo',
    currencySymbol: '\$U',
  ),
  Region.paraguay: _RegionInfo(
    displayName: 'Paraguay',
    flagEmoji: '🇵🇾',
    countryCode: 'PY',
    numberLocale: 'es_PY',
    currencyCode: 'PYG',
    currencyName: 'Guaraní paraguayo',
    currencySymbol: '₲',
    decimalDigits: 0,
  ),
  Region.costaRica: _RegionInfo(
    displayName: 'Costa Rica',
    flagEmoji: '🇨🇷',
    countryCode: 'CR',
    numberLocale: 'es_CR',
    currencyCode: 'CRC',
    currencyName: 'Colón costarricense',
    currencySymbol: '₡',
  ),
  Region.dominicanRepublic: _RegionInfo(
    displayName: 'República Dominicana',
    flagEmoji: '🇩🇴',
    countryCode: 'DO',
    numberLocale: 'es_MX',
    currencyCode: 'DOP',
    currencyName: 'Peso dominicano',
    currencySymbol: 'RD\$',
  ),
  Region.unitedKingdom: _RegionInfo(
    displayName: 'Reino Unido',
    flagEmoji: '🇬🇧',
    countryCode: 'GB',
    numberLocale: 'en_GB',
    currencyCode: 'GBP',
    currencyName: 'Libra esterlina',
    currencySymbol: '£',
  ),
  Region.canada: _RegionInfo(
    displayName: 'Canadá',
    flagEmoji: '🇨🇦',
    countryCode: 'CA',
    numberLocale: 'en_CA',
    currencyCode: 'CAD',
    currencyName: 'Dólar canadiense',
    currencySymbol: '\$',
  ),
  Region.japan: _RegionInfo(
    displayName: 'Japón',
    flagEmoji: '🇯🇵',
    countryCode: 'JP',
    numberLocale: 'ja_JP',
    currencyCode: 'JPY',
    currencyName: 'Yen japonés',
    currencySymbol: '¥',
    decimalDigits: 0,
  ),
  Region.switzerland: _RegionInfo(
    displayName: 'Suiza',
    flagEmoji: '🇨🇭',
    countryCode: 'CH',
    numberLocale: 'de_CH',
    currencyCode: 'CHF',
    currencyName: 'Franco suizo',
    currencySymbol: 'CHF',
  ),
};

extension RegionData on Region {
  _RegionInfo get _info => _regionInfo[this]!;

  String get displayName => _info.displayName;

  String get flagEmoji => _info.flagEmoji;

  /// Código de idioma para `Locale` (ISO 639-1). La interfaz siempre está en
  /// español; lo que cambia por región es la moneda y el formato numérico.
  String get languageCode => 'es';

  /// Código de país para `Locale` (ISO 3166-1 alpha-2).
  String get countryCode => _info.countryCode;

  /// Locale de la interfaz (ej. `es_EC`).
  String get localeCode => '${languageCode}_$countryCode';

  /// Locale usado por `NumberFormat` para los montos (ej. `es_MX`, `pt_BR`).
  String get numberLocale => _info.numberLocale;

  String get currencyCode => _info.currencyCode;

  String get currencyName => _info.currencyName;

  String get currencySymbol => _info.currencySymbol;

  /// Decimales con los que se muestra el monto (0 para CLP, PYG y JPY).
  int get decimalDigits => _info.decimalDigits;
}
