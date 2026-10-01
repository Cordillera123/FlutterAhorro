import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Paleta compartida del Dashboard Inteligente (alineada con StatsScreen).
class DashboardTheme {
  DashboardTheme._();

  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color successGreen = AppColors.primaryGreen;
  static const Color warningYellow = AppColors.warningYellow;
  static const Color dangerRed = AppColors.dangerRed;
  static const Color primaryPurple = AppColors.primaryPurple;
  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color backgroundLight = AppColors.backgroundLight;
  static const Color cardBackground = Colors.white;
  static const Color borderLight = AppColors.borderLight;

  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: borderColor ?? borderLight),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static Color healthColor(int score) {
    if (score >= 80) return successGreen;
    if (score >= 60) return primaryBlue;
    if (score >= 40) return warningYellow;
    return dangerRed;
  }
}
