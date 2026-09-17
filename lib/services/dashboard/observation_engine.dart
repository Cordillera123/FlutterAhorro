import '../../models/dashboard/dashboard_analysis_context.dart';
import '../../models/dashboard/dashboard_observation.dart';
import 'analyzer_registry.dart';
import 'dashboard_analyzer.dart';

class ObservationEngine {
  final AnalyzerRegistry _registry;

  ObservationEngine(this._registry);

  List<DashboardObservation> run(DashboardAnalysisContext context) {
    return _runAnalyzers<DashboardObservation>(
      _registry.observationAnalyzers,
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
