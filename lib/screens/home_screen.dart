import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../services/recurring_expense_service.dart';
import '../services/stats_service.dart';
import '../services/category_service.dart';
import '../services/account_service.dart';
import '../services/goal_service.dart';
import '../services/security_service.dart';
import '../services/reminder_service.dart';
import '../services/dashboard/smart_dashboard_service.dart';
import '../models/dashboard/smart_dashboard_data.dart';
import '../models/reminder.dart';
import '../utils/format_utils.dart';
import '../widgets/app_logo.dart';
import '../widgets/account_selector.dart';
import '../widgets/calendar/home_calendar_card.dart';
import '../widgets/transaction_actions_sheet.dart';
import '../widgets/dashboard/achievement_card.dart';
import '../widgets/dashboard/dashboard_theme.dart';
import 'achievements_screen.dart';
import 'add_transaction_screen.dart';
import 'financial_insights_screen.dart';
import 'recurring_expenses_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'manage_accounts_screen.dart';
import 'create_transfer_screen.dart';
import 'export_screen.dart';
import '../models/export_config.dart';
import 'history_screen.dart';
import 'goals_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';

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
  final AccountService _accountService = AccountService();
  final GoalService _goalService = GoalService();
  final SecurityService _securityService = SecurityService();
  final SmartDashboardService _dashboardService = SmartDashboardService();
  final ReminderService _reminderService = ReminderService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  bool _isRefreshing = false;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  FinancialStats? _financialStats;
  SmartDashboardData? _dashboardData;
  List<Reminder> _reminders = [];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadData();

    // NUEVO: Escuchar cambios en el TransactionService
    _transactionService.addListener(_onTransactionServiceChanged);
    // Escuchar cambios en CategoryService (para actualizar nombres/emojis)
    _categoryService.addListener(_onCategoryServiceChanged);
    // Escuchar cambios de cuenta activa
    _accountService.addListener(_onAccountChanged);
    // Escuchar cambios en metas (afectan la puntuación y los logros)
    _goalService.addListener(_onGoalServiceChanged);
    // Escuchar cambios en la preferencia de ocultar saldos
    _securityService.addListener(_onSecurityServiceChanged);
  }

  void _onSecurityServiceChanged() {
    if (mounted) setState(() {});
  }

  // NUEVO: Método que se ejecuta cuando el TransactionService notifica cambios
  void _onTransactionServiceChanged() {
    if (mounted) {
      _updateStats();
      setState(() {
        // Forzar rebuild cuando cambien los datos del servicio
      });
      _loadDashboardData(forceRefresh: true);
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

  // Método que se ejecuta cuando cambia la cuenta activa
  void _onAccountChanged() {
    if (mounted) {
      _updateStats();
      setState(() {
        // Recargar datos para la nueva cuenta activa
      });
      _loadDashboardData(forceRefresh: true);
    }
  }

  // Método que se ejecuta cuando GoalService notifica cambios (metas/contribuciones)
  void _onGoalServiceChanged() {
    if (mounted) {
      _loadDashboardData(forceRefresh: true);
    }
  }

  void _updateStats() {
    _financialStats = _statsService.getCurrentVsPreviousStats();
  }

  // Alimenta el resumen de insight y la vitrina de logros de Inicio.
  // Es intencionalmente silencioso ante errores: el análisis es un módulo
  // de solo lectura y complementario; si falla, el resto de Inicio sigue
  // funcionando con normalidad.
  Future<void> _loadDashboardData({bool forceRefresh = false}) async {
    try {
      final data = await _dashboardService.getDashboardData(
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _dashboardData = data;
          // Los recordatorios dependen de gastos recurrentes y metas, ambos
          // ya cargados en memoria (las metas las carga el propio dashboard
          // service) — se recalculan aquí para no repetir la lectura.
          _reminders = _reminderService.buildReminders();
        });
      }
    } catch (e) {
      // Silencioso: el Dashboard es complementario, no debe romper Inicio.
    }
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

  Future<void> _loadData({bool forceRefreshDashboard = false}) async {
    try {
      await _transactionService.loadTransactions();
      await _recurringExpenseService.loadRecurringExpenses();
      await _recurringExpenseService.processRecurringExpensesForToday();

      _updateStats();
      await _loadDashboardData(forceRefresh: forceRefreshDashboard);

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
    await _loadData(forceRefreshDashboard: true);
  }

  @override
  void dispose() {
    // NUEVO: Remover el listener cuando se destruye el widget
    _transactionService.removeListener(_onTransactionServiceChanged);
    _categoryService.removeListener(_onCategoryServiceChanged);
    _accountService.removeListener(_onAccountChanged);
    _goalService.removeListener(_onGoalServiceChanged);
    _securityService.removeListener(_onSecurityServiceChanged);
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
      backgroundColor: const Color(0xFFF1F5F9),
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
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInsightEntryCard(),
                                if (_reminders.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  _buildRemindersSection(),
                                ],
                                const SizedBox(height: 24),
                                _buildFinancialOverview(),
                                const SizedBox(height: 20),
                                const HomeCalendarCard(),
                                const SizedBox(height: 28),
                                ..._buildAchievementsPreview(),
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
                          Color(0xFF059669),
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
    final hasNoTransactions = _transactionService.transactions.isEmpty;
    return SliverAppBar(
      expandedHeight: hasNoTransactions ? 258 : 210,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF059669),
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF059669), Color(0xFF047857), Color(0xFF065F46)],
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
                  // Header: menú (izquierda) + saludo (centro)
                  Row(
                    children: [
                      _buildMenuButton(),
                      Expanded(
                        child: Text(
                          FormatUtils.getGreeting(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // Balancear con mismo ancho que botón menú
                      const SizedBox(width: 44),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Selector de cuenta como chip centrado
                  _buildAccountChip(),
                  const Spacer(),
                  // Balance
                  _buildBalancePreview(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountChip() {
    final account = _accountService.activeAccount;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showAccountSelectorSheet(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(account.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                account.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 16),
          ],
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
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [_buildDrawerContent()]),
              ),
            ),
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

  Widget _buildDrawerContent() {
    return Column(
      children: [
        // Header del drawer
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF34D399), Color(0xFF059669), Color(0xFF047857)],
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
        // Opción de cuentas
        _buildDrawerItem(
          icon: Icons.account_balance_outlined,
          title: 'Mis Cuentas',
          subtitle: 'Gestiona tus cuentas financieras',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ManageAccountsScreen(),
              ),
            );
          },
        ),
        const Divider(height: 16),
        _buildDrawerItem(
          icon: Icons.auto_awesome_outlined,
          title: 'Insight financiero',
          subtitle: 'Análisis, predicciones y consejos',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FinancialInsightsScreen(),
              ),
            );
          },
        ),
        _buildDrawerItem(
          icon: Icons.emoji_events_outlined,
          title: 'Logros',
          subtitle: 'Tus trofeos y lo que viene',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AchievementsScreen(),
              ),
            );
          },
        ),
        const Divider(height: 16),
        // Opciones del menú
        _buildDrawerItem(
          icon: Icons.category_outlined,
          title: 'Categorías de gastos',
          subtitle: 'Personaliza tus categorías',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
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
          color: const Color(0xFF059669).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF059669), size: 22),
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
    final hasNoTransactions = _transactionService.transactions.isEmpty;

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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Balance',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _securityService.setHideBalances(
                  !_securityService.hideBalances,
                ),
                child: Icon(
                  _securityService.hideBalances
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 15,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _securityService.hideBalances
                  ? '••••••'
                  : FormatUtils.formatMoney(_transactionService.totalBalance),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          // Botón de balance inicial — visible solo cuando no hay transacciones
          if (hasNoTransactions) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showInitialBalanceDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Establecer balance inicial',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showInitialBalanceDialog() {
    final controller = TextEditingController(
      text: _accountService.activeAccount.initialBalance > 0
          ? _accountService.activeAccount.initialBalance.toStringAsFixed(2)
          : '',
    );
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Color(0xFF059669),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Balance inicial',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'El dinero que ya tienes antes de comenzar',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Campo de monto
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.5,
                      ),
                      decoration: InputDecoration(
                        prefixText: '\$  ',
                        prefixStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF059669),
                        ),
                        hintText: '0.00',
                        hintStyle: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B).withOpacity(0.4),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF059669),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Puedes cambiarlo después desde esta misma pantalla',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF64748B).withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Botón guardar
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final raw = controller.text
                                    .replaceAll(',', '.')
                                    .trim();
                                final amount = double.tryParse(raw) ?? 0.0;
                                setModalState(() => isSaving = true);
                                final nav = Navigator.of(context);
                                await _accountService.updateInitialBalance(
                                  _accountService.activeAccountId,
                                  amount,
                                );
                                nav.pop();
                                if (mounted) setState(() {});
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Guardar balance inicial',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Acceso al análisis completo. En Inicio solo mostramos el titular: la
  // puntuación, una frase y, si las hay, cuántas cosas conviene revisar.
  // El detalle vive en FinancialInsightsScreen para no saturar la pantalla.
  Widget _buildInsightEntryCard() {
    final data = _dashboardData;
    final score = data?.health.score ?? 0;
    final ready = data != null && data.hasSufficientData;
    final color = ready
        ? DashboardTheme.healthColor(score)
        : const Color(0xFF64748B);

    final headline = data == null
        ? 'Analizando tus finanzas...'
        : (ready
              ? data.summary.message
              : 'Registra algunos movimientos y te contamos cómo vas');
    final alertCount = data?.alerts.length ?? 0;

    return GestureDetector(
      onTap: _navigateToInsights,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildScoreBadge(score, color, ready),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 15,
                            color: color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Insight financiero',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
              ],
            ),
            if (alertCount > 0) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warningYellow.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      size: 16,
                      color: AppColors.deepYellow,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alertCount == 1
                            ? 'Hay 1 cosa que conviene revisar'
                            : 'Hay $alertCount cosas que conviene revisar',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepYellow,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersSection() {
    final visible = _reminders.take(4).toList();
    final overflow = _reminders.length - visible.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Recordatorios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...visible.map(_buildReminderTile),
          if (overflow > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'y $overflow más',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReminderTile(Reminder reminder) {
    return GestureDetector(
      onTap: () => _onReminderTap(reminder),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: reminder.accentColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: reminder.accentColor.withValues(alpha: 0.12),
              ),
              child: Icon(reminder.icon, color: reminder.accentColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    reminder.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _onReminderTap(Reminder reminder) {
    HapticFeedback.lightImpact();
    switch (reminder.type) {
      case ReminderType.recurringExpense:
        _navigateToRecurringExpenses();
        break;
      case ReminderType.goalDeadline:
      case ReminderType.goalOffTrack:
        _navigateToGoals();
        break;
    }
  }

  Future<void> _navigateToGoals() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GoalsScreen()),
    );
    if (mounted) {
      setState(() {
        _reminders = _reminderService.buildReminders();
      });
    }
  }

  Widget _buildScoreBadge(int score, Color color, bool ready) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 2),
      ),
      child: Center(
        child: ready
            ? Text(
                '$score',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              )
            : Icon(Icons.insights_rounded, color: color, size: 22),
      ),
    );
  }

  // Vitrina de trofeos: refuerzo positivo en Inicio sin datos densos.
  // El detalle y los logros pendientes viven en AchievementsScreen.
  List<Widget> _buildAchievementsPreview() {
    final data = _dashboardData;
    if (data == null) return const [];

    final unlocked = data.unlockedAchievements;
    final total = data.totalAchievementCount;

    final section = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Tus logros',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            if (total > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warningYellow.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${unlocked.length}/$total',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepYellow,
                  ),
                ),
              ),
            const Spacer(),
            GestureDetector(
              onTap: _navigateToAchievements,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(
                  'Ver todos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.deepYellow,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (unlocked.isEmpty)
          _buildNoAchievementsYet(data)
        else
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: unlocked.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) => AchievementChip(
                achievement: unlocked[index],
                onTap: _navigateToAchievements,
              ),
            ),
          ),
      ],
    );

    return [section, const SizedBox(height: 28)];
  }

  Widget _buildNoAchievementsYet(SmartDashboardData data) {
    // La lista bloqueada llega ordenada por progreso. Sin ningún avance real
    // cualquier sugerencia sería arbitraria, así que preferimos el mensaje
    // genérico antes que proponer una meta lejana al azar.
    final closest = data.lockedAchievements.isNotEmpty
        ? data.lockedAchievements.first
        : null;
    final next = (closest != null && closest.progress > 0) ? closest : null;

    return GestureDetector(
      onTap: _navigateToAchievements,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          border: Border.all(
            color: AppColors.warningYellow.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.warningYellow.withValues(alpha: 0.12),
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: AppColors.warningYellow,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu primer trofeo te espera',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    next?.nextGoalLabel ?? 'Registra tu primer movimiento',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
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
              const SizedBox(width: 8),
              Flexible(
                child: AmountText(
                  subtitle ?? '',
                  alignment: Alignment.centerRight,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
          AmountText(
            amount,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
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
              color: AppColors.warningYellow,
              onTap: _navigateToRecurringExpenses,
            ),
            _buildActionCard(
              title: 'Transferir',
              icon: Icons.swap_horiz_rounded,
              color: const Color(0xFF3B82F6),
              onTap: _navigateToTransfer,
            ),
            _buildActionCard(
              title: 'Estadísticas',
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: _navigateToStats,
            ),
            _buildActionCard(
              title: 'Exportar',
              icon: Icons.file_download_outlined,
              color: const Color(0xFF0891B2),
              onTap: _navigateToExport,
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
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
    return AppEmptyState(
      icon: Icons.trending_up_rounded,
      title: 'Comienza tu viaje financiero',
      message:
          'Agrega tu primera transacción para comenzar a controlar tus '
          'finanzas de manera inteligente y serena',
      ctaLabel: 'Agregar Primer Salario',
      onCta: _navigateToAddSalary,
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final Color amountColor;
    final String sign;
    switch (transaction.type) {
      case TransactionType.income:
        amountColor = const Color(0xFF059669);
        sign = '+';
        break;
      case TransactionType.expense:
        amountColor = const Color(0xFFDC2626);
        sign = '-';
        break;
      case TransactionType.transfer:
        amountColor = const Color(0xFF3B82F6);
        sign = (transaction.isTransferOut ?? true) ? '-' : '+';
        break;
    }

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

    // Tocar una reciente abre el detalle con Editar/Eliminar. Home escucha a
    // TransactionService, así que se actualiza sola al volver.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTransactionActions(context, transaction),
      child: Container(
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
                color: amountColor.withOpacity(0.1),
              ),
              child: Center(
                child: Text(
                  categoryEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
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
            Flexible(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(
                    '$sign${FormatUtils.formatMoney(transaction.amount)}',
                    alignment: Alignment.centerRight,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FormatUtils.formatDateForList(transaction.date),
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
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

  Future<void> _navigateToTransfer() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTransferScreen()),
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
      setState(() {
        _reminders = _reminderService.buildReminders();
      });
    }
  }

  void _navigateToInsights() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FinancialInsightsScreen()),
    );
  }

  void _navigateToAchievements() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AchievementsScreen()),
    );
  }

  void _navigateToExport() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ExportScreen(initialConfig: ExportConfig.currentMonth()),
      ),
    );
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

  String _getIncomeGrowthText() {
    final stats = _financialStats;
    if (stats == null || !stats.hasData || !stats.hasPreviousData) {
      return '';
    }

    return _growthText(stats.incomeGrowthPercentage, stats.currentIncome);
  }

  String _getExpenseGrowthText() {
    final stats = _financialStats;
    if (stats == null || !stats.hasData || !stats.hasPreviousData) {
      return '';
    }

    return _growthText(stats.expenseGrowthPercentage, stats.currentExpenses);
  }

  /// Variación vs. el mes anterior. Sin base de comparación (mes anterior en
  /// 0) muestra "Nuevo" si ya hay movimiento este mes, o nada si no.
  String _growthText(double? growth, double current) {
    if (growth == null && current.abs() < 0.005) return '';
    return FormatUtils.formatGrowthLabel(growth, current: current);
  }
}
