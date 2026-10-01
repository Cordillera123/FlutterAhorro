import 'package:flutter/material.dart';

/// Texto de monto (o porcentaje) de una sola línea que se reduce para caber
/// en el espacio disponible en vez de desbordar o partirse en dos líneas.
///
/// Mantiene el tamaño de fuente pedido mientras quepa; solo si el valor es
/// demasiado largo (p. ej. `20.000.032,45 $` en una tarjeta angosta) lo
/// escala hacia abajo. Debe colocarse en un padre con ancho acotado
/// (`Expanded`, `Flexible`, una celda de `Row` con `Expanded`, etc.).
class AmountText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Alignment alignment;
  final TextAlign? textAlign;

  const AmountText(
    this.text, {
    super.key,
    this.style,
    this.alignment = Alignment.centerLeft,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        softWrap: false,
        textAlign: textAlign,
      ),
    );
  }
}
