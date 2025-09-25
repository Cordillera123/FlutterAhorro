import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final bool showText;
  final Color? textColor;
  final String? subtitle;
  final bool animated;
  final LogoSize size;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.showText = true,
    this.textColor,
    this.subtitle,
    this.animated = false,
    this.size = LogoSize.medium,
  });

  // Constructor para tamaños predefinidos
  const AppLogo.small({
    super.key,
    this.showText = false,
    this.textColor,
    this.subtitle,
    this.animated = false,
  }) : width = 40,
       height = 40,
       size = LogoSize.small;

  const AppLogo.medium({
    super.key,
    this.showText = true,
    this.textColor,
    this.subtitle,
    this.animated = false,
  }) : width = 80,
       height = 80,
       size = LogoSize.medium;

  const AppLogo.large({
    super.key,
    this.showText = true,
    this.textColor,
    this.subtitle,
    this.animated = true,
  }) : width = 120,
       height = 120,
       size = LogoSize.large;

  const AppLogo.splash({
    super.key,
    this.showText = true,
    this.textColor = Colors.white,
    this.subtitle,
    this.animated = true,
  }) : width = 150,
       height = 150,
       size = LogoSize.splash;

  @override
  Widget build(BuildContext context) {
    final logoWidget = _buildLogo();
    
    if (!showText) {
      return animated ? _buildAnimatedWrapper(logoWidget) : logoWidget;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        animated ? _buildAnimatedWrapper(logoWidget) : logoWidget,
        const SizedBox(height: 12),
        _buildText(),
      ],
    );
  }

  Widget _buildLogo() {
    final logoSize = _getLogoSize();
    
    return Container(
      width: logoSize,
      height: logoSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_getBorderRadius()),
        // Fondo blanco para evitar transparencia
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: _getShadowBlur(),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_getBorderRadius()),
        child: Image.asset(
          _getImagePath(),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackLogo();
          },
        ),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_getBorderRadius()),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF4CAF50),
            Color(0xFF66BB6A),
            Color(0xFF81C784),
          ],
        ),
      ),
      child: Icon(
        Icons.savings_rounded,
        color: Colors.white,
        size: _getIconSize(),
      ),
    );
  }

  Widget _buildAnimatedWrapper(Widget child) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 1200),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        // Asegurar que los valores estén en el rango válido
        final clampedValue = value.clamp(0.0, 1.0);
        final scale = (0.8 + (0.2 * clampedValue)).clamp(0.1, 1.2);
        final opacity = clampedValue.clamp(0.0, 1.0);
        
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildText() {
    return Column(
      children: [
        Text(
          'Mi App de Ahorro',
          style: TextStyle(
            fontSize: _getTitleFontSize(),
            fontWeight: FontWeight.w700,
            color: textColor ?? const Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        if (subtitle != null || _shouldShowDefaultSubtitle()) ...[
          const SizedBox(height: 4),
          Text(
            subtitle ?? 'Controla tus finanzas inteligentemente',
            style: TextStyle(
              fontSize: _getSubtitleFontSize(),
              color: (textColor ?? const Color(0xFF1E293B)).withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // Métodos de utilidad para obtener tamaños y configuraciones
  double _getLogoSize() {
    if (width != null && height != null) {
      return width!;
    }
    
    switch (size) {
      case LogoSize.small:
        return 40;
      case LogoSize.medium:
        return 80;
      case LogoSize.large:
        return 120;
      case LogoSize.splash:
        return 150;
    }
  }

  double _getBorderRadius() {
    final logoSize = _getLogoSize();
    return logoSize * 0.2; // 20% del tamaño del logo
  }

  double _getShadowBlur() {
    return _getLogoSize() * 0.125; // 12.5% del tamaño del logo
  }

  double _getIconSize() {
    return _getLogoSize() * 0.5; // 50% del tamaño del logo para el ícono fallback
  }

  double _getTitleFontSize() {
    switch (size) {
      case LogoSize.small:
        return 12;
      case LogoSize.medium:
        return 16;
      case LogoSize.large:
        return 20;
      case LogoSize.splash:
        return 24;
    }
  }

  double _getSubtitleFontSize() {
    switch (size) {
      case LogoSize.small:
        return 10;
      case LogoSize.medium:
        return 12;
      case LogoSize.large:
        return 14;
      case LogoSize.splash:
        return 16;
    }
  }

  String _getImagePath() {
    switch (size) {
      case LogoSize.small:
        return 'assets/images/logo_small.jpg';
      case LogoSize.medium:
        return 'assets/images/logo_medium.jpg';
      case LogoSize.large:
        return 'assets/images/logo_large.jpg';
      case LogoSize.splash:
        return 'assets/images/logo_splash.jpg';
    }
  }

  bool _shouldShowDefaultSubtitle() {
    return size == LogoSize.medium || size == LogoSize.large || size == LogoSize.splash;
  }
}

enum LogoSize {
  small,
  medium,
  large,
  splash,
}

// Widget especializado para loading states con mejores controles
class AppLogoLoading extends StatefulWidget {
  final double? size;
  final Color? color;

  const AppLogoLoading({
    super.key,
    this.size,
    this.color,
  });

  @override
  State<AppLogoLoading> createState() => _AppLogoLoadingState();
}

class _AppLogoLoadingState extends State<AppLogoLoading>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Crear animación con valores controlados
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Iniciar animaciones de forma segura
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        maxHeight: 300, // Limitar altura máxima
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: widget.size ?? 100,
            height: widget.size ?? 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Círculo animado de fondo con valores controlados
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    final pulseValue = _pulseAnimation.value.clamp(0.0, 1.0);
                    final size = (widget.size ?? 100);
                    final animatedSize = size * (1 + pulseValue * 0.3);
                    final opacity = (0.2 * (1 - pulseValue)).clamp(0.0, 1.0);
                    
                    return Container(
                      width: animatedSize.clamp(size * 0.5, size * 1.5),
                      height: animatedSize.clamp(size * 0.5, size * 1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (widget.color ?? const Color(0xFF4CAF50))
                            .withOpacity(opacity),
                      ),
                    );
                  },
                ),
                // Logo principal sin animación anidada
                AppLogo(
                  width: widget.size ?? 100,
                  height: widget.size ?? 100,
                  showText: false,
                  animated: false, // Evitar animaciones anidadas
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Indicador de progreso personalizado con valores controlados
          SizedBox(
            width: 40,
            height: 4,
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                final progressValue = _rotationController.value.clamp(0.0, 1.0);
                
                return LinearProgressIndicator(
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.color ?? const Color(0xFF4CAF50),
                  ),
                  value: progressValue,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando tu información financiera...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}