import 'package:flutter/material.dart';

/// Paleta compartida del Dashboard Inteligente (alineada con StatsScreen).
class DashboardTheme {
  DashboardTheme._();

  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color cardBackground = Colors.white;
  static const Color borderLight = Color(0xFFE5E7EB);

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
