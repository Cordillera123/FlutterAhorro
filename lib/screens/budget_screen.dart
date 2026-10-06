import 'package:flutter/material.dart';
import 'tab_add_action.dart';
import 'package:flutter/services.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/budget_service.dart';
import '../services/category_service.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../utils/format_utils.dart';
import 'create_budget_screen.dart';
import '../theme/app_colors.dart';
import '../utils/app_log.dart';
import '../widgets/common/common.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen>
    with TickerProviderStateMixin
    implements TabAddActionHost {
  final BudgetService _budgetService = BudgetService();
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();
  bool _isLoading = true;
  BudgetSummary? _summary;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  // Colores consistentes
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color deepBlue = AppColors.deepBlue;
  static const Color successGreen = AppColors.primaryGreen;
  static const Color warningYellow = AppColors.warningYellow;
  static const Color dangerRed = AppColors.dangerRed;
  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color backgroundLight = AppColors.backgroundLight;
  static const Color backgroundCard = AppColors.backgroundCard;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
    _accountService.addListener(_onAccountChanged);
    // Lo gastado se calcula desde las transacciones: si una se crea, edita o
    // elimina mientras esta pantalla está abierta, se recalcula al instante.
    _transactionService.addListener(_onTransactionsChanged);
  }

  void _onAccountChanged() {
    if (mounted) {
      _loadData();
    }
  }

  // Solo recalcula con lo que ya está en memoria (no recarga del disco:
  // _loadData llama a loadTransactions, que notifica y entraría en bucle).
  void _onTransactionsChanged() {
    if (!mounted || _isLoading) return;
    setState(() => _summary = _budgetService.getBudgetSummary());
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
  }

  Future<void> _loadData() async {
    await _budgetService.loadBudgets();
    await _transactionService.loadTransactions();
    _summary = _budgetService.getBudgetSummary();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  Future<void> _refreshData() async {
    try {
      HapticFeedback.lightImpact();
      await _loadData();
    } catch (e) {
      AppLog.error('Error al refrescar presupuestos', e);
      // Si hay error, al menos intentar cargar lo básico
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _accountService.removeListener(_onAccountChanged);
    _transactionService.removeListener(_onTransactionsChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundLight,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [primaryBlue, darkBlue],
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Cargando presupuestos...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundLight,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: primaryBlue,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildModernAppBar(),
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeInAnimation.value,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          8,
                          20,
                          120,
                        ), // Espacio para el botón flotante
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryCard(),
                            const SizedBox(height: 24),
                            _buildBudgetHealthIndicator(),
                            const SizedBox(height: 28),
                            _buildQuickActions(),
                            const SizedBox(height: 28),
                            _buildBudgetsList(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // FAB eliminado completamente
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: backgroundLight,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryBlue, darkBlue, deepBlue],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mis Presupuestos',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Controla tus gastos de manera inteligente',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE5E7EB).withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [primaryBlue, darkBlue],
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen de Presupuestos',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${_summary?.totalBudgets ?? 0} presupuestos activos',
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (_summary?.isNearLimit ?? false)
                                ? warningYellow.withOpacity(0.1)
                                : primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_summary?.isNearLimit ?? false)
                                  ? warningYellow.withOpacity(0.3)
                                  : primaryBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${_summary?.totalBudgets ?? 0}/15',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (_summary?.isNearLimit ?? false)
                                  ? warningYellow
                                  : primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  'Presupuesto',
                  FormatUtils.formatMoney(_summary?.totalBudgeted ?? 0),
                  primaryBlue,
                  Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryMetric(
                  'Gastado',
                  FormatUtils.formatMoney(_summary?.totalSpent ?? 0),
                  dangerRed,
                  Icons.trending_down_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(
    String title,
    String amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetHealthIndicator() {
    final isHealthy = _summary?.overallHealthy ?? true;
    final exceededCount = _summary?.exceededCount ?? 0;
    final warningCount = _summary?.warningCount ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(
          color: isHealthy
              ? successGreen.withOpacity(0.2)
              : warningYellow.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isHealthy ? successGreen : warningYellow).withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isHealthy ? successGreen : warningYellow).withOpacity(
                0.1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isHealthy ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: isHealthy ? successGreen : warningYellow,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'Presupuestos Saludables' : 'Atención Requerida',
                  style: TextStyle(
                    color: isHealthy ? successGreen : warningYellow,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isHealthy
                      ? 'Todos tus presupuestos están bajo control'
                      : '$exceededCount excedidos, $warningCount en advertencia',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Acciones Rápidas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                title: 'Presupuesto Mensual',
                subtitle: 'Para gastos del mes',
                icon: Icons.calendar_month_rounded,
                gradientColors: const [primaryBlue, darkBlue],
                onTap: () {
                  HapticFeedback.lightImpact();
                  _createQuickBudget(BudgetPeriod.monthly);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionCard(
                title: 'Presupuesto Semanal',
                subtitle: 'Control semanal',
                icon: Icons.date_range_rounded,
                gradientColors: const [successGreen, AppColors.darkGreen],
                onTap: () {
                  HapticFeedback.lightImpact();
                  _createQuickBudget(BudgetPeriod.weekly);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBudgetsList() {
    // CORREGIDO: Mostrar todos los presupuestos activos (incluyendo pausados)
    final budgets = _budgetService.budgets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Mis Presupuestos', // CAMBIAR por: 'Todos los Presupuestos'
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textDark,
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // En la misma sección, cambiar el container del contador:
            if (budgets.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryBlue.withOpacity(0.2)),
                ),
                child: Text(
                  // CAMBIAR ESTA LÍNEA:
                  '${_budgetService.activeBudgets.length} activos / ${budgets.length} total',
                  style: const TextStyle(
                    color: primaryBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (budgets.isEmpty)
          _buildEmptyState()
        else
          ...budgets.map((budget) => _buildBudgetCard(budget)),
      ],
    );
  }

  /// Porcentaje realmente usado (puede pasar de 100 % si se excedió). Valores
  /// absurdos se muestran como ">999%".
  String _usedPercentLabel(BudgetProgress progress) {
    final percent = progress.usedFraction * 100;
    if (percent > FormatUtils.maxDisplayedPercentage) {
      return '>${FormatUtils.maxDisplayedPercentage.toStringAsFixed(0)}%';
    }
    return '${percent.toStringAsFixed(0)}%';
  }

  /// Nombre y emoji vigentes de la categoría: si una categoría personalizada
  /// se renombró, el presupuesto guardado conserva el nombre anterior.
  ({String name, String emoji}) _categoryLabel(Budget budget) {
    if (!budget.hasCustomCategory) {
      return (name: budget.categoryName, emoji: budget.categoryIcon);
    }
    final custom = CategoryService().getCategoryById(budget.customCategoryId!);
    return (
      name: custom?.name ?? budget.categoryName,
      emoji: custom?.emoji ?? budget.categoryIcon,
    );
  }

  Widget _buildAlertReachedNote(Budget budget, BudgetProgress progress) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: warningYellow.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warningYellow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_active_rounded,
            color: warningYellow,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Alerta: ya usaste el ${_usedPercentLabel(progress)} '
              '(aviso al ${budget.alertPercent}%)',
              style: const TextStyle(
                fontSize: 12,
                color: textDark,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(Budget budget) {
    final progress = _budgetService.getBudgetProgress(budget);
    final category = _categoryLabel(budget);

    return Opacity(
      opacity: budget.isActive ? 1.0 : 0.7,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: budget.isActive
                ? Budget.getStatusColor(progress.status).withOpacity(0.2)
                : Colors.grey.withOpacity(0.3), // Borde gris para pausados
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: budget.isActive
                              ? Budget.getStatusColor(
                                  progress.status,
                                ).withOpacity(0.1)
                              : Colors.grey.withOpacity(
                                  0.1,
                                ), // Gris para pausados
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            category.emoji,
                            style: TextStyle(
                              fontSize: 20,
                              color: budget.isActive
                                  ? null
                                  : Colors.grey, // Gris para pausados
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    budget.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: budget.isActive
                                          ? textDark
                                          : Colors.grey, // Gris para pausados
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                // Indicador de estado mejorado
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: budget.isActive
                                        ? Budget.getStatusColor(
                                            progress.status,
                                          ).withOpacity(0.1)
                                        : Colors.orange.withOpacity(
                                            0.1,
                                          ), // Naranja para pausados
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: budget.isActive
                                          ? Budget.getStatusColor(
                                              progress.status,
                                            ).withOpacity(0.3)
                                          : Colors.orange.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        budget.isActive
                                            ? Icons.check_circle
                                            : Icons.pause_circle,
                                        size: 10,
                                        color: budget.isActive
                                            ? Budget.getStatusColor(
                                                progress.status,
                                              )
                                            : Colors.orange,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        budget.isActive
                                            ? Budget.getStatusMessage(
                                                progress.status,
                                              )
                                            : 'Pausado',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: budget.isActive
                                              ? Budget.getStatusColor(
                                                  progress.status,
                                                )
                                              : Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${category.name} • ${budget.periodName}',
                              style: TextStyle(
                                color: budget.isActive
                                    ? textMedium
                                    : Colors.grey,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '${FormatUtils.formatMoney(progress.spentAmount)} de ${FormatUtils.formatMoney(budget.amount)}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: budget.isActive
                                            ? Budget.getStatusColor(
                                                progress.status,
                                              )
                                            : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _usedPercentLabel(progress),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: budget.isActive
                                        ? Budget.getStatusColor(progress.status)
                                        : Colors.grey,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Barra de progreso mejorada
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.percentage.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        budget.isActive
                            ? Budget.getStatusColor(progress.status)
                            : Colors.grey,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    budget.isActive
                        ? progress.progressMessage
                        : 'Presupuesto pausado - Se puede reactivar en cualquier momento',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Alerta configurada alcanzada (el excedido ya lo dicen el
                  // estado y el mensaje de arriba).
                  if (budget.isActive &&
                      budget.isAlertReached(progress.spentAmount) &&
                      progress.status != BudgetStatus.exceeded) ...[
                    const SizedBox(height: 8),
                    _buildAlertReachedNote(budget, progress),
                  ],
                ],
              ),
            ),
            // Sección de botones con estilo diferenciado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: budget.isActive
                    ? const Color(0xFFF8FAFC)
                    : Colors.grey.withOpacity(
                        0.05,
                      ), // Fondo más gris para pausados
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(
                    color: budget.isActive
                        ? const Color(0xFFE5E7EB)
                        : Colors.grey.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildBudgetActionButton(
                      Icons.edit_outlined,
                      'Editar',
                      primaryBlue,
                      () => _editBudget(budget),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBudgetActionButton(
                      budget.isActive ? Icons.pause : Icons.play_arrow,
                      budget.isActive ? 'Pausar' : 'Activar',
                      budget.isActive ? warningYellow : successGreen,
                      () => _toggleBudget(budget),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBudgetActionButton(
                      Icons.delete_outline,
                      'Eliminar',
                      dangerRed,
                      () => _deleteBudget(budget),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetActionButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Controla tus gastos',
      message:
          'Crea presupuestos para diferentes categorías y mantén tus '
          'finanzas bajo control de manera inteligente',
      ctaLabel: 'Crear Primer Presupuesto',
      onCta: _navigateToCreateBudget,
    );
  }

  // Métodos de navegación y acciones
  // Botón flotante global "Agregar" (MainNavigationScreen).
  @override
  void onAddPressed() => _navigateToCreateBudget();

  void _navigateToCreateBudget() async {
    // Validar límite antes de navegar
    if (!_budgetService.canCreateBudget()) {
      _showMessage(
        'Límite Alcanzado',
        'Has alcanzado el límite máximo de 15 presupuestos activos. Elimina o pausa algunos presupuestos para crear nuevos.',
        dangerRed,
        Icons.block_rounded,
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateBudgetScreen()),
    );

    if (result == true) {
      _refreshData();
    }
  }

  void _createQuickBudget(BudgetPeriod period) async {
    // Validar límite antes de navegar
    if (!_budgetService.canCreateBudget()) {
      _showMessage(
        'Límite Alcanzado',
        'Has alcanzado el límite máximo de 15 presupuestos activos. Elimina o pausa algunos presupuestos para crear nuevos.',
        dangerRed,
        Icons.block_rounded,
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateBudgetScreen(preselectedPeriod: period),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  void _editBudget(Budget budget) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateBudgetScreen(budgetToEdit: budget),
      ),
    );

    if (result == true && mounted) {
      await _refreshData();
    }
  }

  Future<void> _toggleBudget(Budget budget) async {
    try {
      await _budgetService.toggleBudget(budget.id!);

      if (!mounted) return;

      String statusText = budget.isActive ? 'pausado' : 'activado';
      Color statusColor = budget.isActive ? warningYellow : successGreen;

      await _refreshData();

      if (!mounted) return;

      _showMessage(
        'Presupuesto $statusText',
        'El presupuesto "${budget.name}" ha sido $statusText correctamente.',
        statusColor,
        budget.isActive
            ? Icons.pause_circle_rounded
            : Icons.play_circle_rounded,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Error',
        'No se pudo cambiar el estado del presupuesto. Inténtalo de nuevo.',
        dangerRed,
        Icons.error_rounded,
      );
    }
  }

  Future<void> _deleteBudget(Budget budget) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Eliminar presupuesto?',
      message:
          'Esta acción no se puede deshacer. El presupuesto '
          '"${budget.name}" será eliminado permanentemente.',
    );
    if (confirmed != true) return;

    try {
      await _budgetService.deleteBudget(budget.id!);
      if (!mounted) return;
      await _refreshData();
      if (!mounted) return;
      _showMessage(
        'Presupuesto eliminado',
        'El presupuesto "${budget.name}" ha sido eliminado correctamente.',
        dangerRed,
        Icons.delete_rounded,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        'Error',
        'No se pudo eliminar el presupuesto. Inténtalo de nuevo.',
        dangerRed,
        Icons.error_rounded,
      );
    }
  }

  void _showMessage(String title, String message, Color color, IconData icon) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: color.withOpacity(0.1),
                  border: Border.all(color: color.withOpacity(0.3), width: 2),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: textMedium,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
