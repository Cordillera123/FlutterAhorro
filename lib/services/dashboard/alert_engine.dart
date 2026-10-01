import '../../models/dashboard/dashboard_alert.dart';
import '../../models/dashboard/dashboard_analysis_context.dart';
import 'analyzer_registry.dart';
import 'dashboard_analyzer.dart';

class AlertEngine {
  final AnalyzerRegistry _registry;

  AlertEngine(this._registry);

  List<DashboardAlert> run(DashboardAnalysisContext context) {
    return _runAnalyzers<DashboardAlert>(_registry.alertAnalyzers, context);
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
