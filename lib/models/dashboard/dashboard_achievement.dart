import 'package:flutter/material.dart';
import 'dashboard_enums.dart';
import 'dashboard_message.dart';
import 'message_trace.dart';

/// Logro del usuario. A diferencia del resto de mensajes del dashboard, un
/// logro también existe cuando aún NO se ha conseguido: en ese caso viaja
/// bloqueado y con su progreso, para que la pantalla de Logros pueda mostrar
/// al usuario qué le falta para desbloquearlo.
class DashboardAchievement extends DashboardMessage {
  @override
  final String id;
  @override
  final String title;
  @override
  final String message;
  @override
  final IconData icon;
  @override
  final MessageTrace trace;
  final DateTime? achievedAt;

  /// `true` cuando el usuario ya alcanzó al menos el primer nivel.
  final bool unlocked;

  /// Familia a la que pertenece, usada para agrupar la pantalla de Logros.
  final AchievementGroup group;

  /// Avance hacia el siguiente objetivo, entre 0 y 1. Cuando el logro está
  /// en su nivel máximo vale 1.
  final double progress;

  /// Progreso legible, p. ej. "18 / 30 días".
  final String? progressLabel;

  /// Descripción del siguiente objetivo. `null` si ya está en el nivel máximo.
  final String? nextGoalLabel;

  /// Nivel alcanzado (0 = bloqueado) y nivel máximo disponible.
  final int tier;
  final int maxTier;

  DashboardAchievement({
    required this.id,
    required this.title,
    required this.message,
    required this.icon,
    required this.trace,
    required this.group,
    this.achievedAt,
    this.unlocked = true,
    this.progress = 1.0,
    this.progressLabel,
    this.nextGoalLabel,
    this.tier = 1,
    this.maxTier = 1,
  });

  @override
  MessageCategory get category => MessageCategory.achievement;

  /// Un logro escalonado que ya llegó a su último nivel.
  bool get isMaxed => unlocked && tier >= maxTier;
}
