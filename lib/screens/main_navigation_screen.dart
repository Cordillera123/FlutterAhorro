import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'budget_screen.dart';
import 'goals_screen.dart';
import 'recurring_expenses_screen.dart';
import 'add_transaction_screen.dart';
import 'lock_screen.dart';
import 'tab_add_action.dart';
import '../models/transaction.dart';
import '../services/security_service.dart';
import '../theme/app_colors.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  late PageController _pageController;
  late AnimationController _tabFadeController;
  late Animation<double> _tabFadeAnimation;

  // Re-bloqueo al volver del segundo plano (si el usuario activó el PIN).
  AppLifecycleState? _lastLifecycleState;
  bool _isShowingLockScreen = false;

  // Definición de colores consistentes
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color primaryGreen = AppColors.primaryGreen;
  static const Color darkGreen = AppColors.darkGreen;
  static const Color primaryRed = AppColors.dangerRed;
  static const Color darkRed = AppColors.darkRed;
  static const Color warningYellow = AppColors.warningYellow;
  static const Color primaryPurple = AppColors.primaryPurple;
  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color backgroundLight = AppColors.backgroundLight;
  static const Color borderLight = AppColors.borderLight;

  // Claves para pedirle a cada pestaña que cree "lo suyo" desde el botón
  // flotante global (ver [TabAddActionHost]).
  final GlobalKey _budgetsKey = GlobalKey(debugLabel: 'tab_budgets');
  final GlobalKey _goalsKey = GlobalKey(debugLabel: 'tab_goals');
  final GlobalKey _recurringKey = GlobalKey(debugLabel: 'tab_recurring');

  late final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Inicio',
      color: primaryGreen,
      screen: const HomeScreen(),
    ),
    NavigationItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Presupuestos',
      color: primaryBlue,
      screen: BudgetsScreen(key: _budgetsKey),
    ),
    NavigationItem(
      icon: Icons.flag_outlined,
      activeIcon: Icons.flag_rounded,
      label: 'Metas',
      color: warningYellow,
      screen: GoalsScreen(key: _goalsKey),
    ),
    NavigationItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      label: 'Historial',
      color: primaryPurple,
      screen: const HistoryScreen(),
    ),
    NavigationItem(
      icon: Icons.autorenew_outlined,
      activeIcon: Icons.autorenew_rounded,
      label: 'Automático',
      color: primaryRed,
      screen: RecurringExpensesScreen(key: _recurringKey),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _tabFadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: 1.0,
    );
    _tabFadeAnimation = CurvedAnimation(
      parent: _tabFadeController,
      curve: Curves.easeOut,
    );
    _initFabAnimation();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Solo re-bloquear al volver de un backgrounding real (paused →
    // resumed), no ante transiciones pasajeras como un diálogo del sistema
    // (inactive) que no llegan a `paused`.
    if (state == AppLifecycleState.resumed &&
        _lastLifecycleState == AppLifecycleState.paused) {
      _maybeShowLockScreen();
    }
    _lastLifecycleState = state;
  }

  Future<void> _maybeShowLockScreen() async {
    if (_isShowingLockScreen || !SecurityService().isLockEnabled) return;
    _isShowingLockScreen = true;

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LockScreen(
          onUnlocked: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ),
    );

    _isShowingLockScreen = false;
  }

  void _initFabAnimation() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );

    _fabAnimationController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fabAnimationController.dispose();
    _tabFadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: FadeTransition(
        opacity: _tabFadeAnimation,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            // Un toque en la barra ya actualizó el índice y vibró; solo los
            // deslizamientos con el dedo llegan aquí con un índice nuevo.
            if (index == _currentIndex) return;
            setState(() {
              _currentIndex = index;
            });
            HapticFeedback.lightImpact();
          },
          itemCount: _navigationItems.length,
          itemBuilder: (context, index) {
            return _navigationItems[index].screen;
          },
        ),
      ),
      bottomNavigationBar: _buildModernBottomNav(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildModernBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: textDark.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: borderLight.withOpacity(0.5), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _navigationItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _buildNavItem(item, index);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(NavigationItem item, int index) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _onNavItemTap(index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? item.color.withOpacity(0.15)
                      : Colors.transparent,
                ),
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  size: 22,
                  color: isSelected ? item.color : textMedium,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? item.color : textMedium,
                  letterSpacing: -0.2,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Botón flotante "Agregar": el mismo en las cinco pestañas (mismo estilo,
  /// posición y texto). Lo que crea depende de la pestaña activa.
  Widget _buildFloatingActionButton() {
    return ScaleTransition(
      scale: _fabAnimation,
      child: FloatingActionButton.extended(
        onPressed: _onAddPressed,
        tooltip: _addTooltip,
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Agregar',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  // Índices de pestaña: 0 Inicio, 1 Presupuestos, 2 Metas, 3 Historial,
  // 4 Automático.
  String get _addTooltip {
    switch (_currentIndex) {
      case 1:
        return 'Crear presupuesto';
      case 2:
        return 'Crear meta';
      case 4:
        return 'Crear gasto automático';
      default:
        return 'Agregar transacción';
    }
  }

  void _onAddPressed() {
    switch (_currentIndex) {
      case 1:
        _requestAddFrom(_budgetsKey);
        break;
      case 2:
        _requestAddFrom(_goalsKey);
        break;
      case 4:
        _requestAddFrom(_recurringKey);
        break;
      default:
        _showAddTransactionOptions();
    }
  }

  void _requestAddFrom(GlobalKey tabKey) {
    final state = tabKey.currentState;
    if (state is TabAddActionHost) {
      HapticFeedback.mediumImpact();
      (state as TabAddActionHost).onAddPressed();
    }
  }

  void _onNavItemTap(int index) {
    HapticFeedback.lightImpact();
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
    });

    // Salto directo + fundido: animateToPage deslizaba por cada pestaña
    // intermedia, construyéndolas y vibrando en cada una.
    _pageController.jumpToPage(index);
    _tabFadeController.forward(from: 0.0);
  }

  void _showAddTransactionOptions() {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildAddTransactionBottomSheet(),
    );
  }

  Widget _buildAddTransactionBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      colors: [primaryBlue, darkBlue],
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nueva Transacción',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Elige el tipo de transacción que deseas registrar',
                        style: TextStyle(
                          fontSize: 15,
                          color: textMedium,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    'Ingreso',
                    'Salario, extras',
                    Icons.trending_up_rounded,
                    primaryGreen,
                    darkGreen,
                    () => _navigateToAddTransaction(TransactionType.income),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionButton(
                    'Gasto',
                    'Comida, transporte',
                    Icons.trending_down_rounded,
                    primaryRed,
                    darkRed,
                    () => _navigateToAddTransaction(TransactionType.expense),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Additional Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryBlue.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Registra tus transacciones al instante para mantener un control preciso de tus finanzas',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    String subtitle,
    IconData icon,
    Color primaryColor,
    Color darkColor,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor.withOpacity(0.1),
              primaryColor.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [primaryColor, darkColor]),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: primaryColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textMedium,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToAddTransaction(TransactionType type) async {
    Navigator.pop(context); // Cerrar el modal

    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddTransactionScreen(initialType: type),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
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

    // Si se agregó una transacción, mostrar feedback
    if (result == true && mounted) {
      _showSuccessFeedback();
    }
  }

  void _showSuccessFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: primaryGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Transacción agregada exitosamente',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: textDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;
  final Widget screen;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
    required this.screen,
  });
}
