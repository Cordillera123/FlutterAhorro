import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';

/// Botón de "volver" estándar para `AppBar`/`SliverAppBar`.
///
/// Antes existían al menos 4 tratamientos distintos (sin contenedor, chip
/// gris, chip blanco al 15% y chip blanco al 20% de opacidad) y hasta 5
/// íconos de flecha distintos en toda la app. [light] elige entre las dos
/// variantes legítimas que sí tienen sentido: fondo blanco (pantallas
/// planas de Configuración) o fondo de color/degradado (encabezados tipo
/// "hero", como Inicio o Cuentas).
class AppBackButton extends StatelessWidget {
  final bool light;
  final VoidCallback? onPressed;

  const AppBackButton({super.key, this.light = false, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final iconColor = light ? Colors.white : AppColors.textDark;
    final bgColor = light
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.grey.shade100;

    return IconButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        (onPressed ?? () => Navigator.maybePop(context))();
      },
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.arrow_back_rounded, size: 18, color: iconColor),
      ),
    );
  }
}
