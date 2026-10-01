import '../../models/budget.dart';
import '../../models/dashboard/dashboard_analysis_context.dart';
import '../../models/dashboard/dashboard_enums.dart';
import '../../models/dashboard/financial_health_state.dart';
import '../../utils/format_utils.dart';
import 'dashboard_helpers.dart';

/// Calcula el estado financiero con pesos dinámicos redistribuidos.
class FinancialHealthCalculator {
  FinancialHealthState calculate(DashboardAnalysisContext context) {
    final snapshot = context.snapshot;
    final candidates = <_FactorCandidate>[];

    if (snapshot.currentMonthIncome > 0) {
      final rate = snapshot.savingsRate;
      final raw = DashboardHelpers.clampScore((rate / 0.30) * 100);
      candidates.add(
        _FactorCandidate(
          id: 'savings_rate',
          label: 'Tasa de ahorro',
          baseWeight: 0.40,
          rawScore: raw.round(),
          sentiment: rate >= 0.15
              ? HealthFactorSentiment.positive
              : rate >= 0
              ? HealthFactorSentiment.warning
              : HealthFactorSentiment.negative,
          explanation:
              'Ahorras el ${(rate * 100).toStringAsFixed(0)}% de tus ingresos este mes',
          isActive: true,
        ),
      );
    }

    candidates.add(
      _FactorCandidate(
        id: 'consistency',
        label: 'Constancia de registro',
        baseWeight: 0.20,
        rawScore: DashboardHelpers.clampScore(
          (snapshot.daysWithTransactionsLast30 / 30) * 100,
        ).round(),
        sentiment: snapshot.daysWithTransactionsLast30 >= 20
            ? HealthFactorSentiment.positive
            : snapshot.daysWithTransactionsLast30 >= 10
            ? HealthFactorSentiment.neutral
            : HealthFactorSentiment.warning,
        explanation:
            'Registraste movimientos ${snapshot.daysWithTransactionsLast30} de los últimos 30 días',
        isActive: true,
      ),
    );

    if (context.hasActiveBudgets) {
      final safeCount = snapshot.budgetProgress
          .where((p) => p.status == BudgetStatus.safe)
          .length;
      final total = snapshot.budgetProgress.length;
      final raw = total > 0
          ? DashboardHelpers.clampScore((safeCount / total) * 100).round()
          : 50;
      candidates.add(
        _FactorCandidate(
          id: 'budgets',
          label: 'Cumplimiento de presupuestos',
          baseWeight: 0.20,
          rawScore: raw,
          sentiment: raw >= 70
              ? HealthFactorSentiment.positive
              : raw >= 40
              ? HealthFactorSentiment.warning
              : HealthFactorSentiment.negative,
          explanation:
              '$safeCount de $total presupuestos van dentro del límite',
          isActive: true,
        ),
      );
    }

    if (context.hasActiveGoals) {
      final avgProgress =
          context.activeGoals
              .map((g) => g.progressPercentage)
              .fold(0.0, (a, b) => a + b) /
          context.activeGoals.length;
      final raw = DashboardHelpers.clampScore(avgProgress * 100).round();
      candidates.add(
        _FactorCandidate(
          id: 'goals',
          label: 'Progreso en metas',
          baseWeight: 0.20,
          rawScore: raw,
          sentiment: raw >= 60
              ? HealthFactorSentiment.positive
              : raw >= 30
              ? HealthFactorSentiment.neutral
              : HealthFactorSentiment.warning,
          explanation: 'Tus metas activas tienen un $raw% de progreso promedio',
          isActive: true,
        ),
      );
    }

    final active = candidates.where((c) => c.isActive).toList();
    final totalWeight = active.fold(0.0, (sum, c) => sum + c.baseWeight);

    final factors = active.map((c) {
      final normalized = totalWeight > 0
          ? (c.baseWeight / totalWeight).toDouble()
          : 0.0;
      final contribution = (c.rawScore * normalized).toDouble();
      return HealthFactor(
        id: c.id,
        label: c.label,
        baseWeight: c.baseWeight,
        normalizedWeight: normalized,
        rawScore: c.rawScore,
        contributionPoints: contribution,
        sentiment: c.sentiment,
        explanation: c.explanation,
        isActive: c.isActive,
      );
    }).toList();

    final score = factors
        .fold(0.0, (sum, f) => sum + f.contributionPoints)
        .round()
        .clamp(0, 100);

    final level = _levelForScore(score);
    final observations = _buildObservations(context);

    return FinancialHealthState(
      score: score,
      level: level,
      levelLabel: _levelLabel(level),
      factors: factors,
      observations: observations,
      activeFactorCount: factors.length,
      totalFactorCount: 4,
    );
  }

  List<HealthObservation> _buildObservations(DashboardAnalysisContext context) {
    final s = context.snapshot;
    final obs = <HealthObservation>[];

    if (context.hasPreviousMonthData) {
      final expenseGrowth = DashboardHelpers.growthPercentage(
        s.currentMonthExpenses,
        s.previousMonthExpenses,
      );
      if (expenseGrowth < -5) {
        obs.add(
          HealthObservation(
            sentiment: HealthFactorSentiment.positive,
            message:
                'Tus gastos disminuyeron un ${expenseGrowth.abs().toStringAsFixed(0)}% este mes',
          ),
        );
      } else if (expenseGrowth > 5) {
        obs.add(
          HealthObservation(
            sentiment: HealthFactorSentiment.warning,
            message:
                'Tus gastos aumentaron un ${expenseGrowth.toStringAsFixed(0)}% este mes',
          ),
        );
      }

      final incomeGrowth = DashboardHelpers.growthPercentage(
        s.currentMonthIncome,
        s.previousMonthIncome,
      );
      if (incomeGrowth > 5) {
        obs.add(
          HealthObservation(
            sentiment: HealthFactorSentiment.positive,
            message:
                'Tus ingresos crecieron un ${incomeGrowth.toStringAsFixed(0)}% respecto al mes anterior',
          ),
        );
      } else if (incomeGrowth < -5) {
        obs.add(
          HealthObservation(
            sentiment: HealthFactorSentiment.warning,
            message:
                'Tus ingresos bajaron un ${incomeGrowth.abs().toStringAsFixed(0)}% respecto al mes anterior',
          ),
        );
      }
    }

    if (s.currentMonthSavings > 0) {
      obs.add(
        HealthObservation(
          sentiment: HealthFactorSentiment.positive,
          message:
              'Este mes llevas ${FormatUtils.formatMoney(s.currentMonthSavings)} de ahorro (flujo)',
        ),
      );
    }

    return obs;
  }

  FinancialHealthLevel _levelForScore(int score) {
    if (score >= 80) return FinancialHealthLevel.excellent;
    if (score >= 60) return FinancialHealthLevel.good;
    if (score >= 40) return FinancialHealthLevel.fair;
    return FinancialHealthLevel.needsAttention;
  }

  String _levelLabel(FinancialHealthLevel level) {
    switch (level) {
      case FinancialHealthLevel.excellent:
        return 'Excelente';
      case FinancialHealthLevel.good:
        return 'Buena';
      case FinancialHealthLevel.fair:
        return 'Regular';
      case FinancialHealthLevel.needsAttention:
        return 'Necesita atención';
    }
  }
}

class _FactorCandidate {
  final String id;
  final String label;
  final double baseWeight;
  final int rawScore;
  final HealthFactorSentiment sentiment;
  final String explanation;
  final bool isActive;

  _FactorCandidate({
    required this.id,
    required this.label,
    required this.baseWeight,
    required this.rawScore,
    required this.sentiment,
    required this.explanation,
    required this.isActive,
  });
}
