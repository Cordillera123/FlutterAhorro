import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Diálogo de confirmación estándar (ej. "¿Eliminar presupuesto?").
///
/// Reemplaza las variantes que existían antes por pantalla: algunas con
/// insignia de icono grande, otras con un simple ícono en línea; algunas
/// coloreando el título de rojo, otras dejándolo en negro. Devuelve `true`
/// si el usuario confirmó, `false`/`null` si canceló o cerró el diálogo —
/// el llamador sigue siendo responsable de ejecutar la acción real.
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Eliminar',
  String cancelLabel = 'Cancelar',
  IconData icon = Icons.delete_rounded,
  Color accentColor = AppColors.dangerRed,

  /// Widget opcional entre el mensaje y los botones (ej. una nota de
  /// advertencia con contexto extra antes de confirmar).
  Widget? extra,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: accentColor.withValues(alpha: 0.1),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(icon, color: accentColor, size: 30),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (extra != null) ...[const SizedBox(height: 12), extra],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogContext, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      cancelLabel,
                      style: const TextStyle(
                        color: AppColors.textMedium,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(dialogContext, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      confirmLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
