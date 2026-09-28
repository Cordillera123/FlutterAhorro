import 'account.dart';
import 'budget.dart';
import 'export_config.dart';
import 'financial_goal.dart';
import 'transaction.dart';

/// DTO que agrupa todos los datos ya filtrados y listos para ser exportados.
///
/// Se construye en [ExportService] y se pasa a los exportadores vía
/// [BaseExporter.generateBytes]. No contiene referencias a servicios
/// ni lógica de acceso a datos.
///
/// Las métricas calculadas (totales, agrupaciones) se exponen como getters
/// para que los exportadores no necesiten recalcularlas.
class ExportData {
  final List<Transaction> transactions;
  final List<Budget> budgets;
  final List<FinancialGoal> goals;

  /// Todas las cuentas del usuario (para resolución de nombres por ID).
  final List<Account> accounts;

  final ExportConfig config;
  final DateTime generatedAt;
  final String appName;
  final String appVersion;

  const ExportData({
    required this.transactions,
    required this.budgets,
    required this.goals,
    required this.accounts,
    required this.config,
    required this.generatedAt,
    this.appName = 'AhorroApp',
    this.appVersion = '1.0.0',
  });

  // ─── Métricas financieras ──────────────────────────────────────────────

  double get totalIncome => transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get totalExpense => transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, t) => sum + t.amount);

  double get netBalance => totalIncome - totalExpense;

  /// Efecto neto de las transferencias sobre las cuentas incluidas en el
  /// reporte (no es ingreso ni gasto, pero sí mueve saldo real).
  double get transferNetDelta => transactions
      .where((t) => t.type == TransactionType.transfer)
      .fold(0.0, (sum, t) => sum + ((t.isTransferOut ?? true) ? -t.amount : t.amount));

  /// Suma de [Account.initialBalance] de las cuentas relevantes según filtros.
  double get totalInitialBalance {
    final relevant = config.filters.hasAccountFilter
        ? accounts.where((a) => config.filters.accountIds.contains(a.id)).toList()
        : accounts;
    return relevant.fold(0.0, (sum, a) => sum + a.initialBalance);
  }

  /// Balance real = saldo inicial + transacciones netas del período filtrado
  /// (incluyendo el efecto de las transferencias entre cuentas).
  double get totalBalance => totalInitialBalance + netBalance + transferNetDelta;

  int get transactionCount => transactions.length;
  int get budgetCount => budgets.length;
  int get goalCount => goals.length;

  // ─── Agrupaciones por categoría ───────────────────────────────────────

  /// Mapa { nombre de categoría → monto total }, ordenado de mayor a menor.
  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (final t in transactions.where(
      (t) => t.type == TransactionType.expense,
    )) {
      final key = t.categoryName;
      map[key] = (map[key] ?? 0.0) + t.amount;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Mapa { nombre de categoría → monto total }, ordenado de mayor a menor.
  Map<String, double> get incomeByCategory {
    final map = <String, double>{};
    for (final t in transactions.where(
      (t) => t.type == TransactionType.income,
    )) {
      final key = t.categoryName;
      map[key] = (map[key] ?? 0.0) + t.amount;
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// Conteo de transacciones por categoría y tipo.
  Map<String, int> get transactionCountByCategory {
    final map = <String, int>{};
    for (final t in transactions) {
      final key = t.categoryName;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  // ─── Helpers de resolución ────────────────────────────────────────────

  /// Devuelve el nombre de la cuenta por su ID.
  /// Si no se encuentra, retorna el ID como fallback.
  String accountNameById(String accountId) {
    try {
      return accounts.firstWhere((a) => a.id == accountId).name;
    } catch (_) {
      return accountId;
    }
  }

  /// Devuelve el emoji de la cuenta por su ID.
  String accountEmojiById(String accountId) {
    try {
      return accounts.firstWhere((a) => a.id == accountId).emoji;
    } catch (_) {
      return '💼';
    }
  }

  // ─── Métricas de metas ────────────────────────────────────────────────

  double get totalGoalTarget =>
      goals.fold(0.0, (sum, g) => sum + g.targetAmount);

  double get totalGoalSaved =>
      goals.fold(0.0, (sum, g) => sum + g.currentAmount);

  double get goalsOverallProgress =>
      totalGoalTarget > 0 ? totalGoalSaved / totalGoalTarget : 0.0;

  // ─── Métricas de presupuestos ─────────────────────────────────────────

  double get totalBudgeted =>
      budgets.fold(0.0, (sum, b) => sum + b.amount);

  int get activeBudgetCount => budgets.where((b) => b.isActive).length;
}
