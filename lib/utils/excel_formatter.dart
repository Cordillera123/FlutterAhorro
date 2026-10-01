import 'package:excel/excel.dart';

/// Paleta de colores y estilos de celda reutilizables para reportes Excel.
///
/// Clase utilitaria estática: no instanciar.
/// Los colores están en formato AARRGGBB (8 dígitos hex, canal alfa al inicio).
class ExcelFormatter {
  ExcelFormatter._();

  // ─── Paleta de colores (formato AARRGGBB) ─────────────────────────────

  static final ExcelColor _colorDarkHeader = ExcelColor.fromHexString(
    'FF1F2937',
  );
  static final ExcelColor _colorMediumHeader = ExcelColor.fromHexString(
    'FF374151',
  );
  static final ExcelColor _colorSubHeader = ExcelColor.fromHexString(
    'FF6B7280',
  );
  static final ExcelColor _colorIncome = ExcelColor.fromHexString('FF059669');
  static final ExcelColor _colorExpense = ExcelColor.fromHexString('FFDC2626');
  static final ExcelColor _colorTransfer = ExcelColor.fromHexString('FF3B82F6');
  static final ExcelColor _colorWarning = ExcelColor.fromHexString('FFD97706');
  static final ExcelColor _colorAltRow = ExcelColor.fromHexString('FFF9FAFB');
  static final ExcelColor _colorWhite = ExcelColor.fromHexString('FFFFFFFF');
  static final ExcelColor _colorBlack = ExcelColor.fromHexString('FF1F2937');
  static final ExcelColor _colorPosBalance = ExcelColor.fromHexString(
    'FF065F46',
  );
  static final ExcelColor _colorNegBalance = ExcelColor.fromHexString(
    'FF991B1B',
  );

  // ─── Estilos de celda ─────────────────────────────────────────────────

  /// Título principal de hoja (fila 1, fondo oscuro, texto blanco, negrita).
  static CellStyle get titleStyle => CellStyle(
    bold: true,
    fontSize: 14,
    fontColorHex: _colorWhite,
    backgroundColorHex: _colorDarkHeader,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  /// Encabezado de columna o sección (fondo gris oscuro, texto blanco).
  static CellStyle get headerStyle => CellStyle(
    bold: true,
    fontSize: 10,
    fontColorHex: _colorWhite,
    backgroundColorHex: _colorMediumHeader,
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  /// Sub-encabezado de bloque (fondo gris medio, texto blanco, izquierda).
  static CellStyle get subHeaderStyle => CellStyle(
    bold: true,
    fontSize: 10,
    fontColorHex: _colorWhite,
    backgroundColorHex: _colorSubHeader,
    horizontalAlign: HorizontalAlign.Left,
    verticalAlign: VerticalAlign.Center,
  );

  /// Etiqueta de campo (negrita, texto oscuro, izquierda).
  static CellStyle get labelStyle => CellStyle(
    bold: true,
    fontSize: 10,
    fontColorHex: _colorBlack,
    horizontalAlign: HorizontalAlign.Left,
  );

  /// Valor de dato (texto oscuro, izquierda).
  static CellStyle get valueStyle => CellStyle(
    fontSize: 10,
    fontColorHex: _colorBlack,
    horizontalAlign: HorizontalAlign.Left,
  );

  /// Valor numérico (texto oscuro, derecha).
  static CellStyle get valueRightStyle => CellStyle(
    fontSize: 10,
    fontColorHex: _colorBlack,
    horizontalAlign: HorizontalAlign.Right,
  );

  /// Fila alterna — alineación izquierda (fondo gris muy claro).
  static CellStyle get altRowStyle => CellStyle(
    fontSize: 10,
    fontColorHex: _colorBlack,
    backgroundColorHex: _colorAltRow,
    horizontalAlign: HorizontalAlign.Left,
  );

  /// Fila alterna — alineación derecha (fondo gris muy claro).
  static CellStyle get altRowRightStyle => CellStyle(
    fontSize: 10,
    fontColorHex: _colorBlack,
    backgroundColorHex: _colorAltRow,
    horizontalAlign: HorizontalAlign.Right,
  );

  /// Monto de ingreso (verde, negrita, derecha).
  static CellStyle get incomeAmountStyle => CellStyle(
    bold: true,
    fontSize: 10,
    fontColorHex: _colorIncome,
    horizontalAlign: HorizontalAlign.Right,
  );

  /// Monto de gasto (rojo, negrita, derecha).
  static CellStyle get expenseAmountStyle => CellStyle(
    bold: true,
    fontSize: 10,
    fontColorHex: _colorExpense,
    horizontalAlign: HorizontalAlign.Right,
  );

  /// Metadatos: fecha de generación, notas (itálica, gris, pequeño).
  static CellStyle get metadataStyle => CellStyle(
    italic: true,
    fontSize: 9,
    fontColorHex: _colorSubHeader,
    horizontalAlign: HorizontalAlign.Left,
  );

  // ─── Estilos dinámicos ────────────────────────────────────────────────

  /// Monto con color semántico (verde/rojo/azul) y soporte de fila alterna.
  /// [isTransfer] tiene prioridad sobre [isIncome] cuando ambos aplicarían.
  static CellStyle amountStyle({
    required bool isIncome,
    required bool isAltRow,
    bool isTransfer = false,
  }) {
    final ExcelColor color;
    if (isTransfer) {
      color = _colorTransfer;
    } else if (isIncome) {
      color = _colorIncome;
    } else {
      color = _colorExpense;
    }
    return CellStyle(
      fontSize: 10,
      fontColorHex: color,
      backgroundColorHex: isAltRow ? _colorAltRow : _colorWhite,
      horizontalAlign: HorizontalAlign.Right,
    );
  }

  /// Balance neto: verde si positivo, rojo si negativo.
  static CellStyle balanceStyle({required bool isPositive}) {
    return CellStyle(
      bold: true,
      fontSize: 10,
      fontColorHex: isPositive ? _colorPosBalance : _colorNegBalance,
      horizontalAlign: HorizontalAlign.Right,
    );
  }

  /// Porcentaje con semáforo de color (verde/ámbar/rojo según umbral).
  static CellStyle percentageStyle(double percentage) {
    final ExcelColor color;
    if (percentage >= 1.0) {
      color = _colorExpense;
    } else if (percentage >= 0.8) {
      color = _colorWarning;
    } else {
      color = _colorIncome;
    }
    return CellStyle(
      fontSize: 10,
      fontColorHex: color,
      horizontalAlign: HorizontalAlign.Center,
    );
  }

  // ─── Helpers de formato de texto ──────────────────────────────────────

  /// Moneda con separador de miles: `$1,234.56`.
  static String formatMoney(double amount) {
    if (!amount.isFinite) return '\$0.00';
    final abs = amount.abs();
    final formatted = abs.toStringAsFixed(2);
    final parts = formatted.split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
    }
    return '\$${buffer.toString()}.$decPart';
  }

  /// Moneda con signo explícito: `+$1,234.56` / `-$1,234.56`.
  static String formatMoneyWithSign(double amount) {
    final sign = amount >= 0 ? '+' : '-';
    return '$sign${formatMoney(amount.abs())}';
  }

  /// Fecha: `DD/MM/YYYY`.
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  /// Fecha y hora: `DD/MM/YYYY HH:mm`.
  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  /// Porcentaje con un decimal: `87.3%`.
  static String formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}
