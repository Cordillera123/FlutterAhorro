import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/onboarding_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';

/// Tutorial de bienvenida: carrusel que explica lo principal de la app.
///
/// Se muestra solo en la primera apertura (ver [OnboardingService]) y se
/// puede repetir desde Configuración. Omitirlo o terminarlo lo marca como
/// visto y llama a [onFinished]; quien lo abre decide a dónde ir después,
/// igual que `LockScreen.onUnlocked`.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingSlide {
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String description;
  final IconData hintIcon;

  /// Texto de "dónde encontrarlo"; los tramos marcados con `true` van en
  /// negrita.
  final List<(String, bool)> hint;

  const _OnboardingSlide({
    required this.icon,
    required this.colors,
    required this.title,
    required this.description,
    required this.hintIcon,
    required this.hint,
  });
}

const List<_OnboardingSlide> _slides = [
  _OnboardingSlide(
    icon: Icons.savings_rounded,
    colors: [AppColors.primaryGreen, AppColors.darkGreen],
    title: '¡Te damos la bienvenida!',
    description:
        'Controla tus ingresos, gastos y ahorros en un solo lugar. '
        'Funciona sin internet y no se conecta a ningún banco.',
    hintIcon: Icons.shield_outlined,
    hint: [('Tus datos ', false), ('se quedan en tu teléfono', true)],
  ),
  _OnboardingSlide(
    icon: Icons.receipt_long_rounded,
    colors: [AppColors.primaryBlue, AppColors.darkBlue],
    title: 'Registra ingresos y gastos',
    description:
        'Cada vez que recibas o gastes dinero, anótalo en segundos '
        'eligiendo Ingreso o Gasto. Tu balance se actualiza al instante.',
    hintIcon: Icons.add_circle_outline_rounded,
    hint: [('Botón ', false), ('Agregar', true), (' en Inicio', false)],
  ),
  _OnboardingSlide(
    icon: Icons.account_balance_rounded,
    colors: [AppColors.cyanAccent, AppColors.deepBlue],
    title: 'Organiza tus cuentas',
    description:
        'Separa tu dinero en varias cuentas, como Principal o Ahorros. '
        'Cambia de cuenta cuando quieras y mueve dinero entre ellas con '
        'Transferir.',
    hintIcon: Icons.touch_app_outlined,
    hint: [
      ('Toca el ', false),
      ('nombre de la cuenta', true),
      (' en Inicio', false),
    ],
  ),
  _OnboardingSlide(
    icon: Icons.account_balance_wallet_rounded,
    colors: [AppColors.indigoAccent, AppColors.deepPurple],
    title: 'Controla con presupuestos',
    description:
        'Pon un límite de gasto por categoría: semanal, mensual o anual. '
        'La app te avisa cuando te acercas al límite o lo pasas.',
    hintIcon: Icons.account_balance_wallet_outlined,
    hint: [('Pestaña ', false), ('Presupuestos', true)],
  ),
  _OnboardingSlide(
    icon: Icons.flag_rounded,
    colors: [AppColors.darkYellow, AppColors.deepYellow],
    title: 'Cumple tus metas',
    description:
        'Define cuánto quieres ahorrar y para cuándo. La app calcula cuánto '
        'apartar cada semana o cada mes, y ahí registras tus aportes.',
    hintIcon: Icons.flag_outlined,
    hint: [('Pestaña ', false), ('Metas', true)],
  ),
  _OnboardingSlide(
    icon: Icons.autorenew_rounded,
    colors: [AppColors.primaryPurple, AppColors.darkPurple],
    title: 'Gastos automáticos',
    description:
        'Registra una sola vez tus pagos fijos, como arriendo, internet o '
        'transporte, y se anotarán solos el día que toca.',
    hintIcon: Icons.autorenew_outlined,
    hint: [('Pestaña ', false), ('Automático', true)],
  ),
  _OnboardingSlide(
    icon: Icons.history_rounded,
    colors: [AppColors.darkGreen, AppColors.deepGreen],
    title: 'Historial y mucho más',
    description:
        'Busca y filtra tus movimientos, descarga reportes en Excel, guarda '
        'copias de seguridad y protege la app con un PIN.',
    hintIcon: Icons.menu_rounded,
    hint: [
      ('Pestaña ', false),
      ('Historial', true),
      (' y menú ', false),
      ('Configuración', true),
    ],
  ),
];

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;
  bool _finishing = false;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    HapticFeedback.lightImpact();
    await OnboardingService().markCompleted();
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];

    // El botón atrás del sistema retrocede una pantalla; solo en la primera
    // se comporta normal (cerrar/volver).
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _previous();
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                slide.colors.first.withValues(alpha: 0.12),
                AppColors.backgroundLight,
              ],
              stops: const [0.0, 0.55],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    _buildTopBar(),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _slides.length,
                        onPageChanged: (index) => setState(() => _page = index),
                        itemBuilder: (context, index) => _buildSlide(
                          _slides[index],
                          isActive: index == _page,
                        ),
                      ),
                    ),
                    _buildDots(),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AppPrimaryButton(
                        label: _isLast ? 'Comenzar' : 'Siguiente',
                        icon: _isLast
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        gradientColors: slide.colors,
                        onPressed: _next,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                '${_page + 1} de ${_slides.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMedium,
                ),
              ),
            ),
            const Spacer(),
            if (!_isLast)
              TextButton(
                onPressed: _finish,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMedium,
                ),
                child: const Text(
                  'Omitir',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlide slide, {required bool isActive}) {
    // Scroll solo como red de seguridad en pantallas bajas; en teléfonos
    // normales el contenido cabe y queda centrado.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: isActive ? 1.0 : 0.85,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutBack,
                child: _buildIllustration(slide),
              ),
              const SizedBox(height: 40),
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                slide.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textMedium,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              _buildHint(slide),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration(_OnboardingSlide slide) {
    return Container(
      width: 180,
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: slide.colors.first.withValues(alpha: 0.10),
      ),
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: LinearGradient(
            colors: slide.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: slide.colors.first.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(slide.icon, size: 60, color: Colors.white),
      ),
    );
  }

  Widget _buildHint(_OnboardingSlide slide) {
    final color = slide.colors.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: AppCard.standardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(slide.hintIcon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  for (final (text, bold) in slide.hint)
                    TextSpan(
                      text: text,
                      style: TextStyle(
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                        color: bold ? AppColors.textDark : AppColors.textMedium,
                      ),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    final activeColor = _slides[_page].colors.first;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _slides.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == _page ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == _page ? activeColor : AppColors.emptyGray,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
