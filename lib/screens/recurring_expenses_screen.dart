import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recurring_expense.dart';
import '../models/transaction.dart';
import '../services/recurring_expense_service.dart';
import '../utils/format_utils.dart';
import 'add_recurring_expense_screen.dart';

class RecurringExpensesScreen extends StatefulWidget {
  const RecurringExpensesScreen({super.key});

  @override
  State<RecurringExpensesScreen> createState() => _RecurringExpensesScreenState();
}

class _RecurringExpensesScreenState extends State<RecurringExpensesScreen> with TickerProviderStateMixin {
  final RecurringExpenseService _recurringExpenseService = RecurringExpenseService();
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  // Definición de colores consistentes
  static const Color primaryPurple = Color(0xFF7C3AED);
  static const Color darkPurple = Color(0xFF5B21B6);
  static const Color deepPurple = Color(0xFF4C1D95);
  static const Color successGreen = Color(0xFF059669);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFDC2626);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color darkBlue = Color(0xFF1D4ED8);
  static const Color darkYellow = Color(0xFFD97706);

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
    await _recurringExpenseService.loadRecurringExpenses();
    _summary = _recurringExpenseService.getRecurringExpensesSummary();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _animationController.forward();
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
                    colors: [primaryPurple, darkPurple],
                  ),
                ),
                child: const Icon(
                  Icons.autorenew_rounded,
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
                'Cargando gastos automáticos...',
                style: TextStyle(
                  color: textMedium,
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
        onRefresh: _loadData,
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
                      child: Column(
                        children: [
                          _buildSummarySection(),
                          _buildQuickActions(),
                          _buildRecurringExpensesList(),
                          const SizedBox(height: 120),
                        ],
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
              colors: [
                primaryPurple,
                darkPurple,
                deepPurple,
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gastos Automáticos',
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
                              'Configura y controla tus gastos recurrentes',
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
                      Row(
                        children: [
                          _buildHeaderAction(
                            Icons.refresh_rounded,
                            'Procesar gastos de hoy',
                            _processRecurringExpenses,
                          ),
                          const SizedBox(width: 8),
                          _buildHeaderAction(
                            Icons.add_rounded,
                            'Agregar gasto recurrente',
                            _navigateToAddRecurringExpense,
                          ),
                        ],
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

  Widget _buildHeaderAction(IconData icon, String tooltip, VoidCallback onPressed) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.2),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(20),
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
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [primaryPurple, darkPurple],
                  ),
                ),
                child: const Icon(
                  Icons.autorenew_rounded,
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
                      'Resumen de Gastos Automáticos',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Control inteligente de tus gastos recurrentes',
                      style: TextStyle(
                        color: textMedium,
                        fontSize: 14,
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
                  'Gastos Activos',
                  '${_summary['totalActive'] ?? 0}',
                  'configurados',
                  successGreen,
                  Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  'Estimado Mensual',
                  FormatUtils.formatMoney(_summary['estimatedMonthly'] ?? 0),
                  'promedio',
                  infoBlue,
                  Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: backgroundCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderLight,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      color: primaryPurple,
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Proyección de Gastos',
                      style: TextStyle(
                        color: textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildProjectionItem(
                        'Diario',
                        FormatUtils.formatMoney(_summary['estimatedDaily'] ?? 0),
                        Icons.today_rounded,
                      ),
                    ),
                    Expanded(
                      child: _buildProjectionItem(
                        'Semanal',
                        FormatUtils.formatMoney(_summary['estimatedWeekly'] ?? 0),
                        Icons.date_range_rounded,
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

  Widget _buildSummaryCard(String title, String value, String subtitle, Color color, IconData icon) {
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
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionItem(String period, String amount, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0), // Añadir padding
      child: Row(
        children: [
          Icon(
            icon,
            color: textMedium,
            size: 14,
          ),
          const SizedBox(width: 4), // Reducido de 6 a 4
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period,
                  style: const TextStyle(
                    color: textMedium,
                    fontSize: 10, // Reducido de 11 a 10
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  amount,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 12, // Reducido de 13 a 12
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis, // Añadido
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
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
                  'Transporte Diario',
                  'Bus, taxi, gasolina',
                  Icons.directions_bus_rounded,
                  const LinearGradient(
                    colors: [infoBlue, darkBlue],
                  ),
                  _createTransportExpense,
                ),
              ),
              const SizedBox(width: 12), // Cambiado de 16 a 12
              Expanded(
                child: _buildQuickActionCard(
                  'Suscripciones',
                  'Netflix, Spotify, etc',
                  Icons.subscriptions_rounded,
                  const LinearGradient(
                    colors: [warningYellow, darkYellow],
                  ),
                  _createSubscriptionExpense,
                ),
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildRecurringExpensesList() {
    final expenses = _recurringExpenseService.recurringExpenses;

    if (expenses.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Mis Gastos Recurrentes',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryPurple.withOpacity(0.2),
                  ),
                ),
                child: Text(
                  '${expenses.length} ${expenses.length == 1 ? 'gasto' : 'gastos'}',
                  style: const TextStyle(
                    color: primaryPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...expenses.map((expense) => _buildRecurringExpenseCard(expense)),
        ],
      ),
    );
  }

  Widget _buildRecurringExpenseCard(RecurringExpense expense) {
    return Container(
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
          color: borderLight,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: expense.isActive
                        ? primaryPurple.withOpacity(0.1)
                        : textMedium.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      expense.categoryIcon,
                      style: const TextStyle(fontSize: 24),
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
                              expense.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: expense.isActive ? textDark : textMedium,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: expense.isActive
                                  ? successGreen.withOpacity(0.1)
                                  : warningYellow.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  expense.isActive ? Icons.play_circle : Icons.pause_circle,
                                  size: 12,
                                  color: expense.isActive ? successGreen : warningYellow,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  expense.isActive ? 'Activo' : 'Pausado',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: expense.isActive ? successGreen : warningYellow,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        expense.description,
                        style: const TextStyle(
                          color: textMedium,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: infoBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              expense.frequencyName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: infoBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            expense.categoryName,
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
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      FormatUtils.formatMoney(expense.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: expense.isActive ? dangerRed : textMedium,
                      ),
                    ),
                    if (expense.lastProcessed != null)
                      Text(
                        'Último: ${FormatUtils.formatDateForList(expense.lastProcessed!)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: textMedium,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: backgroundCard,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border(
                top: BorderSide(
                  color: borderLight,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    expense.isActive ? Icons.pause : Icons.play_arrow,
                    expense.isActive ? 'Pausar' : 'Activar',
                    expense.isActive ? warningYellow : successGreen,
                        () => _toggleExpense(expense),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    Icons.edit_outlined,
                    'Editar',
                    infoBlue,
                        () => _editExpense(expense),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    Icons.delete_outline,
                    'Eliminar',
                    dangerRed,
                        () => _deleteExpense(expense),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onPressed) {
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
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        border: Border.all(
          color: borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withOpacity(0.05),
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
                colors: [primaryPurple, darkPurple],
              ),
            ),
            child: const Icon(
              Icons.autorenew_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Automatiza tus gastos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'Configura gastos que se repiten automáticamente y mantén el control de tus finanzas sin esfuerzo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textMedium,
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: infoBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: infoBlue.withOpacity(0.2),
              ),
            ),
            child: const Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: infoBlue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Tips para empezar',
                      style: TextStyle(
                        color: infoBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.repeat,
                          color: successGreen,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Suscripciones mensuales (Netflix, Spotify)',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.directions_bus,
                          color: successGreen,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Transporte diario (bus, gasolina)',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.home,
                          color: successGreen,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Servicios del hogar (agua, luz, internet)',
                            style: TextStyle(
                              color: textDark,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _navigateToAddRecurringExpense();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [primaryPurple, darkPurple],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: primaryPurple.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Crear gasto automático',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método para navegar a la pantalla de agregar gasto recurrente
  void _navigateToAddRecurringExpense() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddRecurringExpenseScreen(),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  // Método para procesar gastos recurrentes del día
  Future<void> _processRecurringExpenses() async {
    try {
      // Mostrar diálogo de carga
      showDialog(
        context: context,
        barrierDismissible: false,
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
                    gradient: const LinearGradient(
                      colors: [primaryPurple, darkPurple],
                    ),
                  ),
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Procesando gastos automáticos...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryPurple),
                  strokeWidth: 3,
                ),
              ],
            ),
          );
        },
      );

      // Procesar gastos recurrentes
      await _recurringExpenseService.processRecurringExpenses();

      // Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      // Mostrar mensaje de éxito
      _showProcessMessage(
        'Gastos procesados exitosamente',
        'Se han creado las transacciones correspondientes a los gastos automáticos de hoy.',
        successGreen,
        Icons.check_circle_rounded,
      );

      // Recargar datos
      _loadData();
    } catch (e) {
      // Cerrar diálogo de carga si está abierto
      if (mounted) Navigator.pop(context);

      // Mostrar mensaje de error
      _showProcessMessage(
        'Error al procesar gastos',
        'Ocurrió un error al procesar los gastos automáticos. Inténtalo de nuevo.',
        dangerRed,
        Icons.error_rounded,
      );
    }
  }

  // Método para mostrar mensajes de resultado del procesamiento
  void _showProcessMessage(String title, String message, Color color, IconData icon) {
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

  // Método para crear gasto de transporte rápido
  void _createTransportExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddRecurringExpenseScreen(
          prefilledCategory: 'Transporte',
          prefilledIcon: '🚌',
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  // Método para crear gasto de suscripción rápido
  void _createSubscriptionExpense() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddRecurringExpenseScreen(
          prefilledCategory: 'Entretenimiento',
          prefilledIcon: '📺',
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  // Método para alternar estado activo/pausado de un gasto
  Future<void> _toggleExpense(RecurringExpense expense) async {
    try {
      await _recurringExpenseService.toggleRecurringExpense(expense.id!);

      String statusText = expense.isActive ? 'pausado' : 'activado';
      Color statusColor = expense.isActive ? warningYellow : successGreen;

      _showProcessMessage(
        'Gasto $statusText',
        'El gasto "${expense.name}" ha sido $statusText correctamente.',
        statusColor,
        expense.isActive ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
      );

      _loadData();
    } catch (e) {
      _showProcessMessage(
        'Error',
        'No se pudo cambiar el estado del gasto. Inténtalo de nuevo.',
        dangerRed,
        Icons.error_rounded,
      );
    }
  }

  // Método para editar un gasto recurrente
  void _editExpense(RecurringExpense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecurringExpenseScreen(
          expenseToEdit: expense,
        ),
      ),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  // Método para eliminar un gasto recurrente
  Future<void> _deleteExpense(RecurringExpense expense) async {
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
                '¿Eliminar gasto automático?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: dangerRed,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Esta acción no se puede deshacer. El gasto "${expense.name}" será eliminado permanentemente.',
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
                          color: borderLight,
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
                          await _recurringExpenseService.deleteRecurringExpense(expense.id!);

                          _showProcessMessage(
                            'Gasto eliminado',
                            'El gasto "${expense.name}" ha sido eliminado correctamente.',
                            dangerRed,
                            Icons.delete_rounded,
                          );

                          _loadData();
                        } catch (e) {
                          _showProcessMessage(
                            'Error',
                            'No se pudo eliminar el gasto. Inténtalo de nuevo.',
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
}