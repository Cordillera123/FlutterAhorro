import 'package:flutter/widgets.dart';

/// Marca todo el árbol de widgets para reconstruirse en el siguiente cuadro.
///
/// Los montos se escriben con `FormatUtils.formatMoney`, que lee la moneda
/// activa directamente y no depende de ningún widget heredado. Por eso, al
/// cambiar de moneda las pantallas ya construidas (Inicio, Historial, ...)
/// no se enterarían solas y seguirían mostrando el símbolo anterior hasta
/// rehacerse. Esto las refresca todas sin perder la navegación ni el estado
/// de cada pantalla.
///
/// Es una operación poco frecuente (solo al cambiar región/moneda).
void rebuildEntireApp() {
  final root = WidgetsBinding.instance.rootElement;
  if (root == null) return;

  void markDirty(Element element) {
    element.markNeedsBuild();
    element.visitChildren(markDirty);
  }

  root.visitChildren(markDirty);
}
