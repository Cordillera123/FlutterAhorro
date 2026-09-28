import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'manage_categories_screen.dart';
import 'manage_accounts_screen.dart';
import 'export_screen.dart';
import 'backup_screen.dart';
import 'onboarding_screen.dart';
import 'security_screen.dart';
import 'region_settings_screen.dart';
import '../models/export_config.dart';
import '../models/region.dart';
import '../services/region_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = RegionService().current;

    return Scaffold(
      backgroundColor: AppColors.backgroundCard,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildModernAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeInAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionHeader('Personalización'),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        children: [
                          AppListTile(
                            icon: Icons.account_balance_outlined,
                            iconColor: AppColors.primaryGreen,
                            title: 'Mis Cuentas',
                            subtitle: 'Gestiona tus cuentas financieras',
                            onTap: _navigateToAccounts,
                            showDivider: true,
                          ),
                          AppListTile(
                            icon: Icons.category_outlined,
                            iconColor: AppColors.primaryBlue,
                            title: 'Categorías de gastos',
                            subtitle: 'Gestiona tus categorías personalizadas',
                            onTap: _navigateToCategories,
                            showDivider: true,
                          ),
                          AppListTile(
                            icon: Icons.file_download_outlined,
                            iconColor: AppColors.primaryBlue,
                            title: 'Exportar datos',
                            subtitle: 'Genera reportes en Excel',
                            onTap: _navigateToExport,
                            showDivider: true,
                          ),
                          AppListTile(
                            icon: Icons.backup_outlined,
                            iconColor: AppColors.primaryBlue,
                            title: 'Copia de seguridad',
                            subtitle:
                                'Crea o restaura un respaldo de tus datos',
                            onTap: _navigateToBackup,
                            showDivider: true,
                          ),
                          AppListTile(
                            icon: Icons.public_outlined,
                            iconColor: AppColors.primaryBlue,
                            title: 'Región y moneda',
                            subtitle:
                                '${region.flagEmoji} ${region.displayName} · ${region.currencyCode}',
                            onTap: _navigateToRegion,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader('Privacidad y seguridad'),
                    const SizedBox(height: 12),
                    AppCard(
                      child: AppListTile(
                        icon: Icons.lock_outline,
                        iconColor: AppColors.primaryPurple,
                        title: 'Seguridad',
                        subtitle: 'PIN, biometría y saldos ocultos',
                        onTap: _navigateToSecurity,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader('Información'),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        children: [
                          AppListTile(
                            icon: Icons.school_outlined,
                            iconColor: AppColors.primaryGreen,
                            title: 'Ver tutorial',
                            subtitle: 'Repasa cómo usar la app',
                            onTap: _openTutorial,
                            showDivider: true,
                          ),
                          AppListTile(
                            icon: Icons.info_outline,
                            iconColor: AppColors.textMedium,
                            title: 'Acerca de',
                            subtitle: 'Versión 1.0.0',
                            onTap: _showAboutDialog,
                          ),
                        ],
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
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: const AppBackButton(),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Configuración',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, AppColors.backgroundCard],
            ),
          ),
        ),
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _navigateToAccounts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageAccountsScreen()),
    );
  }

  void _navigateToExport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ExportScreen(initialConfig: ExportConfig.currentMonth()),
      ),
    );
  }

  void _navigateToSecurity() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SecurityScreen()),
    );
  }

  void _navigateToBackup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BackupScreen()),
    );
  }

  Future<void> _navigateToRegion() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegionSettingsScreen()),
    );
    // La región pudo haber cambiado — refrescar el subtítulo.
    if (mounted) setState(() {});
  }

  void _navigateToCategories() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageCategoriesScreen()),
    );
  }

  void _openTutorial() {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (routeContext) => OnboardingScreen(
          onFinished: () => Navigator.of(routeContext).pop(),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.savings_outlined,
                color: AppColors.primaryBlue,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Mi App de Ahorro',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versión 1.0.0',
              style: TextStyle(fontSize: 14, color: AppColors.textMedium),
            ),
            SizedBox(height: 12),
            Text(
              'App para control de gastos, presupuestos y metas de ahorro.',
              style: TextStyle(fontSize: 14, color: AppColors.textDark),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
