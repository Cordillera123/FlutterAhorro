import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import '../services/budget_service.dart';
import '../services/transaction_service.dart';
import '../utils/format_utils.dart';
import 'create_budget_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> with TickerProviderStateMixin {
  final BudgetService _budgetService = BudgetService();
  final TransactionService _transactionService = TransactionService();
  bool _isLoading = true;
  BudgetSummary? _summary;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  // Colores consistentes
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);
  static const Color deepBlue = Color(0xFF1E40AF);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundCard = Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));
  }

  Future<void> _loadData() async {
    await _budgetService.loadBudgets();
    await _transactionService.loadTransactions();
    _summary = _budgetService.getBudgetSummary();
    
    // Debug para verificar la carga de datos
    _budgetService.debugPrintBudgets();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
    }
  }

  Future<void> _refreshData() async {
    HapticFeedback.lightImpact();
    await _loadData();
  }

  @override
  void dispose() {
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
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), // Reducido padding bottom
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
                                fontSize: 26,
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
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildHeaderAction(),
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

  Widget _buildHeaderAction() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _navigateToCreateBudget();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.2),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 24,
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
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
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
                        fontSize: 14,
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
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (_summary?.isNearLimit ?? false) ? warningYellow.withOpacity(0.1) : primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (_summary?.isNearLimit ?? false) ? warningYellow.withOpacity(0.3) : primaryBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            '${_summary?.totalBudgets ?? 0}/15',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: (_summary?.isNearLimit ?? false) ? warningYellow : primaryBlue,
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


  Widget _buildSummaryMetric(String title, String amount, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
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
          const SizedBox(height: 12),
          FittedBox(
            child: Text(
              amount,
              style: TextStyle(
                color: color,
                fontSize: 18,
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
          color: isHealthy ? successGreen.withOpacity(0.2) : warningYellow.withOpacity(0.2),
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
              color: (isHealthy ? successGreen : warningYellow).withOpacity(0.1),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isHealthy
                      ? 'Todos tus presupuestos están bajo control'
                      : '$exceededCount excedidos, $warningCount en advertencia',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
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
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                'Presupuesto Mensual',
                'Para gastos del mes',
                Icons.calendar_month_rounded,
                const LinearGradient(
                  colors: [primaryBlue, darkBlue],
                ),
                    () => _createQuickBudget(BudgetPeriod.monthly),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'Presupuesto Semanal',
                'Control semanal',
                Icons.date_range_rounded,
                const LinearGradient(
                  colors: [successGreen, Color(0xFF047857)],
                ),
                    () => _createQuickBudget(BudgetPeriod.weekly),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
      String title,
      String subtitle,
      IconData icon,
      Gradient gradient,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetsList() {
    // CORREGIDO: Mostrar todos los presupuestos activos (incluyendo pausados)
      final budgets = _budgetService.budgets;
  
  print('Displaying ${budgets.length} budgets');

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
          fontSize: 22,
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
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: primaryBlue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: primaryBlue.withOpacity(0.2),
      ),
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

  Widget _buildBudgetCard(Budget budget) {
    final progress = _budgetService.getBudgetProgress(budget);

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
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: budget.isActive
                            ? Budget.getStatusColor(progress.status).withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1), // Gris para pausados
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          budget.categoryIcon,
                          style: TextStyle(
                            fontSize: 24,
                            color: budget.isActive ? null : Colors.grey, // Gris para pausados
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: budget.isActive ? textDark : Colors.grey, // Gris para pausados
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Indicador de estado mejorado
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: budget.isActive
                                      ? Budget.getStatusColor(progress.status).withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.1), // Naranja para pausados
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: budget.isActive
                                        ? Budget.getStatusColor(progress.status).withOpacity(0.3)
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
                                      size: 12,
                                      color: budget.isActive
                                          ? Budget.getStatusColor(progress.status)
                                          : Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      budget.isActive
                                          ? Budget.getStatusMessage(progress.status)
                                          : 'Pausado',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: budget.isActive
                                            ? Budget.getStatusColor(progress.status)
                                            : Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${budget.categoryName} • ${budget.periodName}',
                            style: TextStyle(
                              color: budget.isActive ? textMedium : Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '${FormatUtils.formatMoney(progress.spentAmount)} de ${FormatUtils.formatMoney(budget.amount)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: budget.isActive
                                      ? Budget.getStatusColor(progress.status)
                                      : Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${(progress.percentage * 100).toStringAsFixed(0)}%',
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
                const SizedBox(height: 16),
                // Barra de progreso mejorada
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.percentage.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: budget.isActive
                            ? Budget.getStatusColor(progress.status)
                            : Colors.grey,
                        borderRadius: BorderRadius.circular(4),
                        // Patrón rayado para presupuestos pausados
                        gradient: budget.isActive
                            ? null
                            : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.grey.withOpacity(0.6),
                            Colors.grey.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  budget.isActive
                      ? progress.progressMessage
                      : 'Presupuesto pausado - Se puede reactivar en cualquier momento',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Sección de botones con estilo diferenciado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: budget.isActive
                  ? const Color(0xFFF8FAFC)
                  : Colors.grey.withOpacity(0.05), // Fondo más gris para pausados
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
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBudgetActionButton(
                    budget.isActive ? Icons.pause : Icons.play_arrow,
                    budget.isActive ? 'Pausar' : 'Activar',
                    budget.isActive ? warningYellow : successGreen,
                        () => _toggleBudget(budget),
                  ),
                ),
                const SizedBox(width: 12),
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

  Widget _buildBudgetActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(
          color: primaryBlue.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
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
          const Text(
            'Controla tus gastos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Crea presupuestos para diferentes categorías y mantén tus finanzas bajo control de manera inteligente',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToCreateBudget,
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text(
                'Crear Primer Presupuesto',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Métodos de navegación y acciones
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
      MaterialPageRoute(
        builder: (context) => const CreateBudgetScreen(),
      ),
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
        builder: (context) => CreateBudgetScreen(
          preselectedPeriod: period,
        ),
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
        builder: (context) => CreateBudgetScreen(
          budgetToEdit: budget,
        ),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  Future<void> _toggleBudget(Budget budget) async {
    try {
      await _budgetService.toggleBudget(budget.id!);

      String statusText = budget.isActive ? 'pausado' : 'activado';
      Color statusColor = budget.isActive ? warningYellow : successGreen;

      _showMessage(
        'Presupuesto $statusText',
        'El presupuesto "${budget.name}" ha sido $statusText correctamente.',
        statusColor,
        budget.isActive ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
      );

      _refreshData();
    } catch (e) {
      _showMessage(
        'Error',
        'No se pudo cambiar el estado del presupuesto. Inténtalo de nuevo.',
        dangerRed,
        Icons.error_rounded,
      );
    }
  }

  Future<void> _deleteBudget(Budget budget) async {
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
                  color: dangerRed.withOpacity(0.1),
                  border: Border.all(
                    color: dangerRed.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.delete_rounded,
                  color: dangerRed,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '¿Eliminar presupuesto?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: dangerRed,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Esta acción no se puede deshacer. El presupuesto "${budget.name}" será eliminado permanentemente.',
                style: const TextStyle(
                  fontSize: 14,
                  color: textMedium,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(
                            color: textMedium,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);

                        try {
                          await _budgetService.deleteBudget(budget.id!);

                          _showMessage(
                            'Presupuesto eliminado',
                            'El presupuesto "${budget.name}" ha sido eliminado correctamente.',
                            dangerRed,
                            Icons.delete_rounded,
                          );

                          _refreshData();
                        } catch (e) {
                          _showMessage(
                            'Error',
                            'No se pudo eliminar el presupuesto. Inténtalo de nuevo.',
                            dangerRed,
                            Icons.error_rounded,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: dangerRed,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Eliminar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 30,
                ),
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
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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