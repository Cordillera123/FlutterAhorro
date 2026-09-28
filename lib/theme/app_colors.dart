import 'package:flutter/material.dart';

/// Paleta de colores compartida por toda la app (slate/blue/green/purple).
///
/// Antes de esto, cada pantalla/widget redeclaraba su propia copia de estas
/// constantes con `static const Color x = Color(0x...)`, lo que provocaba que
/// el mismo color lógico (ej. el fondo de pantalla) tuviera valores distintos
/// según el archivo. Este archivo es ahora la única fuente de verdad: cada
/// pantalla sigue exponiendo sus propios alias locales (para no tener que
/// tocar cada uso interno), pero todos apuntan aquí.
class AppColors {
  AppColors._();

  // Azul
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);
  static const Color deepBlue = Color(0xFF1E40AF);

  // Verde
  static const Color lightGreen = Color(0xFF34D399);
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color primaryGreen = Color(0xFF059669);
  static const Color darkGreen = Color(0xFF047857);
  static const Color deepGreen = Color(0xFF065F46);

  // Rojo
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color darkRed = Color(0xFFB91C1C);
  static const Color deepRed = Color(0xFF991B1B);

  // Amarillo (advertencias)
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color darkYellow = Color(0xFFD97706);
  // Tono más oscuro usado en texto/íconos sobre fondo warningYellow tenue
  // (ej. el banner "hay cosas que conviene revisar").
  static const Color deepYellow = Color(0xFFB45309);

  // Púrpura
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color darkPurple = Color(0xFF5B21B6);
  static const Color deepPurple = Color(0xFF4C1D95);

  // Acentos adicionales (usados como color de ícono en tarjetas de acción)
  static const Color indigoAccent = Color(0xFF6366F1);
  static const Color cyanAccent = Color(0xFF0891B2);

  // Texto
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  // Fondos y bordes
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundCard = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color emptyGray = Color(0xFFCBD5E1);
}
