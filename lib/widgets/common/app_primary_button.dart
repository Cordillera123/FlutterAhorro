import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Botón primario de ancho completo (crear/guardar/confirmar).
///
/// Reemplaza las 5 variantes que existían antes en distintas pantallas de
/// creación (radios de borde y pesos de texto distintos para la misma
/// acción). El look — degradado, icono en insignia translúcida, alto 56,
/// radio 16 — está tomado del botón de Agregar Transacción, que de las
/// cinco versiones originales era la más cuidada.
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool showTrailingArrow;
  final List<Color> gradientColors;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.showTrailingArrow = false,
    this.gradientColors = const [AppColors.primaryBlue, AppColors.darkBlue],
  });

  @override
  Widget build(BuildContext context) {
    // "Deshabilitado" (gris, sin degradado) solo cuando no hay acción y no
    // hay una operación en curso — ej. un formulario incompleto. Mientras
    // `loading` es true el botón conserva su color y muestra un spinner: así
    // no "parpadea" a gris apenas se toca, que era como se veían 5 de los 7
    // botones originales que esto reemplaza.
    final greyedOut = onPressed == null && !loading;
    final canTap = onPressed != null && !loading;
    final contentColor = greyedOut ? AppColors.textMedium : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: greyedOut ? null : LinearGradient(colors: gradientColors),
        color: greyedOut ? AppColors.borderLight : null,
        borderRadius: BorderRadius.circular(16),
        boxShadow: greyedOut
            ? []
            : [
                BoxShadow(
                  color: gradientColors.first.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: canTap ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: contentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: contentColor, size: 20),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: contentColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      if (showTrailingArrow) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: contentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: contentColor,
                            size: 18,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
