import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'app_card.dart';
import 'app_primary_button.dart';

/// Estado vacío estándar: insignia con icono en degradado + título +
/// mensaje + botón opcional. Reemplaza las ~4 variantes (radios, tamaños de
/// insignia y tipografías distintas) que existían antes por pantalla.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final List<Color> iconGradient;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onCta,
    this.iconGradient = const [AppColors.primaryBlue, AppColors.darkBlue],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppCard.standardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: iconGradient),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textMedium,
              height: 1.4,
            ),
          ),
          if (ctaLabel != null && onCta != null) ...[
            const SizedBox(height: 20),
            AppPrimaryButton(label: ctaLabel!, onPressed: onCta),
          ],
        ],
      ),
    );
  }
}
