import '../../models/dashboard/dashboard_achievement.dart';
import '../../models/dashboard/dashboard_analysis_context.dart';
import 'analyzer_registry.dart';
import 'dashboard_analyzer.dart';

class AchievementEngine {
  final AnalyzerRegistry _registry;

  AchievementEngine(this._registry);

  List<DashboardAchievement> run(DashboardAnalysisContext context) {
    return _runAnalyzers<DashboardAchievement>(
      _registry.achievementAnalyzers,
      context,
    );
  }

  List<T> _runAnalyzers<T>(
    List<DashboardAnalyzer<T>> analyzers,
    DashboardAnalysisContext context,
  ) {
    final results = <T>[];
    for (final analyzer in analyzers) {
      if (!analyzer.canAnalyze(context)) continue;
      final result = analyzer.analyze(context);
      if (result != null) results.add(result);
    }
    return results;
  }
}
