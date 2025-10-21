import 'package:flutter/material.dart';
import '../services/stats_service.dart';
import '../widgets/pie_chart_widget.dart';
import '../utils/format_utils.dart';

class ChartsScreen extends StatefulWidget {
  final List<CategoryStats> categoryStats;

  const ChartsScreen({
    super.key,
    required this.categoryStats,
  });

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _legendController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _legendFadeAnimation;
  late Animation<double> _scaleAnimation;

  // Colores consistentes con el diseño
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);
  static const Color deepBlue = Color(0xFF1E40AF);
  static const Color textDark = Color(0xFF1E293B);
  static const Color textMedium = Color(0xFF64748B);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color backgroundCard = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    // Animación principal del gráfico
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Animación de la leyenda
    _legendController = AnimationController(
      duration: const Duration(milliseconds: 600),
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
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    _legendFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _legendController,
      curve: Curves.easeOut,
    ));

    // Iniciar animaciones
    _animationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _legendController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _legendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderSection(),
                        const SizedBox(height: 32),
                        _buildChartCard(),
                        const SizedBox(height: 24),
                        _buildLegendSection(),
                        const SizedBox(height: 32),
                        _buildInsightsSection(),
                        const SizedBox(height: 20), // Padding extra al final
                      ],
                    );
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
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
      ),
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
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.pie_chart_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Análisis Gráfico',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Visualización de gastos',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
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

  Widget _buildHeaderSection() {
    final total = widget.categoryStats.fold<double>(
      0,
      (sum, stat) => sum + stat.amount,
    );

    return FadeTransition(
      opacity: _fadeInAnimation,
      child: Transform.translate(
        offset: Offset(0, _slideAnimation.value),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryBlue.withOpacity(0.1),
                deepBlue.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: primaryBlue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Gastos',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FormatUtils.formatMoney(total),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.categoryStats.length} categorías',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    if (widget.categoryStats.isEmpty) {
      return _buildEmptyChart();
    }

    return FadeTransition(
      opacity: _fadeInAnimation,
      child: Transform.scale(
        scale: _scaleAnimation.value,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 600), // ✅ FINAL: 600px
          padding: const EdgeInsets.all(18), // ✅ OPTIMIZADO: De 20 a 18
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primaryBlue.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Distribución por Categorías',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
                const SizedBox(height: 4), // ✅ OPTIMIZADO: De 6 a 4
                Text(
                  'Toca una sección para ver detalles',
                  style: TextStyle(
                    fontSize: 11, // ✅ OPTIMIZADO: De 12 a 11
                    fontWeight: FontWeight.w400,
                    color: textMedium.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 10), // ✅ OPTIMIZADO: De 12 a 10

                // Gráfico de torta
                Center(
                  child: SizedBox(
                    width: 210, // ✅ OPTIMIZADO: De 220 a 210
                    height: 210, // ✅ OPTIMIZADO: De 220 a 210
                    child: PieChartWidget(
                      categoryStats: widget.categoryStats,
                      size: 210, // ✅ OPTIMIZADO: De 220 a 210
                      showLegend: false,
                    ),
                  ),
                ),
                const SizedBox(height: 10), // ✅ OPTIMIZADO: De 12 a 10
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildLegendSection() {
    if (widget.categoryStats.isEmpty) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _legendFadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Categorías',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(height: 16),
          
          // Lista de categorías con colores
          ...widget.categoryStats.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            return _buildLegendItem(category, index);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLegendItem(CategoryStats category, int index) {
    // Colores del gráfico (mismos que PieChartWidget)
    final colors = [
      const Color(0xFFFF6B6B), // Rojo coral
      const Color(0xFF4ECDC4), // Turquesa
      const Color(0xFF45B7D1), // Azul cielo
      const Color(0xFF96CEB4), // Verde menta
      const Color(0xFFFECA57), // Amarillo dorado
      const Color(0xFFFF9FF3), // Rosa fucsia
      const Color(0xFF54A0FF), // Azul brillante
      const Color(0xFF5F27CD), // Púrpura
      const Color(0xFFFF9F43), // Naranja
      const Color(0xFF00D2D3), // Cian
      const Color(0xFFFF6348), // Rojo tomate
      const Color(0xFF2ED573), // Verde lime
    ];

    final color = colors[index % colors.length];
    final total = widget.categoryStats.fold<double>(
      0,
      (sum, stat) => sum + stat.amount,
    );
    final percentage = (category.amount / total * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 8), // ✅ OPTIMIZADO - De 10 a 8
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), // ✅ OPTIMIZADO - De 16,14 a 14,12
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Indicador de color con ícono
          Container(
            width: 36, // ✅ OPTIMIZADO - De 40 a 36
            height: 36, // ✅ OPTIMIZADO - De 40 a 36
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                category.categoryIcon,
                style: const TextStyle(fontSize: 18), // ✅ OPTIMIZADO - De 20 a 18
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Nombre de categoría
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.categoryName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${category.transactionCount} ${category.transactionCount == 1 ? 'transacción' : 'transacciones'}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: textMedium.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          
          // Porcentaje y monto
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                FormatUtils.formatMoney(category.amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: textDark,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsSection() {
    if (widget.categoryStats.isEmpty) return const SizedBox.shrink();

    // Encontrar la categoría con mayor gasto
    final topCategory = widget.categoryStats.reduce(
      (a, b) => a.amount > b.amount ? a : b,
    );

    final total = widget.categoryStats.fold<double>(
      0,
      (sum, stat) => sum + stat.amount,
    );
    final topPercentage = (topCategory.amount / total * 100).toStringAsFixed(0);

    return FadeTransition(
      opacity: _legendFadeAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF7C3AED).withOpacity(0.1),
              const Color(0xFF6366F1).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF7C3AED).withOpacity(0.2),
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
                    color: const Color(0xFF7C3AED).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lightbulb_rounded,
                    color: Color(0xFF7C3AED),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Insight Financiero',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.trending_up_rounded,
                    color: Color(0xFF7C3AED),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: textDark,
                          height: 1.4,
                        ),
                        children: [
                          const TextSpan(text: 'Tu mayor gasto es en '),
                          TextSpan(
                            text: topCategory.categoryName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                          const TextSpan(text: ', representando el '),
                          TextSpan(
                            text: '$topPercentage%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                          const TextSpan(text: ' de tus gastos totales.'),
                        ],
                      ),
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

  Widget _buildEmptyChart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: primaryBlue.withOpacity(0.1),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.pie_chart_outline_rounded,
              color: primaryBlue.withOpacity(0.6),
              size: 64,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay datos para mostrar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega transacciones para ver\ntus estadísticas gráficas',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: textMedium.withOpacity(0.8),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}