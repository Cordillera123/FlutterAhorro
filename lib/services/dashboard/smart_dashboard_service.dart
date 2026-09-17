import '../../models/dashboard/dashboard_module_config.dart';
import '../../models/dashboard/smart_dashboard_data.dart';
import '../../services/account_service.dart';
import '../../services/budget_service.dart';
import '../../services/goal_service.dart';
import '../../services/transaction_service.dart';
import 'dashboard_orchestrator.dart';

/// Servicio principal del Dashboard Inteligente.
/// Gestiona caché, invalidación y API pública.
class SmartDashboardService {
  static final SmartDashboardService _instance =
      SmartDashboardService._internal();
  factory SmartDashboardService() => _instance;

  SmartDashboardService._internal() {
    _transactionService.addListener(_invalidateCache);
    _accountService.addListener(_invalidateCache);
    _goalService.addListener(_invalidateCache);
  }

  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();
  final GoalService _goalService = GoalService();
  final BudgetService _budgetService = BudgetService();
  final DashboardOrchestrator _orchestrator = DashboardOrchestrator.create();

  SmartDashboardData? _cachedData;
  String? _cacheKey;

  // Controla la carga inicial desde persistencia. Se marca en `true` de forma
  // SÍNCRONA (antes de cualquier `await`) para evitar reentradas: cada
  // `loadX()` dispara `notifyListeners()` en su servicio, lo cual reactiva los
  // listeners que invalidan/recalculan el dashboard (incluyendo consumidores
  // como HomeScreen). Sin esta guarda se produce un ciclo infinito:
  // cargar -> notificar -> recalcular dashboard -> volver a cargar -> ...
  // No es necesario recargar en cada llamada: TransactionService, BudgetService
  // y GoalService son singletons cuyos métodos de mutación ya actualizan la
  // lista en memoria directamente, por lo que una sola carga inicial basta.
  bool _loaded = false;

  void _invalidateCache() {
    _cachedData = null;
    _cacheKey = null;
  }

  String _buildCacheKey() {
    final accountId = _accountService.activeAccountId;
    final txs = _transactionService.transactions;
    if (txs.isEmpty) return '${accountId}_empty';
    final last = txs.first;
    return '${accountId}_${txs.length}_${last.id}_${last.amount}_${last.date.millisecondsSinceEpoch}';
  }

  /// Obtiene los datos del dashboard, usando caché cuando es válida.
  Future<SmartDashboardData> getDashboardData({
    DashboardModuleConfig config = DashboardModuleConfig.production,
    bool forceRefresh = false,
  }) async {
    if (!_loaded) {
      _loaded = true; // marcar antes de esperar: evita reentradas en cascada
      await _transactionService.loadTransactions();
      await _budgetService.loadBudgets();
      await _goalService.loadGoals();
    }

    final key = _buildCacheKey();
    if (!forceRefresh && _cachedData != null && _cacheKey == key) {
      return _cachedData!;
    }

    final data = _orchestrator.run(config: config);
    _cachedData = data;
    _cacheKey = key;
    return data;
  }

  void clearCache() => _invalidateCache();

  void dispose() {
    _transactionService.removeListener(_invalidateCache);
    _accountService.removeListener(_invalidateCache);
    _goalService.removeListener(_invalidateCache);
  }
}
