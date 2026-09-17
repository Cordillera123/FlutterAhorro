import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Paleta y helpers visuales compartidos por los widgets del Calendario
/// Financiero. Centraliza los colores del proyecto para no duplicarlos en cada
/// widget del módulo (mantiene consistencia con el resto de la app).
class CalendarTheme {
  const CalendarTheme._();

  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color deepBlue = AppColors.deepBlue;

  static const Color incomeGreen = AppColors.primaryGreen;
  static const Color expenseRed = AppColors.dangerRed;

  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color textLight = AppColors.textLight;

  static const Color backgroundLight = AppColors.backgroundLight;
  static const Color backgroundCard = AppColors.backgroundCard;
  static const Color borderLight = AppColors.borderLight;

  /// Color para días sin movimientos (indicador ⚪).
  static const Color emptyGray = AppColors.emptyGray;
}
