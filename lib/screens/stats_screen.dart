import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/stats_service.dart';
import '../services/transaction_service.dart';
import '../utils/format_utils.dart';
import '../models/transaction.dart';
import '../widgets/pie_chart_widget.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with TickerProviderStateMixin {
  final StatsService _statsService = StatsService();
  final TransactionService _transactionService = TransactionService();
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  
  bool _isLoading = true;
  FinancialStats? _financialStats;
  List<CategoryStats> _categoryStats = [];
  List<WeeklyStats> _weeklyStats = [];
  OverallStats? _overallStats;

  // Definición de colores consistentes
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);
  static const Color deepBlue = Color(0xFF1E40AF);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color infoBlue = Color(0xFF0EA5E9);
  static const Color darkGreen = Color(0xFF047857);
  static const Color darkRed = Color(0xFFB91C1C);
  static const Color primaryPurple = Color(0xFF7C3AED);

  // Colores de texto y fondo
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundCard = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadStats();
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

  Future<void> _loadStats() async {
    try {
      await _transactionService.loadTransactions();
      
      _financialStats = _statsService.getCurrentVsPreviousStats();
      _categoryStats = _statsService.getCategoryStats();
      _weeklyStats = _statsService.getWeeklyStats();
      _overallStats = _statsService.getOverallStats();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                    colors: [primaryPurple, infoBlue],
                  ),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryPurple),
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Generando tus estadísticas...',
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
        onRefresh: _loadStats,
        color: primaryPurple,
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
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildOverallSummary(),
                            const SizedBox(height: 28),
                            _buildMonthlyComparison(),
                            const SizedBox(height: 28),
                            _buildCategoryBreakdown(),
                            const SizedBox(height: 28),
                            _buildWeeklyTrends(),
                            const SizedBox(height: 28),
                            _buildFinancialInsights(),
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
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
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
              colors: [
                primaryPurple,
                infoBlue,
                primaryBlue,
              ],
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estadísticas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Analiza tus finanzas en detalle',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 15,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.analytics_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildStatsPreview(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsPreview() {
    final stats = _financialStats;
    final hasData = stats?.hasData ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasData ? 'Tu progreso este mes' : 'Sin datos suficientes',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              hasData && stats!.hasPreviousData 
                  ? FormatUtils.getGrowthIcon(stats.balanceGrowthPercentage)
                  : Icons.show_chart_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              hasData && stats!.hasPreviousData
                  ? FormatUtils.formatPercentageWithSign(stats.balanceGrowthPercentage)
                  : 'Agrega más transacciones',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverallSummary() {
    final overall = _overallStats;
    if (overall == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: primaryPurple.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [primaryPurple, infoBlue],
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen General',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Todos tus datos financieros',
                      style: TextStyle(
                        fontSize: 14,
                        color: textMedium,
                      ),
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
                child: _buildSummaryCard(
                  'Balance Total',
                  FormatUtils.formatMoney(overall.totalBalance),
                  overall.totalBalance >= 0 ? successGreen : dangerRed,
                  overall.totalBalance >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Transacciones',
                  '${overall.totalTransactions}',
                  primaryBlue,
                  Icons.receipt_long_rounded,
                ),
              ),
            ],
          ),
          if (overall.monthsWithData > 0) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Ahorro Promedio',
                    FormatUtils.formatMoney(overall.averageMonthlyBalance),
                    overall.averageMonthlyBalance >= 0 ? successGreen : dangerRed,
                    Icons.savings_rounded,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Tasa de Ahorro',
                    FormatUtils.formatPercentage(overall.savingsRate),
                    overall.savingsRate >= 20 ? successGreen : 
                    overall.savingsRate >= 10 ? warningYellow : dangerRed,
                    Icons.percent_rounded,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color, IconData icon) {
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
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textMedium,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyComparison() {
    final stats = _financialStats;
    if (stats == null || !stats.hasData) {
      return _buildEmptyStateCard(
        'Comparación Mensual',
        'Agrega transacciones para ver la comparación',
        Icons.compare_arrows_rounded,
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [infoBlue, primaryBlue],
                  ),
                ),
                child: const Icon(
                  Icons.compare_arrows_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Este Mes vs Anterior',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Compara tu progreso mensual',
                      style: TextStyle(
                        fontSize: 14,
                        color: textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildComparisonRow(
            'Balance',
            FormatUtils.formatMoney(stats.currentBalance),
            FormatUtils.formatMoney(stats.previousBalance),
            stats.balanceGrowthPercentage,
          ),
          const SizedBox(height: 16),
          _buildComparisonRow(
            'Ingresos',
            FormatUtils.formatMoney(stats.currentIncome),
            FormatUtils.formatMoney(stats.previousIncome),
            stats.incomeGrowthPercentage,
          ),
          const SizedBox(height: 16),
          _buildComparisonRow(
            'Gastos',
            FormatUtils.formatMoney(stats.currentExpenses),
            FormatUtils.formatMoney(stats.previousExpenses),
            stats.expenseGrowthPercentage,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String title, String current, String previous, double growthPercentage) {
    final color = FormatUtils.getGrowthColor(growthPercentage);
    final icon = FormatUtils.getGrowthIcon(growthPercentage);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderLight,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Actual: $current',
                  style: const TextStyle(
                    fontSize: 13,
                    color: textMedium,
                  ),
                ),
                Text(
                  'Anterior: $previous',
                  style: const TextStyle(
                    fontSize: 13,
                    color: textMedium,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(
                  FormatUtils.formatPercentageWithSign(growthPercentage),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown() {
    if (_categoryStats.isEmpty) {
      return _buildEmptyStateCard(
        'Gastos por Categoría',
        'Agrega gastos para ver el desglose',
        Icons.pie_chart_rounded,
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [primaryPurple, infoBlue],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: primaryPurple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gastos por Categoría',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Visualiza cómo distribuyes tu dinero',
                      style: TextStyle(
                        fontSize: 14,
                        color: textMedium,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Gráfico de pastel interactivo
          Center(
            child: PieChartWidget(
              categoryStats: _categoryStats,
              size: 280,
              showLegend: true,
              onCategorySelected: (category) {
                // Feedback háptico cuando se selecciona una categoría
                if (category != null) {
                  HapticFeedback.lightImpact();
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          // Resumen adicional
          _buildCategoryStatsSummary(),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(CategoryStats category) {
    final colors = [
      dangerRed,
      warningYellow,
      successGreen,
      primaryBlue,
      primaryPurple,
      infoBlue,
    ];
    final color = colors[_categoryStats.indexOf(category) % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                category.categoryIcon,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      category.categoryName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textDark,
                      ),
                    ),
                    Text(
                      FormatUtils.formatMoney(category.amount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: category.percentage / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${category.percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTrends() {
    if (_weeklyStats.isEmpty || _weeklyStats.every((w) => w.transactionCount == 0)) {
      return _buildEmptyStateCard(
        'Tendencias Semanales',
        'Agrega transacciones para ver las tendencias',
        Icons.show_chart_rounded,
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [successGreen, darkGreen],
                  ),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Últimas 4 Semanas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tu actividad financiera semanal',
                      style: TextStyle(
                        fontSize: 14,
                        color: textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildWeeklyChart(),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final maxAmount = _weeklyStats.map((w) => 
      [w.income, w.expenses].reduce((a, b) => a > b ? a : b)
    ).reduce((a, b) => a > b ? a : b);

    if (maxAmount == 0) {
      return const Center(
        child: Text(
          'No hay datos para mostrar',
          style: TextStyle(
            fontSize: 14,
            color: textMedium,
          ),
        ),
      );
    }

    return Column(
      children: _weeklyStats.map((week) => _buildWeeklyBar(week, maxAmount)).toList(),
    );
  }

  Widget _buildWeeklyBar(WeeklyStats week, double maxAmount) {
    final incomePercentage = maxAmount > 0 ? week.income / maxAmount : 0.0;
    final expensePercentage = maxAmount > 0 ? week.expenses / maxAmount : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                week.weekLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textDark,
                ),
              ),
              Text(
                'Balance: ${FormatUtils.formatMoney(week.balance)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: week.balance >= 0 ? successGreen : dangerRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Barra de ingresos
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: successGreen.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: incomePercentage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: successGreen,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Barra de gastos
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: dangerRed.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: expensePercentage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: dangerRed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.formatMoneyCompact(week.income),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: successGreen,
                    ),
                  ),
                  Text(
                    FormatUtils.formatMoneyCompact(week.expenses),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: dangerRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialInsights() {
    final stats = _financialStats;
    final overall = _overallStats;
    
    if (stats == null || overall == null) {
      return _buildEmptyStateCard(
        'Insights Financieros',
        'Agrega más transacciones para obtener insights',
        Icons.lightbulb_rounded,
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: borderLight,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [warningYellow, Color(0xFFFF8C00)],
                  ),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insights Financieros',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Recomendaciones personalizadas',
                      style: TextStyle(
                        fontSize: 14,
                        color: textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ..._generateInsights(stats, overall),
        ],
      ),
    );
  }

  List<Widget> _generateInsights(FinancialStats stats, OverallStats overall) {
    List<Widget> insights = [];

    // Insight sobre tasa de ahorro
    if (overall.savingsRate > 0) {
      insights.add(_buildInsightCard(
        overall.savingsRate >= 20 ? '🎉' : overall.savingsRate >= 10 ? '👍' : '⚠️',
        'Tasa de Ahorro',
        overall.savingsRate >= 20 
            ? '¡Excelente! Estás ahorrando ${overall.savingsRate.toStringAsFixed(1)}% de tus ingresos.'
            : overall.savingsRate >= 10
                ? 'Bien hecho. Ahorras ${overall.savingsRate.toStringAsFixed(1)}% de tus ingresos.'
                : 'Tu tasa de ahorro es del ${overall.savingsRate.toStringAsFixed(1)}%. Considera reducir gastos.',
        overall.savingsRate >= 20 ? successGreen : overall.savingsRate >= 10 ? warningYellow : dangerRed,
      ));
    }

    // Insight sobre crecimiento
    if (stats.hasPreviousData) {
      insights.add(_buildInsightCard(
        stats.balanceGrowthPercentage > 0 ? '📈' : stats.balanceGrowthPercentage < 0 ? '📉' : '➡️',
        'Tendencia Mensual',
        stats.balanceGrowthPercentage > 0 
            ? 'Tu balance creció ${stats.balanceGrowthPercentage.toStringAsFixed(1)}% este mes. ¡Sigue así!'
            : stats.balanceGrowthPercentage < 0
                ? 'Tu balance disminuyó ${stats.balanceGrowthPercentage.abs().toStringAsFixed(1)}% este mes. Revisa tus gastos.'
                : 'Tu balance se mantiene estable este mes.',
        FormatUtils.getGrowthColor(stats.balanceGrowthPercentage),
      ));
    }

    // Insight sobre categoría principal
    if (_categoryStats.isNotEmpty) {
      final topCategory = _categoryStats.first;
      insights.add(_buildInsightCard(
        topCategory.categoryIcon,
        'Mayor Gasto',
        'Tu mayor gasto este mes es en ${topCategory.categoryName} con ${FormatUtils.formatMoney(topCategory.amount)} (${topCategory.percentage.toStringAsFixed(1)}%).',
        primaryBlue,
      ));
    }

    return insights;
  }

  Widget _buildInsightCard(String emoji, String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: textMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(String title, String description, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: borderLight,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: textMedium.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              color: textMedium,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: textMedium,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryStatsSummary() {
    if (_categoryStats.isEmpty) return const SizedBox.shrink();

    final totalAmount = _categoryStats.fold(0.0, (sum, cat) => sum + cat.amount);
    final topCategory = _categoryStats.first;
    final categoryCount = _categoryStats.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            backgroundCard,
            primaryPurple.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryPurple.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '💰',
                  'Total Gastado',
                  FormatUtils.formatMoney(totalAmount),
                  primaryPurple,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: borderLight,
              ),
              Expanded(
                child: _buildStatItem(
                  topCategory.categoryIcon,
                  'Mayor Gasto',
                  topCategory.categoryName,
                  successGreen,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: borderLight,
              ),
              Expanded(
                child: _buildStatItem(
                  '📊',
                  'Categorías',
                  '$categoryCount',
                  infoBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String icon, String label, String value, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.circle,
              size: 6,
              color: color,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textMedium,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}