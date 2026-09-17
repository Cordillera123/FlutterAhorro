import 'dashboard_enums.dart';

class HealthFactor {
  final String id;
  final String label;
  final double baseWeight;
  final double normalizedWeight;
  final int rawScore;
  final double contributionPoints;
  final HealthFactorSentiment sentiment;
  final String explanation;
  final bool isActive;

  const HealthFactor({
    required this.id,
    required this.label,
    required this.baseWeight,
    required this.normalizedWeight,
    required this.rawScore,
    required this.contributionPoints,
    required this.sentiment,
    required this.explanation,
    required this.isActive,
  });
}

class HealthObservation {
  final HealthFactorSentiment sentiment;
  final String message;

  const HealthObservation({
    required this.sentiment,
    required this.message,
  });
}

class FinancialHealthState {
  final int score;
  final FinancialHealthLevel level;
  final String levelLabel;
  final List<HealthFactor> factors;
  final List<HealthObservation> observations;
  final int activeFactorCount;
  final int totalFactorCount;

  const FinancialHealthState({
    required this.score,
    required this.level,
    required this.levelLabel,
    required this.factors,
    required this.observations,
    required this.activeFactorCount,
    required this.totalFactorCount,
  });
}
