import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dashboard/smart_dashboard_data.dart';
import '../services/account_service.dart';
import '../services/dashboard/smart_dashboard_service.dart';
import '../services/goal_service.dart';
import '../services/transaction_service.dart';
import '../widgets/dashboard/alerts_section.dart';
import '../widgets/dashboard/dashboard_theme.dart';
import '../widgets/dashboard/executive_summary_banner.dart';
import '../widgets/dashboard/financial_health_section.dart';
import '../widgets/dashboard/forecasts_section.dart';
import '../widgets/dashboard/observations_section.dart';
import '../widgets/dashboard/opportunities_section.dart';
import '../widgets/common/common.dart';
import 'achievements_screen.dart';

/// Análisis financiero completo. Vive fuera de Inicio a propósito: aquí el
/// usuario entra cuando quiere profundizar, así la pantalla principal se
/// mantiene ligera.
class FinancialInsightsScreen extends StatefulWidget {
  const FinancialInsightsScreen({super.key});

  @override
  State<FinancialInsightsScreen> createState() =>
      _FinancialInsightsScreenState();
}

class _FinancialInsightsScreenState extends State<FinancialInsightsScreen>
    with TickerProviderStateMixin {
  final SmartDashboardService _dashboardService = SmartDashboardService();
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();
  final GoalService _goalService = GoalService();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  SmartDashboardData? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _load();
    _transactionService.addListener(_onDataChanged);
    _accountService.addListener(_onDataChanged);
    _goalService.addListener(_onDataChanged);
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
          ),
        );
  }

  @override
  void dispose() {
    _transactionService.removeListener(_onDataChanged);
    _accountService.removeListener(_onDataChanged);
    _goalService.removeListener(_onDataChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load(forceRefresh: true);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    try {
      final data = await _dashboardService.getDashboardData(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
        _error = null;
      });
      _animationController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No pudimos cargar tu análisis. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardTheme.backgroundLight,
      body: RefreshIndicator(
        color: DashboardTheme.primaryBlue,
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await _load(forceRefresh: true);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      backgroundColor: DashboardTheme.primaryBlue,
      foregroundColor: Colors.white,
      leading: const AppBackButton(light: true),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: const Text(
          'Insight financiero',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [DashboardTheme.primaryBlue, DashboardTheme.darkBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const SizedBox(
        height: 360,
        child: Center(
          child: CircularProgressIndicator(color: DashboardTheme.primaryBlue),
        ),
      );
    }

    if (_error != null) {
      return SizedBox(
        height: 360,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: const TextStyle(color: DashboardTheme.textMedium),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _load(forceRefresh: true),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _data!;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExecutiveSummaryBanner(summary: data.summary),
              const SizedBox(height: 24),
              if (!data.hasSufficientData)
                _emptyState(data.emptyStateMessage)
              else ...[
                if (data.hasAlerts) ...[
                  AlertsSection(alerts: data.alerts),
                  const SizedBox(height: 24),
                ],
                FinancialHealthSection(health: data.health),
                const SizedBox(height: 24),
                if (data.forecasts.isNotEmpty) ...[
                  ForecastsSection(forecasts: data.forecasts),
                  const SizedBox(height: 24),
                ],
                if (data.observations.isNotEmpty) ...[
                  ObservationsSection(observations: data.observations),
                  const SizedBox(height: 24),
                ],
                if (data.opportunities.isNotEmpty) ...[
                  OpportunitiesSection(opportunities: data.opportunities),
                  const SizedBox(height: 24),
                ],
                _achievementsLink(data),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _achievementsLink(SmartDashboardData data) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AchievementsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: DashboardTheme.cardDecoration(
          borderColor: DashboardTheme.warningYellow.withValues(alpha: 0.35),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: DashboardTheme.warningYellow.withValues(alpha: 0.14),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: DashboardTheme.warningYellow,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tus logros',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DashboardTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${data.unlockedAchievementCount} de '
                    '${data.totalAchievementCount} desbloqueados',
                    style: const TextStyle(
                      fontSize: 13,
                      color: DashboardTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: DashboardTheme.textMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String? message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: DashboardTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.insights_outlined,
            size: 48,
            color: DashboardTheme.textMedium,
          ),
          const SizedBox(height: 12),
          Text(
            message ?? 'Datos insuficientes para el análisis',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: DashboardTheme.textMedium,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
