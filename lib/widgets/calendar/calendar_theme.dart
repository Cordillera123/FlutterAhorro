import 'package:flutter/material.dart';

/// Paleta y helpers visuales compartidos por los widgets del Calendario
/// Financiero. Centraliza los colores del proyecto para no duplicarlos en cada
/// widget del módulo (mantiene consistencia con el resto de la app).
class CalendarTheme {
  const CalendarTheme._();

  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);
  static const Color deepBlue = Color(0xFF1E40AF);

  static const Color incomeGreen = Color(0xFF059669);
  static const Color expenseRed = Color(0xFFDC2626);

  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundCard = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFE5E7EB);

  /// Color para días sin movimientos (indicador ⚪).
  static const Color emptyGray = Color(0xFFCBD5E1);
}
