import 'package:flutter/material.dart';
import '../../../../models/dashboard/dashboard_achievement.dart';
import '../../../../models/dashboard/dashboard_analysis_context.dart';
import '../../../../models/dashboard/dashboard_enums.dart';
import '../../../../models/dashboard/message_trace.dart';
import '../../../../utils/format_utils.dart';
import '../../dashboard_analyzer.dart';

/// Cómo se presenta el valor de un logro al usuario.
enum AchievementValueFormat { count, money, percent }

/// Un nivel dentro de un logro escalonado.
class AchievementTier {
  final double threshold;
  final String title;

  /// Objetivo en lenguaje natural: "30 días seguidos".
  final String goal;

  /// Mensaje de celebración. `{v}` se reemplaza por el valor alcanzado.
  final String celebration;

  const AchievementTier({
    required this.threshold,
    required this.title,
    required this.goal,
    required this.celebration,
  });
}

/// Base de los logros con niveles progresivos.
///
/// Emite siempre un logro: si el usuario no alcanzó el primer nivel viaja
/// bloqueado con su progreso, y si ya superó alguno viaja desbloqueado en el
/// nivel más alto conseguido, mostrando el avance hacia el siguiente. Así el
/// usuario siempre ve un objetivo a la vista en lugar de una lista estática.
abstract class TieredAchievementAnalyzer
    implements DashboardAnalyzer<DashboardAchievement> {
  const TieredAchievementAnalyzer();

  /// Tolerancia para comparar valores monetarios en coma flotante.
  static const double _epsilon = 0.005;

  AchievementGroup get group;
  IconData get icon;

  /// Niveles ordenados de menor a mayor exigencia.
  List<AchievementTier> get tiers;

  /// Unidad mostrada junto al progreso ("días", "movimientos"...).
  String get unit => '';

  AchievementValueFormat get format => AchievementValueFormat.count;

  String get traceReason;
  String get traceFormula;

  /// Valor actual del usuario para este logro.
  double currentValue(DashboardAnalysisContext context);

  @override
  bool canAnalyze(DashboardAnalysisContext context) => true;

  @override
  DashboardAchievement? analyze(DashboardAnalysisContext context) {
    final value = currentValue(context);

    var tierIndex = -1;
    for (var i = 0; i < tiers.length; i++) {
      if (value + _epsilon >= tiers[i].threshold) tierIndex = i;
    }

    final unlocked = tierIndex >= 0;
    final reached = unlocked ? tiers[tierIndex] : null;
    final target = unlocked
        ? (tierIndex + 1 < tiers.length ? tiers[tierIndex + 1] : null)
        : tiers.first;

    final progress = target == null
        ? 1.0
        : (value / target.threshold).clamp(0.0, 1.0).toDouble();

    return DashboardAchievement(
      id: id,
      title: (reached ?? tiers.first).title,
      message: reached != null
          ? reached.celebration.replaceAll('{v}', _format(value))
          : 'Desbloquéalo al llegar a ${tiers.first.goal}',
      icon: icon,
      group: group,
      unlocked: unlocked,
      progress: progress,
      progressLabel: target == null
          ? null
          : '${_format(value)} / ${_format(target.threshold)}'
                '${unit.isEmpty ? '' : ' $unit'}',
      nextGoalLabel: target?.goal,
      tier: tierIndex + 1,
      maxTier: tiers.length,
      trace: MessageTrace(
        reason: traceReason,
        inputs: [
          DataPoint(label: 'Tu valor actual', value: _format(value)),
          if (target != null)
            DataPoint(
              label: 'Siguiente nivel',
              value: _format(target.threshold),
            ),
          DataPoint(
            label: 'Nivel',
            value: '${tierIndex + 1} de ${tiers.length}',
          ),
        ],
        formula: traceFormula,
      ),
    );
  }

  String _format(double value) {
    switch (format) {
      case AchievementValueFormat.money:
        return FormatUtils.formatMoney(value);
      case AchievementValueFormat.percent:
        return '${value.toStringAsFixed(0)}%';
      case AchievementValueFormat.count:
        return value.toStringAsFixed(0);
    }
  }
}

/// Base de los logros de un solo nivel (se consiguen o no).
abstract class SingleAchievementAnalyzer
    implements DashboardAnalyzer<DashboardAchievement> {
  const SingleAchievementAnalyzer();

  AchievementGroup get group;
  IconData get icon;
  String get title;

  /// Qué debe hacer el usuario para conseguirlo.
  String get lockedHint;

  String get traceReason;
  String get traceFormula;

  bool isUnlocked(DashboardAnalysisContext context);

  /// Solo se invoca cuando el logro está desbloqueado.
  String unlockedMessage(DashboardAnalysisContext context);

  DateTime? achievedAt(DashboardAnalysisContext context) => null;

  List<DataPoint> traceInputs(DashboardAnalysisContext context) => const [];

  @override
  bool canAnalyze(DashboardAnalysisContext context) => true;

  @override
  DashboardAchievement? analyze(DashboardAnalysisContext context) {
    final unlocked = isUnlocked(context);
    return DashboardAchievement(
      id: id,
      title: title,
      message: unlocked ? unlockedMessage(context) : lockedHint,
      icon: icon,
      group: group,
      unlocked: unlocked,
      progress: unlocked ? 1.0 : 0.0,
      progressLabel: null,
      nextGoalLabel: unlocked ? null : lockedHint,
      achievedAt: unlocked ? achievedAt(context) : null,
      trace: MessageTrace(
        reason: traceReason,
        inputs: traceInputs(context),
        formula: traceFormula,
      ),
    );
  }
}
