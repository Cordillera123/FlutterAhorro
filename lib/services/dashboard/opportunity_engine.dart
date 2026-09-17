import '../../models/dashboard/dashboard_analysis_context.dart';
import '../../models/dashboard/dashboard_opportunity.dart';
import 'analyzer_registry.dart';
import 'dashboard_analyzer.dart';

class OpportunityEngine {
  final AnalyzerRegistry _registry;

  OpportunityEngine(this._registry);

  List<DashboardOpportunity> run(DashboardAnalysisContext context) {
    return _runAnalyzers<DashboardOpportunity>(
      _registry.opportunityAnalyzers,
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
