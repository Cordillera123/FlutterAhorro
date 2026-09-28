import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Fila de lista dentro de una tarjeta (icono/emoji + título + subtítulo +
/// algo a la derecha). Cubre tanto el ítem de Configuración (icono +
/// chevron) como el selector de región (emoji + check), que antes eran
/// implementaciones separadas y casi idénticas por pantalla.
class AppListTile extends StatelessWidget {
  final IconData? icon;
  final String? emoji;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final FontWeight? subtitleFontWeight;
  final VoidCallback? onTap;

  /// Widget a la derecha. Si se omite y hay [onTap], se muestra un chevron.
  final Widget? trailing;
  final bool showDivider;

  const AppListTile({
    super.key,
    this.icon,
    this.emoji,
    this.iconColor = AppColors.primaryBlue,
    required this.title,
    required this.subtitle,
    this.subtitleColor,
    this.subtitleFontWeight,
    this.onTap,
    this.trailing,
    this.showDivider = false,
  }) : assert(
         icon != null || emoji != null,
         'AppListTile necesita un icon o un emoji',
       );

  @override
  Widget build(BuildContext context) {
    final resolvedTrailing =
        trailing ??
        (onTap != null
            ? Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 24,
              )
            : null);

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: emoji != null
                        ? Text(emoji!, style: const TextStyle(fontSize: 22))
                        : Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleColor ?? Colors.grey.shade500,
                            fontWeight: subtitleFontWeight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (resolvedTrailing != null) resolvedTrailing,
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 68, color: Colors.grey.shade200),
      ],
    );
  }
}
