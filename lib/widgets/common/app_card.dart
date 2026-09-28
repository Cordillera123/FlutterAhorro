import 'package:flutter/material.dart';

/// Tarjeta blanca redondeada con la sombra estándar de la app.
///
/// Antes de esto, cada pantalla reimplementaba su propia versión de "tarjeta
/// blanca con sombra" con ligeras variaciones (radio, opacidad, blur) que
/// terminaban viéndose casi -pero no exactamente- igual entre pantallas.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.color = Colors.white,
  });

  /// Sombra estándar, expuesta para los casos que necesiten componerla a
  /// mano (ej. [AppEmptyState]) en vez de envolver el contenido con
  /// [AppCard] directamente.
  static List<BoxShadow> get standardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: standardShadow,
      ),
      child: child,
    );
  }
}
