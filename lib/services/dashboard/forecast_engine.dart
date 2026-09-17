import '../../models/dashboard/dashboard_analysis_context.dart';
import '../../models/dashboard/dashboard_forecast.dart';
import 'analyzer_registry.dart';
import 'dashboard_analyzer.dart';

class ForecastEngine {
  final AnalyzerRegistry _registry;

  ForecastEngine(this._registry);

  List<DashboardForecast> run(DashboardAnalysisContext context) {
    return _runAnalyzers<DashboardForecast>(
      _registry.forecastAnalyzers,
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
