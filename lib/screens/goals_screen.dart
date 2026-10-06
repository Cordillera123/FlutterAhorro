import 'package:flutter/material.dart';
import 'tab_add_action.dart';
import 'package:flutter/services.dart';
import '../models/financial_goal.dart';
import '../services/goal_service.dart';
import '../services/account_service.dart';
import '../utils/format_utils.dart';
import 'create_goal_screen.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';
import '../widgets/goal_contributions_sheet.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with TickerProviderStateMixin
    implements TabAddActionHost {
  final GoalService _goalService = GoalService();
  final AccountService _accountService = AccountService();
  bool _isLoading = true;
  GoalSummary? _summary;
  ContributionStats? _contributionStats;
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
  static const Color purpleAccent = AppColors.primaryPurple;
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
    _goalService.addListener(_onGoalsChanged);
  }

  void _onAccountChanged() {
    if (mounted) {
      _loadData();
    }
  }

  void _onGoalsChanged() {
    if (mounted) {
      _loadData();
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

  Future<void> _loadData() async {
    await _goalService.loadGoals();
    _summary = _goalService.getGoalSummary();
    _contributionStats = _goalService.getContributionStats();

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
    _accountService.removeListener(_onAccountChanged);
    _goalService.removeListener(_onGoalsChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: backgroundLight,
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
          ),
        ),
      );
    }

    // Abierta desde un recordatorio no hay botón global ni barra inferior:
    // la pantalla pone su propio "Agregar" y su flecha de volver.
    final standalone = !TabHostScope.isHosted(context);

    return Scaffold(
      backgroundColor: backgroundLight,
      floatingActionButton: standalone
          ? AppAddFab(onPressed: _navigateToCreateGoal, tooltip: 'Crear meta')
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: primaryBlue,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildModernAppBar(standalone: standalone),
            SliverToBoxAdapter(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: Opacity(
                      opacity: _fadeInAnimation.value,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSummaryCard(),
                            const SizedBox(height: 24),
                            _buildGoalHealthIndicator(),
                            const SizedBox(height: 24),
                            _buildQuickActions(),
                            const SizedBox(height: 32),
                            _buildGoalsList(),
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

  Widget _buildModernAppBar({required bool standalone}) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: backgroundLight,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      // Sola: flecha propia y el título más abajo para que no se encimen.
      automaticallyImplyLeading: false,
      leading: standalone ? const AppBackButton(light: true) : null,
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
              padding: EdgeInsets.fromLTRB(24, standalone ? 48 : 16, 24, 24),
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
                              'Mis Metas',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Alcanza tus sueños paso a paso',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
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

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
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
                  color: purpleAccent.withOpacity(0.1),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: purpleAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen de Metas',
                      style: TextStyle(
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tu progreso hacia la libertad financiera',
                      style: TextStyle(color: textMedium, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  'Total Objetivo',
                  FormatUtils.formatMoney(_summary?.totalTargetAmount ?? 0),
                  primaryBlue,
                  Icons.track_changes_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMetric(
                  'Ahorrado',
                  FormatUtils.formatMoney(_summary?.totalCurrentAmount ?? 0),
                  successGreen,
                  Icons.savings_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  'Progreso',
                  '${((_summary?.overallProgress ?? 0) * 100).toStringAsFixed(1)}%',
                  purpleAccent,
                  Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryMetric(
                  'Metas Activas',
                  '${_summary?.activeGoals ?? 0}',
                  warningYellow,
                  Icons.rocket_launch_rounded,
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
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: textMedium,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalHealthIndicator() {
    final isHealthy = _summary?.isHealthy ?? true;
    final urgentGoals = _summary?.urgentGoals ?? 0;
    final onTrackGoals = _summary?.onTrackGoals ?? 0;
    final activeGoals = _summary?.activeGoals ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: (isHealthy ? successGreen : warningYellow).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: (isHealthy ? successGreen : warningYellow).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: (isHealthy ? successGreen : warningYellow).withOpacity(
                0.1,
              ),
            ),
            child: Icon(
              isHealthy ? Icons.check_circle_rounded : Icons.warning_rounded,
              color: isHealthy ? successGreen : warningYellow,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHealthy ? 'Metas en buen camino' : 'Necesita atención',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isHealthy ? successGreen : warningYellow,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isHealthy
                      ? '$onTrackGoals de $activeGoals metas van según lo planeado'
                      : urgentGoals > 0
                      ? '$urgentGoals metas urgentes requieren atención'
                      : 'Algunas metas están atrasadas',
                  style: const TextStyle(fontSize: 12, color: textMedium),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                title: 'Meta de Compra',
                subtitle: 'Para algo específico',
                icon: Icons.shopping_bag_rounded,
                gradientColors: const [primaryBlue, darkBlue],
                onTap: () {
                  HapticFeedback.lightImpact();
                  _createQuickGoal(GoalType.purchase);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionCard(
                title: 'Fondo de Emergencia',
                subtitle: 'Para imprevistos',
                icon: Icons.security_rounded,
                gradientColors: const [dangerRed, Color(0xFFEF4444)],
                onTap: () {
                  HapticFeedback.lightImpact();
                  _createQuickGoal(GoalType.emergency);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickActionCard(
                title: 'Vacaciones',
                subtitle: 'Tu próximo viaje',
                icon: Icons.flight_rounded,
                gradientColors: const [successGreen, AppColors.emeraldGreen],
                onTap: () {
                  HapticFeedback.lightImpact();
                  _createQuickGoal(GoalType.vacation);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionCard(
                title: 'Educación',
                subtitle: 'Invierte en ti',
                icon: Icons.school_rounded,
                gradientColors: const [purpleAccent, Color(0xFF8B5CF6)],
                onTap: () {
                  HapticFeedback.lightImpact();
                  _createQuickGoal(GoalType.education);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalsList() {
    final activeGoals = _goalService.activeGoals;
    final pausedGoals = _goalService.pausedGoals;
    final completedGoals = _goalService.completedGoals;
    final totalGoals = activeGoals.length + pausedGoals.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mis Metas ($totalGoals/15)',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textDark,
          ),
        ),
        const SizedBox(height: 16),
        if (totalGoals == 0)
          _buildEmptyState()
        else ...[
          // Metas activas
          if (activeGoals.isNotEmpty) ...[
            ...activeGoals.map((goal) => _buildGoalCard(goal)),
          ],
          // Metas pausadas
          if (pausedGoals.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Metas Pausadas (${pausedGoals.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textMedium,
              ),
            ),
            const SizedBox(height: 8),
            ...pausedGoals.map((goal) => _buildGoalCard(goal)),
          ],
        ],
        // Metas completadas: antes desaparecían de la lista al llegar al
        // objetivo (sin forma de verlas, editarlas ni eliminarlas). No ocupan
        // cupo del límite de 15.
        if (completedGoals.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Metas Completadas (${completedGoals.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textMedium,
            ),
          ),
          const SizedBox(height: 8),
          ...completedGoals.map((goal) => _buildGoalCard(goal)),
        ],
      ],
    );
  }

  /// Acceso a la lista de aportes de la meta, para editarlos o eliminarlos
  /// desde aquí (sin ir al historial).
  Widget _buildContributionsLink(FinancialGoal goal, int count) {
    return Material(
      color: primaryBlue.withOpacity(0.06),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showGoalContributionsSheet(
          context,
          goalId: goal.id!,
          onAddContribution: goal.status == GoalStatus.active
              ? () => _addContribution(goal)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                color: primaryBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  count == 1
                      ? '1 aporte · Ver y editar'
                      : '$count aportes · Ver y editar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primaryBlue,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: primaryBlue,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalCard(FinancialGoal goal) {
    final isPaused = goal.status == GoalStatus.paused;
    final contributionCount = goal.id == null
        ? 0
        : _goalService.getGoalContributions(goal.id!).length;

    return Opacity(
      opacity: isPaused ? 0.7 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(isPaused ? 0.05 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(
            color: isPaused
                ? Colors.grey.withOpacity(0.3)
                : goal.priorityColor.withOpacity(0.2),
            width: isPaused ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emoji - tamaño fijo
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: goal.priorityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            goal.emoji,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Nombre y tipo - flexible para adaptarse
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    goal.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isPaused) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: warningYellow.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: warningYellow.withOpacity(0.3),
                                      ),
                                    ),
                                    child: const Text(
                                      'PAUSADA',
                                      style: TextStyle(
                                        color: warningYellow,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${goal.typeName} • ${goal.priorityName}',
                              style: TextStyle(
                                color: goal.priorityColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Montos movidos aquí para mejor distribución
                            Row(
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      FormatUtils.formatMoney(
                                        goal.currentAmount,
                                      ),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: goal.progressColor,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  ' de ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textMedium,
                                  ),
                                ),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      FormatUtils.formatMoney(
                                        goal.targetAmount,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textDark,
                                      ),
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
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${(goal.progressPercentage * 100).toStringAsFixed(1)}% completado',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              goal.timeInfo,
                              style: TextStyle(
                                fontSize: 12,
                                color: goal.isOverdue ? dangerRed : textMedium,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: goal.progressPercentage.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            goal.progressColor,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                  if (contributionCount > 0) ...[
                    const SizedBox(height: 10),
                    _buildContributionsLink(goal, contributionCount),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: goal.priorityColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      goal.mainTip,
                      style: TextStyle(
                        fontSize: 13,
                        color: goal.priorityColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: backgroundCard,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  if (goal.status == GoalStatus.active) ...[
                    Expanded(
                      child: _buildGoalActionButton(
                        Icons.add_rounded,
                        'Aportar',
                        successGreen,
                        () => _addContribution(goal),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: _buildGoalActionButton(
                      Icons.edit_rounded,
                      'Editar',
                      primaryBlue,
                      () => _editGoal(goal),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Pausar/Reanudar solo aplica a metas en curso (en una
                  // completada el botón no hacía nada).
                  if (goal.status != GoalStatus.completed) ...[
                    Expanded(
                      child: _buildGoalActionButton(
                        goal.status == GoalStatus.active
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        goal.status == GoalStatus.active
                            ? 'Pausar'
                            : 'Reanudar',
                        goal.status == GoalStatus.active
                            ? warningYellow
                            : successGreen,
                        () => _toggleGoalStatus(goal),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: _buildGoalActionButton(
                      Icons.delete_rounded,
                      'Eliminar',
                      dangerRed,
                      () => _deleteGoal(goal),
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

  Widget _buildGoalActionButton(
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(height: 2),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
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
      icon: Icons.flag_outlined,
      title: 'Sin metas activas',
      message:
          'Crea tu primera meta financiera y comienza a ahorrar para '
          'tus sueños',
      ctaLabel: 'Crear mi primera meta',
      onCta: _navigateToCreateGoal,
    );
  }

  // Métodos de navegación y acciones
  // Botón flotante global "Agregar" (MainNavigationScreen).
  @override
  void onAddPressed() => _navigateToCreateGoal();

  void _navigateToCreateGoal() async {
    // Verificar límite de metas
    if (!_goalService.canCreateMoreGoals) {
      _showMessage(
        'Límite Alcanzado',
        'Has alcanzado el límite máximo de 15 metas. Elimina o completa algunas metas para crear nuevas.',
        warningYellow,
        Icons.warning_rounded,
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGoalScreen()),
    );

    if (result == true) {
      _refreshData();
    }
  }

  void _createQuickGoal(GoalType type) async {
    // Verificar límite de metas
    if (!_goalService.canCreateMoreGoals) {
      _showMessage(
        'Límite Alcanzado',
        'Has alcanzado el límite máximo de 15 metas. Elimina o completa algunas metas para crear nuevas.',
        warningYellow,
        Icons.warning_rounded,
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGoalScreen(preselectedType: type),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  void _editGoal(FinancialGoal goal) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateGoalScreen(goalToEdit: goal),
      ),
    );

    if (result == true) {
      _refreshData();
    }
  }

  void _addContribution(FinancialGoal goal) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController amountController = TextEditingController();
        final TextEditingController noteController = TextEditingController();
        bool isSubmitting = false;
        String? amountError;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: successGreen.withOpacity(0.1),
                    border: Border.all(
                      color: successGreen.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: successGreen,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aportar a ${goal.name}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textDark,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  // Mismo campo de monto que el resto de la app: decimales
                  // con punto o coma. Antes "10,50" se guardaba como 1050.
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [AmountInputFormatter()],
                  onChanged: (_) {
                    if (amountError != null) {
                      setDialogState(() => amountError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Monto a aportar',
                    hintText: FormatUtils.amountHint(),
                    errorText: amountError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: Icon(FormatUtils.currencyIcon),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: noteController,
                  decoration: InputDecoration(
                    labelText: 'Nota (opcional)',
                    hintText: 'Ej: Ahorro del mes',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.note),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final amount = double.tryParse(amountController.text);
                        if (amount == null || !amount.isFinite || amount <= 0) {
                          // Antes no pasaba nada al tocar "Aportar".
                          setDialogState(
                            () => amountError = 'Ingresa un monto mayor a 0',
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          final note = noteController.text.trim();
                          await _goalService.addContribution(
                            goal.id!,
                            amount,
                            note: note.isNotEmpty ? note : null,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            _refreshData();
                            _showMessage(
                              'Aporte exitoso',
                              'Se agregaron ${FormatUtils.formatMoney(amount)} a tu meta',
                              successGreen,
                              Icons.check_circle_rounded,
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          _showMessage(
                            'Error',
                            'No se pudo agregar el aporte',
                            dangerRed,
                            Icons.error_rounded,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: successGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Aportar',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleGoalStatus(FinancialGoal goal) async {
    try {
      if (goal.status == GoalStatus.active) {
        await _goalService.pauseGoal(goal.id!);
        _showMessage(
          'Meta Pausada',
          'La meta "${goal.name}" ha sido pausada correctamente. Puedes reanudarla cuando desees.',
          warningYellow,
          Icons.pause_rounded,
        );
      } else if (goal.status == GoalStatus.paused) {
        await _goalService.resumeGoal(goal.id!);
        _showMessage(
          'Meta Reanudada',
          'La meta "${goal.name}" ha sido reactivada correctamente.',
          successGreen,
          Icons.play_arrow_rounded,
        );
      }
      await _refreshData();
    } catch (e) {
      _showMessage(
        'Error',
        'No se pudo cambiar el estado de la meta: ${e.toString()}',
        dangerRed,
        Icons.error_rounded,
      );
    }
  }

  Future<void> _deleteGoal(FinancialGoal goal) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Eliminar?',
      message: '¿Eliminar "${goal.name}"? Esta acción no se puede deshacer.',
      extra: goal.currentAmount > 0
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: warningYellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Ahorrado: ${FormatUtils.formatMoney(goal.currentAmount)}\n'
                'Los aportes seguirán en tu historial como gastos de '
                '"Ahorros e Inversión".',
                style: TextStyle(
                  fontSize: 11,
                  color: warningYellow,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
    if (confirmed != true) return;

    try {
      await _goalService.deleteGoal(goal.id!);
      _showMessage(
        'Eliminada',
        'La meta ha sido eliminada.',
        successGreen,
        Icons.check_circle_rounded,
      );
      await _refreshData();
    } catch (e) {
      _showMessage(
        'Error',
        'No se pudo eliminar la meta.',
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
