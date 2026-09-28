import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Etiqueta pequeña de sección (ej. "Personalización", "Este mes").
///
/// Estandariza los distintos estilos de encabezado de sección que existían
/// antes en cada pantalla (algunos en mayúsculas, otros no; distinto
/// tamaño/peso de letra).
class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textMedium,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
