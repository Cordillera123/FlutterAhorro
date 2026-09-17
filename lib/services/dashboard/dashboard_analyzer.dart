import '../../models/dashboard/dashboard_analysis_context.dart';

/// Interfaz única para todos los analyzers del dashboard.
abstract class DashboardAnalyzer<T> {
  String get id;
  bool canAnalyze(DashboardAnalysisContext context);
  T? analyze(DashboardAnalysisContext context);
}
