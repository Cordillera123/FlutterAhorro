import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/recurring_expense_service.dart';
import '../services/stats_service.dart';
import '../services/category_service.dart';
import '../utils/format_utils.dart';
import '../widgets/app_logo.dart';
import 'add_transaction_screen.dart';
import 'recurring_expenses_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TransactionService _transactionService = TransactionService();
  final RecurringExpenseService _recurringExpenseService =
      RecurringExpenseService();
  final StatsService _statsService = StatsService();
  final CategoryService _categoryService = CategoryService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  bool _isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  FinancialStats? _financialStats;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();

    // NUEVO: Escuchar cambios en el TransactionService
    _transactionService.addListener(_onTransactionServiceChanged);
    // Escuchar cambios en CategoryService (para actualizar nombres/emojis)
    _categoryService.addListener(_onCategoryServiceChanged);
  }

  // NUEVO: Método que se ejecuta cuando el TransactionService notifica cambios
  void _onTransactionServiceChanged() {
    if (mounted) {
      _updateStats();
      setState(() {
        // Forzar rebuild cuando cambien los datos del servicio
      });
    }
  }

  // Método que se ejecuta cuando CategoryService notifica cambios
  void _onCategoryServiceChanged() {
    if (mounted) {
      setState(() {
        // Forzar rebuild para mostrar nombres/emojis actualizados
      });
    }
  }

  void _updateStats() {
    _financialStats = _statsService.getCurrentVsPreviousStats();
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
    try {
      await _transactionService.loadTransactions();
      await _recurringExpenseService.loadRecurringExpenses();
      await _recurringExpenseService.processRecurringExpensesForToday();

      _updateStats();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isRefreshing = true;
    });
    await _loadData();
  }

  @override
  void dispose() {
    // NUEVO: Remover el listener cuando se destruye el widget
    _transactionService.removeListener(_onTransactionServiceChanged);
    _categoryService.removeListener(_onCategoryServiceChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Vista de carga inicial
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: const Center(child: AppLogoLoading()),
      );
    }

    // Vista principal con overlay de actualización opcional
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshData,
            color: const Color(0xFF34D399),
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
                                _buildBalanceCard(),
                                const SizedBox(height: 24),
                                _buildFinancialOverview(),
                                const SizedBox(height: 28),
                                _buildQuickActions(),
                                const SizedBox(height: 28),
                                _buildRecentTransactions(),
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
          // Overlay de carga para actualizaciones manuales (pull to refresh)
          if (_isRefreshing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50),
                        ),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Actualizando datos...',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 190,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF4CAF50),
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF43A047), Color(0xFF388E3C), Color(0xFF2E7D32)],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  // Header con menú y saludo centrado
                  Row(
                    children: [
                      // Botón de menú (izquierda)
                      _buildMenuButton(),
                      // Saludo centrado
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              FormatUtils.getGreeting(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Controla tus finanzas con serenidad',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      // Espacio invisible para balancear (mismo tamaño que el botón)
                      const SizedBox(width: 44),
                    ],
                  ),
                  const Spacer(),
                  // Balance con diseño mejorado
                  _buildBalancePreview(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        _scaffoldKey.currentState?.openDrawer();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.15),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1.5),
        ),
        child: const Icon(Icons.menu_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header del drawer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF81C784),
                    Color(0xFF4CAF50),
                    Color(0xFF388E3C),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text('💰', style: TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mi Ahorro',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Gestiona tus finanzas',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Opciones del menú
            _buildDrawerItem(
              icon: Icons.category_outlined,
              title: 'Categorías de gastos',
              subtitle: 'Personaliza tus categorías',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.repeat_outlined,
              title: 'Gastos recurrentes',
              subtitle: 'Configura pagos automáticos',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecurringExpensesScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.bar_chart_outlined,
              title: 'Estadísticas',
              subtitle: 'Analiza tus gastos',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const StatsScreen()),
                );
              },
            ),
            const Divider(height: 32),
            _buildDrawerItem(
              icon: Icons.settings_outlined,
              title: 'Configuración',
              subtitle: 'Gestionar categorías y más',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            const Spacer(),
            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Versión 1.0.0',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF4CAF50), size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: Color(0xFF1E293B),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey.shade400,
        size: 20,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }

  Widget _buildBalancePreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Balance Total',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              FormatUtils.formatMoney(_transactionService.totalBalance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8F5E9), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGrowthMessage(),
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getGrowthColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getGrowthIcon(),
                            color: _getGrowthColor(),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getGrowthText(),
                            style: TextStyle(
                              color: _getGrowthColor(),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
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
        ],
      ),
    );
  }

  Widget _buildFinancialOverview() {
    final stats = _financialStats;
    final currentIncome = stats?.currentIncome ?? 0.0;
    final currentExpenses = stats?.currentExpenses ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Este mes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            if (stats?.hasCurrentData == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${stats!.currentMonthTransactionCount} transacciones',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildGlassCard(
                title: 'Ingresos',
                amount: FormatUtils.formatMoney(currentIncome),
                icon: Icons.arrow_upward_rounded,
                color: const Color(0xFF059669),
                isPositive: true,
                subtitle: _getIncomeGrowthText(),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildGlassCard(
                title: 'Gastos',
                amount: FormatUtils.formatMoney(currentExpenses),
                icon: Icons.arrow_downward_rounded,
                color: const Color(0xFFDC2626),
                isPositive: false,
                subtitle: _getExpenseGrowthText(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required bool isPositive,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Text(
                subtitle ?? '',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  amount,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
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
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildActionCard(
              title: 'Ingresos',
              icon: Icons.trending_up_rounded,
              color: const Color(0xFF3B82F6),
              onTap: _navigateToAddSalary,
            ),
            _buildActionCard(
              title: 'Gastos',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFEF4444),
              onTap: _navigateToAddExpense,
            ),
            _buildActionCard(
              title: 'Recurrentes',
              icon: Icons.sync_rounded,
              color: const Color(0xFFF59E0B),
              onTap: _navigateToRecurringExpenses,
            ),
            _buildActionCard(
              title: 'Estadísticas',
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: _navigateToStats,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          border: Border.all(color: color.withOpacity(0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: color.withOpacity(0.4),
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    final recentTransactions = _transactionService.transactions
        .take(5)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Transacciones Recientes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (recentTransactions.isNotEmpty)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  // TODO: Navigate to full history
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.2),
                    ),
                  ),
                  child: const Text(
                    'Ver todas',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (recentTransactions.isEmpty)
          _buildEmptyState()
        else
          ...recentTransactions.map(
            (transaction) => _buildTransactionItem(transaction),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4CAF50).withOpacity(0.05),
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
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              ),
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Comienza tu viaje financiero',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Agrega tu primera transacción para comenzar a controlar tus finanzas de manera inteligente y serena',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToAddSalary,
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text(
                'Agregar Primer Salario',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
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

  Widget _buildTransactionItem(Transaction transaction) {
    final isIncome = transaction.type == TransactionType.income;

    // Obtener nombre/emoji actualizado de la categoría
    final categoryInfo = _categoryService.getCategoryInfo(
      transaction.customCategoryId,
      transaction.expenseCategory,
    );
    final categoryName = transaction.hasCustomCategory
        ? categoryInfo['name']!
        : transaction.categoryName;
    final categoryEmoji = transaction.hasCustomCategory
        ? categoryInfo['emoji']!
        : transaction.categoryIcon;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isIncome
                  ? const Color(0xFF4CAF50).withOpacity(0.1)
                  : const Color(0xFFFF7043).withOpacity(0.1),
            ),
            child: Center(
              child: Text(categoryEmoji, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  categoryName,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                child: Text(
                  '${isIncome ? '+' : '-'}${FormatUtils.formatMoney(transaction.amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: isIncome
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF7043),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                FormatUtils.formatDateForList(transaction.date),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // NUEVO: Métodos de navegación simplificados
  // Ya no necesitan refresh manual - el listener se encarga automáticamente
  Future<void> _navigateToAddSalary() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const AddTransactionScreen(initialType: TransactionType.income),
      ),
    );
    // No se necesita código adicional - el listener actualiza automáticamente
  }

  Future<void> _navigateToAddExpense() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const AddTransactionScreen(initialType: TransactionType.expense),
      ),
    );
    // No se necesita código adicional - el listener actualiza automáticamente
  }

  Future<void> _navigateToRecurringExpenses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecurringExpensesScreen()),
    );

    // Para gastos recurrentes, sí necesitamos refresh manual
    if (mounted) {
      await _transactionService.loadTransactions();
      await _recurringExpenseService.loadRecurringExpenses();
    }
  }

  void _navigateToStats() {
    HapticFeedback.lightImpact();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const StatsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  // Métodos para obtener datos reales del crecimiento financiero
  String _getGrowthMessage() {
    final stats = _financialStats;
    if (stats == null || !stats.hasData) {
      return 'Agrega transacciones para ver tu progreso';
    }

    if (!stats.hasCurrentData) {
      return 'Aún no tienes transacciones este mes';
    }

    if (!stats.hasPreviousData) {
      return 'Tu primer mes registrado';
    }

    return FormatUtils.getGrowthMessage(stats.balanceGrowthPercentage);
  }

  IconData _getGrowthIcon() {
    final stats = _financialStats;
    if (stats == null || !stats.hasData || !stats.hasPreviousData) {
      return Icons.show_chart_rounded;
    }

    return FormatUtils.getGrowthIcon(stats.balanceGrowthPercentage);
  }

  Color _getGrowthColor() {
    final stats = _financialStats;
    if (stats == null || !stats.hasData || !stats.hasPreviousData) {
      return const Color(0xFF64748B);
    }

    return FormatUtils.getGrowthColor(stats.balanceGrowthPercentage);
  }

  String _getGrowthText() {
    final stats = _financialStats;
    if (stats == null || !stats.hasData) {
      return 'Sin datos';
    }

    if (!stats.hasCurrentData) {
      return 'Este mes: \$0';
    }

    if (!stats.hasPreviousData) {
      return 'Primer mes';
    }

    final percentage = stats.balanceGrowthPercentage;
    return '${FormatUtils.formatPercentageWithSign(percentage)} este mes';
  }

  String _getIncomeGrowthText() {
    final stats = _financialStats;
    if (stats == null || !stats.hasData || !stats.hasPreviousData) {
      return '';
    }

    return FormatUtils.formatPercentageWithSign(stats.incomeGrowthPercentage);
  }

  String _getExpenseGrowthText() {
    final stats = _financialStats;
    if (stats == null || !stats.hasData || !stats.hasPreviousData) {
      return '';
    }

    return FormatUtils.formatPercentageWithSign(stats.expenseGrowthPercentage);
  }
}
