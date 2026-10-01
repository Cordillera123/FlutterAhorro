// Enums compartidos del módulo Dashboard Inteligente.

enum MessageCategory { alert, observation, forecast, opportunity, achievement }

enum ObservationDimension {
  trend,
  pattern,
  habit,
  category,
  budget,
  goal,
  monthly,
}

enum HealthFactorSentiment { positive, neutral, warning, negative }

enum FinancialHealthLevel { excellent, good, fair, needsAttention }

enum PredictionConfidence { high, medium, low }

enum AlertSeverity { critical, warning }

/// Familias de logros. Sirven para agrupar la pantalla de Logros y para que
/// el usuario identifique en qué área está progresando.
enum AchievementGroup {
  firstSteps,
  consistency,
  savings,
  budgets,
  goals,
  growth,
}

extension AchievementGroupLabel on AchievementGroup {
  String get label {
    switch (this) {
      case AchievementGroup.firstSteps:
        return 'Primeros pasos';
      case AchievementGroup.consistency:
        return 'Constancia';
      case AchievementGroup.savings:
        return 'Ahorro';
      case AchievementGroup.budgets:
        return 'Presupuestos';
      case AchievementGroup.goals:
        return 'Metas';
      case AchievementGroup.growth:
        return 'Crecimiento';
    }
  }

  String get emoji {
    switch (this) {
      case AchievementGroup.firstSteps:
        return '🌱';
      case AchievementGroup.consistency:
        return '🔥';
      case AchievementGroup.savings:
        return '💰';
      case AchievementGroup.budgets:
        return '🛡️';
      case AchievementGroup.goals:
        return '🎯';
      case AchievementGroup.growth:
        return '📈';
    }
  }
}
