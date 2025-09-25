import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_logo.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _navigateToHome();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _logoAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    // Iniciar animaciones de forma segura
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.forward();
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _logoController.forward();
          }
        });
      }
    });
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    
    if (mounted) {
      // Agregar haptic feedback
      HapticFeedback.lightImpact();
      
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const MainNavigationScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF4CAF50),
              Color(0xFF66BB6A),
              Color(0xFF81C784),
            ],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: Listenable.merge([_fadeAnimation, _logoAnimation]),
            builder: (context, child) {
              final fadeValue = _fadeAnimation.value.clamp(0.0, 1.0);
              final scaleValue = _logoAnimation.value.clamp(0.5, 1.2);
              
              return Opacity(
                opacity: fadeValue,
                child: Center(
                  child: Transform.scale(
                    scale: scaleValue,
                    child: const AppLogo.splash(
                      animated: false, // Controlamos la animación externamente
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}