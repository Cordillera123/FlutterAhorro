import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/dashboard/dashboard_achievement.dart';
import '../models/dashboard/dashboard_enums.dart';
import '../models/dashboard/smart_dashboard_data.dart';
import '../services/account_service.dart';
import '../services/dashboard/smart_dashboard_service.dart';
import '../services/goal_service.dart';
import '../services/transaction_service.dart';
import '../widgets/dashboard/achievement_card.dart';
import '../widgets/dashboard/dashboard_theme.dart';
import '../theme/app_colors.dart';

/// Sala de trofeos. Muestra lo conseguido y, sobre todo, lo que está a punto
/// de conseguirse: ver el progreso es lo que empuja a seguir.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  static const Color _gold = AppColors.warningYellow;
  static const Color _goldDark = AppColors.darkYellow;

  final SmartDashboardService _dashboardService = SmartDashboardService();
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();
  final GoalService _goalService = GoalService();

  SmartDashboardData? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _transactionService.addListener(_onDataChanged);
    _accountService.addListener(_onDataChanged);
    _goalService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _transactionService.removeListener(_onDataChanged);
    _accountService.removeListener(_onDataChanged);
    _goalService.removeListener(_onDataChanged);
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No pudimos cargar tus logros. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashboardTheme.backgroundLight,
      body: RefreshIndicator(
        color: _gold,
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
      backgroundColor: _gold,
      foregroundColor: Colors.white,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: const Text(
          'Tus logros',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_gold, _goldDark],
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
        child: Center(child: CircularProgressIndicator(color: _gold)),
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

    final data = _data;
    if (data == null || data.allAchievements.isEmpty) {
      return _emptyState();
    }

    final grouped = <AchievementGroup, List<DashboardAchievement>>{};
    for (final achievement in data.allAchievements) {
      grouped.putIfAbsent(achievement.group, () => []).add(achievement);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryCard(data),
          const SizedBox(height: 24),
          for (final group in AchievementGroup.values)
            if (grouped[group] != null && grouped[group]!.isNotEmpty) ...[
              _groupHeader(group, grouped[group]!),
              const SizedBox(height: 12),
              ...grouped[group]!.map(
                (achievement) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AchievementCard(achievement: achievement),
                ),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _summaryCard(SmartDashboardData data) {
    final unlocked = data.unlockedAchievementCount;
    final total = data.totalAchievementCount;
    final ratio = total > 0 ? unlocked / total : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gold, _goldDark],
        ),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.28),
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$unlocked de $total logros',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _motivation(unlocked, total),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _motivation(int unlocked, int total) {
    if (unlocked == 0) {
      return 'Registra tu primer movimiento y empieza a desbloquear';
    }
    if (unlocked >= total) return '¡Los conseguiste todos! Eres una leyenda';
    if (unlocked >= total * 0.75) return 'Ya casi los tienes todos';
    if (unlocked >= total * 0.4) return 'Vas por muy buen camino';
    return 'Buen comienzo, sigue así';
  }

  Widget _groupHeader(
    AchievementGroup group,
    List<DashboardAchievement> items,
  ) {
    final unlocked = items.where((a) => a.unlocked).length;
    return Row(
      children: [
        Text(group.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          group.label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: DashboardTheme.textDark,
            letterSpacing: -0.3,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$unlocked/${items.length}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _goldDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.emoji_events_outlined,
            size: 56,
            color: _gold.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tus trofeos aparecerán aquí',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: DashboardTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Registra tus movimientos y empezarás a desbloquear logros '
            'automáticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: DashboardTheme.textMedium,
            ),
          ),
        ],
      ),
    );
  }
}
