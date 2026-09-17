import 'package:flutter/material.dart';
import '../../models/dashboard/dashboard_achievement.dart';
import 'dashboard_theme.dart';
import 'message_trace_sheet.dart';

/// Tarjeta completa de un logro: celebra los conseguidos y muestra el camino
/// de los pendientes con una barra de progreso.
class AchievementCard extends StatelessWidget {
  final DashboardAchievement achievement;

  const AchievementCard({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final accent = unlocked
        ? DashboardTheme.warningYellow
        : DashboardTheme.textMedium;

    return GestureDetector(
      onTap: () => MessageTraceSheet.show(
        context,
        title: achievement.title,
        trace: achievement.trace,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: DashboardTheme.cardDecoration(
          borderColor: unlocked
              ? DashboardTheme.warningYellow.withValues(alpha: 0.35)
              : DashboardTheme.borderLight,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: accent.withValues(alpha: unlocked ? 0.14 : 0.08),
                  ),
                  child: Icon(
                    unlocked ? achievement.icon : Icons.lock_outline_rounded,
                    color: accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              achievement.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: unlocked
                                    ? DashboardTheme.textDark
                                    : DashboardTheme.textMedium,
                              ),
                            ),
                          ),
                          if (achievement.maxTier > 1) _tierBadge(unlocked),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.message,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: DashboardTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (achievement.progressLabel != null) ...[
              const SizedBox(height: 14),
              _progressBar(accent),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      achievement.nextGoalLabel == null
                          ? 'Nivel máximo alcanzado'
                          : 'Siguiente: ${achievement.nextGoalLabel}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: DashboardTheme.textMedium,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    achievement.progressLabel!,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tierBadge(bool unlocked) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (unlocked
                ? DashboardTheme.warningYellow
                : DashboardTheme.textMedium)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Nivel ${achievement.tier}/${achievement.maxTier}',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: unlocked
              ? DashboardTheme.warningYellow
              : DashboardTheme.textMedium,
        ),
      ),
    );
  }

  Widget _progressBar(Color accent) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: achievement.progress,
        minHeight: 7,
        backgroundColor: DashboardTheme.borderLight,
        valueColor: AlwaysStoppedAnimation<Color>(accent),
      ),
    );
  }
}

/// Trofeo compacto para la tira horizontal del Inicio. Prioriza la
/// celebración: icono grande, título corto y nada de datos densos.
class AchievementChip extends StatelessWidget {
  final DashboardAchievement achievement;
  final VoidCallback? onTap;

  const AchievementChip({
    super.key,
    required this.achievement,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = DashboardTheme.warningYellow;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 104,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.22),
                    accent.withValues(alpha: 0.10),
                  ],
                ),
              ),
              child: Icon(achievement.icon, color: accent, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              achievement.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: DashboardTheme.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
