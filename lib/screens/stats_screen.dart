import 'package:flutter/material.dart';
import '../services/stats_service.dart';
import '../services/transaction_service.dart';
import '../utils/format_utils.dart';
import 'charts_screen.dart';

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
  
  // NUEVAS VARIABLES PARA HISTORIAL MENSUAL
  List<MonthlyStats> _monthlyHistory = [];
  DateTime _selectedMonth = DateTime.now();
  MonthlyDetailStats? _selectedMonthDetails;

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
      
      // CARGAR NUEVAS ESTADÍSTICAS MENSUALES
      _monthlyHistory = _statsService.getMonthlyStatsHistory();
      _selectedMonthDetails = _statsService.getMonthStats(_selectedMonth);

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

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _selectedMonthDetails = _statsService.getMonthStats(month);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryBlue,
                darkBlue,
                deepBlue,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.analytics_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Reportes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Estadísticas Financieras',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analiza tu progreso y toma decisiones inteligentes',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: _isLoading 
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                strokeWidth: 3,
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildModernAppBar(),
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeInAnimation,
                        child: Transform.translate(
                          offset: Offset(0, _slideAnimation.value),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Resumen financiero principal
                                if (_financialStats != null) ...[
                                  _buildCurrentVsPreviousCard(),
                                  const SizedBox(height: 20),
                                ],
                                
                                // Estadísticas generales
                                if (_overallStats != null) ...[
                                  _buildOverallStatsCard(),
                                  const SizedBox(height: 20),
                                ],
                                
                                // NUEVO: Botón para ver gráficos
                                if (_categoryStats.isNotEmpty) ...[
                                  _buildChartsButton(),
                                  const SizedBox(height: 20),
                                ],
                                
                                // Análisis por categorías (solo lista, sin gráfico)
                                if (_categoryStats.isNotEmpty) ...[
                                  _buildCategoryAnalysisCard(),
                                  const SizedBox(height: 20),
                                ],
                                
                                // Historial mensual mejorado
                                _buildMonthlyHistory(),
                                const SizedBox(height: 20),
                                
                                // Detalles del mes seleccionado
                                if (_selectedMonthDetails != null) 
                                  _buildMonthDetails(),
                                const SizedBox(height: 20),
                                
                                // Tendencias semanales
                                if (_weeklyStats.isNotEmpty) ...[
                                  _buildWeeklyTrendsCard(),
                                  const SizedBox(height: 20),
                                ],
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
    );
  }

  Widget _buildCurrentVsPreviousCard() {
    final stats = _financialStats!;
    
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Este Mes vs Anterior',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(height: 20),
          
          // Ingresos
          _buildComparisonItem(
            'Ingresos',
            Icons.trending_up_rounded,
            successGreen,
            stats.currentIncome,
            stats.previousIncome,
            stats.incomeGrowthPercentage,
          ),
          
          const SizedBox(height: 16),
          
          // Gastos
          _buildComparisonItem(
            'Gastos',
            Icons.trending_down_rounded,
            dangerRed,
            stats.currentExpenses,
            stats.previousExpenses,
            stats.expenseGrowthPercentage,
          ),
          
          const SizedBox(height: 16),
          
          // Balance
          _buildComparisonItem(
            'Balance',
            Icons.account_balance_rounded,
            stats.currentBalance >= 0 ? successGreen : dangerRed,
            stats.currentBalance,
            stats.previousBalance,
            stats.balanceGrowthPercentage,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(
    String title,
    IconData icon,
    Color color,
    double current,
    double previous,
    double change,
  ) {
    final isPositive = change >= 0;
    final changeColor = title == 'Gastos' ? 
        (isPositive ? dangerRed : successGreen) : 
        (isPositive ? successGreen : dangerRed);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
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
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    FormatUtils.formatMoney(current),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: changeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        color: changeColor,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${change.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: changeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  child: Text(
                    'Anterior: ${FormatUtils.formatMoney(previous)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: textMedium,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatsCard() {
    final stats = _overallStats!;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: primaryBlue.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.assessment_rounded,
                  color: primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Resumen General',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 300;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                    child: _buildOverallStatItem(
                      'Transacciones',
                      '${stats.totalTransactions}',
                      primaryBlue,
                      Icons.receipt_long_rounded,
                    ),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                    child: _buildOverallStatItem(
                      'Promedio Mensual',
                      FormatUtils.formatMoney(stats.averageMonthlyExpenses),
                      warningYellow,
                      Icons.calendar_month_rounded,
                    ),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                    child: _buildOverallStatItem(
                      'Balance Promedio',
                      FormatUtils.formatMoney(stats.averageMonthlyBalance),
                      successGreen,
                      Icons.trending_up_rounded,
                    ),
                  ),
                  SizedBox(
                    width: isWide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                    child: _buildOverallStatItem(
                      'Meses Registrados',
                      '${stats.monthsWithData}',
                      primaryPurple,
                      Icons.date_range_rounded,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatItem(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: textMedium,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

  Widget _buildChartsButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChartsScreen(categoryStats: _categoryStats),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryPurple,
              primaryPurple.withOpacity(0.8),
              const Color(0xFF6366F1),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryPurple.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: primaryPurple.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ícono con efecto glassmorphism
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ver Gráficos Detallados',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Explora tus gastos visualmente',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),
            
            // Flecha
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.08),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  color: primaryPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Análisis por Categorías',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_categoryStats.isNotEmpty) ...[
            // Lista de categorías principales (sin gráfico embebido)
            ...(_categoryStats.take(5).map((category) => 
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildCategoryItem(category),
              )
            )),
            
            // Mostrar indicador si hay más categorías
            if (_categoryStats.length > 5) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryPurple.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.more_horiz_rounded,
                      color: primaryPurple,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${_categoryStats.length - 5} categorías más',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryPurple,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryPurple.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.category_rounded,
                    color: primaryPurple.withOpacity(0.6),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No hay datos de categorías',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: primaryPurple.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(CategoryStats category) {
    final colors = [dangerRed, warningYellow, successGreen, primaryBlue, primaryPurple];
    final colorIndex = _categoryStats.indexOf(category);
    final color = colors[colorIndex % colors.length];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.categoryName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${category.transactionCount} transacciones',
                  style: const TextStyle(
                    fontSize: 12,
                    color: textMedium,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FormatUtils.formatMoney(category.amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
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
    );
  }

  Widget _buildWeeklyTrendsCard() {
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tendencias Semanales',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(height: 20),
          
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _weeklyStats.length,
              itemBuilder: (context, index) {
                final week = _weeklyStats[index];
                return _buildWeekBar(week);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekBar(WeeklyStats week) {
    final maxAmount = _weeklyStats.map((w) => w.expenses).reduce((a, b) => a > b ? a : b);
    final height = maxAmount > 0 ? (week.expenses / maxAmount) * 100 : 0.0;
    
    return Container(
      width: 60,
      margin: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            week.weekLabel.split(' - ')[0],
            style: const TextStyle(
              fontSize: 12,
              color: textMedium,
            ),
          ),
        ],
      ),
    );
  }

  // NUEVO: Widget para mostrar historial mensual
  Widget _buildMonthlyHistory() {
    if (_monthlyHistory.isEmpty || _monthlyHistory.every((m) => !m.hasData)) {
      return _buildEmptyStateCard(
        'Historial Mensual',
        'Agrega transacciones para ver tu historial',
        Icons.history_rounded,
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
                    colors: [primaryBlue, infoBlue],
                  ),
                ),
                child: const Icon(
                  Icons.history_rounded,
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
                      'Historial Mensual',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tus últimos 12 meses de actividad',
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
          
          // Gráfico de barras mensual
          _buildMonthlyChart(),
          
          const SizedBox(height: 20),
          
          // Lista de meses con resumen
          _buildMonthlyList(),
        ],
      ),
    );
  }

  // NUEVO: Gráfico de barras mensual
  Widget _buildMonthlyChart() {
  final monthsWithData = _monthlyHistory.where((m) => m.hasData).toList();
  if (monthsWithData.isEmpty) return const SizedBox.shrink();

  final maxAmount = monthsWithData.map((m) => 
    [m.income, m.expenses].reduce((a, b) => a > b ? a : b)
  ).reduce((a, b) => a > b ? a : b);

  return SizedBox(
    height: 130, // ✅ FINAL: De 140 a 130 (elimina los 1.8px restantes)
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width - 80,
        ),
        child: IntrinsicWidth(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: monthsWithData.map((month) => 
              _buildMonthBar(month, maxAmount)
            ).toList(),
          ),
        ),
      ),
    ),
  );
}

 Widget _buildMonthBar(MonthlyStats month, double maxAmount) {
  final incomeHeight = maxAmount > 0 ? (month.income / maxAmount) * 90 : 0.0; // ✅ FINAL: De 100 a 90
  final expenseHeight = maxAmount > 0 ? (month.expenses / maxAmount) * 90 : 0.0; // ✅ FINAL: De 100 a 90
  final isSelected = FormatUtils.isSameMonth(month.month, _selectedMonth);

  return SizedBox(
    width: 50,
    child: GestureDetector(
      onTap: () => _selectMonth(month.month),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Balance indicator
            SizedBox(
              height: 14, // ✅ FINAL: De 16 a 14
              child: month.balance >= 0 
                ? const Icon(Icons.trending_up, color: successGreen, size: 10) // ✅ FINAL: De 11 a 10
                : const Icon(Icons.trending_down, color: dangerRed, size: 10),
            ),
            
            // Income bar
            Container(
              width: double.infinity,
              height: incomeHeight,
              decoration: BoxDecoration(
                color: isSelected ? successGreen : successGreen.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ),
            
            const SizedBox(height: 2),
            
            // Expense bar
            Container(
              width: double.infinity,
              height: expenseHeight,
              decoration: BoxDecoration(
                color: isSelected ? dangerRed : dangerRed.withOpacity(0.7),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
            
            const SizedBox(height: 4), // ✅ Se mantiene en 4
            
            // Month label
            Text(
              month.shortMonthLabel,
              style: TextStyle(
                fontSize: 8,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryBlue : textMedium,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ),
  );
}

  // NUEVO: Lista de meses
  Widget _buildMonthlyList() {
    final recentMonths = _monthlyHistory.where((m) => m.hasData).take(6).toList();
    
    return Column(
      children: recentMonths.map((month) => _buildMonthItem(month)).toList(),
    );
  }

  Widget _buildMonthItem(MonthlyStats month) {
    final isSelected = FormatUtils.isSameMonth(month.month, _selectedMonth);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectMonth(month.month),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? primaryBlue.withOpacity(0.1) : backgroundCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? primaryBlue : borderLight,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: month.isPositive 
                        ? successGreen.withOpacity(0.1) 
                        : dangerRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    month.isPositive 
                        ? Icons.trending_up_rounded 
                        : Icons.trending_down_rounded,
                    color: month.isPositive ? successGreen : dangerRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        month.fullMonthLabel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? primaryBlue : textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${month.transactionCount} transacciones • ${month.topExpenseCategory?.categoryName ?? "Sin gastos"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      FormatUtils.formatMoney(month.balance),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: month.isPositive ? successGreen : dangerRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${month.savingsRate.toStringAsFixed(1)}% ahorro',
                      style: const TextStyle(
                        fontSize: 12,
                        color: textMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // NUEVO: Widget para mostrar detalles del mes seleccionado
  Widget _buildMonthDetails() {
    final monthDetails = _selectedMonthDetails;
    if (monthDetails == null || !monthDetails.hasData) {
      return _buildEmptyStateCard(
        'Detalles del Mes',
        'Selecciona un mes con datos para ver los detalles',
        Icons.calendar_month_rounded,
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
                    colors: [warningYellow, primaryPurple],
                  ),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalles de ${monthDetails.monthLabel}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Análisis detallado del mes seleccionado',
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
          
          // Resumen del mes
          _buildMonthSummary(monthDetails),
          
          const SizedBox(height: 20),
          
          // Top categorías del mes
          if (monthDetails.categoryStats.isNotEmpty)
            _buildMonthTopCategories(monthDetails.categoryStats),
        ],
      ),
    );
  }

  Widget _buildMonthSummary(MonthlyDetailStats monthDetails) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200), // ← NUEVO
      padding: const EdgeInsets.all(16), // ← CAMBIADO de 20 a 16
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            monthDetails.isPositive ? successGreen.withOpacity(0.1) : dangerRed.withOpacity(0.1),
            backgroundCard,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: monthDetails.isPositive ? successGreen.withOpacity(0.2) : dangerRed.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: SingleChildScrollView( // ← NUEVO
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildDetailStat(
                    'Balance',
                    FormatUtils.formatMoney(monthDetails.balance),
                    monthDetails.isPositive ? successGreen : dangerRed,
                    monthDetails.isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  ),
                ),
                Container(width: 1, height: 40, color: borderLight),
                Expanded(
                  child: _buildDetailStat(
                    'Transacciones',
                    '${monthDetails.transactionCount}',
                    primaryBlue,
                    Icons.receipt_long_rounded,
                  ),
                ),
                Container(width: 1, height: 40, color: borderLight),
                Expanded(
                  child: _buildDetailStat(
                    'Tasa Ahorro',
                    '${monthDetails.savingsRate.toStringAsFixed(1)}%',
                    monthDetails.savingsRate >= 20 ? successGreen : warningYellow,
                    Icons.savings_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDetailStat(
                    'Promedio Diario',
                    FormatUtils.formatMoney(monthDetails.averageDailyExpenses),
                    infoBlue,
                    Icons.today_rounded,
                  ),
                ),
                Container(width: 1, height: 40, color: borderLight),
                Expanded(
                  child: _buildDetailStat(
                    'Mayor Gasto',
                    monthDetails.highestExpenseDay != null 
                        ? 'Día ${monthDetails.highestExpenseDay!.day}'
                        : 'N/A',
                    dangerRed,
                    Icons.bar_chart_rounded,
                  ),
                ),
                Container(width: 1, height: 40, color: borderLight),
                Expanded(
                  child: _buildDetailStat(
                    'Categorías',
                    '${monthDetails.categoryStats.length}',
                    primaryPurple,
                    Icons.category_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildMonthTopCategories(List<CategoryStats> categoryStats) {
    final topCategories = categoryStats.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top Categorías del Mes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
        const SizedBox(height: 16),
        ...topCategories.map((category) => _buildCompactCategoryItem(category)).toList(),
      ],
    );
  }

  Widget _buildCompactCategoryItem(CategoryStats category) {
    final colors = [dangerRed, warningYellow, successGreen];
    final colorIndex = _selectedMonthDetails!.categoryStats.indexOf(category);
    final color = colors[colorIndex % colors.length];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                category.categoryIcon,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.categoryName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${category.transactionCount} transacciones',
                  style: const TextStyle(
                    fontSize: 11,
                    color: textMedium,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                FormatUtils.formatMoney(category.amount),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${category.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              icon,
              size: 48,
              color: primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: textMedium,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}