import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/security_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_logo.dart';
import '../widgets/common/common.dart';
import '../widgets/pin_pad.dart';

/// Pantalla de bloqueo de la app. No dismisible con el botón atrás —
/// solo se sale de aquí verificando el PIN, con biometría, o restableciendo
/// el bloqueo desde "¿Olvidaste tu PIN?".
///
/// Se usa en dos contextos distintos, ambos controlados por [onUnlocked]:
/// - Al arrancar la app (splash_screen.dart reemplaza esta pantalla por
///   MainNavigationScreen).
/// - Al volver del segundo plano (main_navigation_screen.dart la apila
///   encima y la cierra con `Navigator.pop`).
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;

  const LockScreen({super.key, required this.onUnlocked});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  static const int _pinLength = 4;

  final SecurityService _securityService = SecurityService();

  String _pin = '';
  bool _error = false;
  bool _verifying = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    if (!_securityService.isBiometricEnabled) return;
    final available = await _securityService.isBiometricAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
    if (available) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
    }
  }

  Future<void> _tryBiometric() async {
    final ok = await _securityService.authenticateWithBiometrics();
    if (ok && mounted) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
    }
  }

  void _onDigit(String digit) {
    if (_verifying || _pin.length >= _pinLength) return;
    setState(() {
      _error = false;
      _pin += digit;
    });
    if (_pin.length == _pinLength) {
      _verify();
    }
  }

  void _onBackspace() {
    if (_verifying || _pin.isEmpty) return;
    setState(() {
      _error = false;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _verify() async {
    setState(() => _verifying = true);
    final ok = await _securityService.verifyPin(_pin);

    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      widget.onUnlocked();
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _error = true;
      _verifying = false;
    });
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) setState(() => _pin = '');
  }

  Future<void> _showForgotPinDialog() async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Olvidaste tu PIN?',
      message:
          'Puedes desactivar el bloqueo para volver a entrar. Tus datos '
          '(transacciones, presupuestos, metas) no se verán afectados — '
          'podrás configurar un PIN nuevo desde Configuración.',
      confirmLabel: 'Desactivar bloqueo',
      icon: Icons.lock_open_rounded,
      accentColor: AppColors.warningYellow,
    );
    if (confirmed == true) {
      await _securityService.disableLock();
      if (mounted) widget.onUnlocked();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.emeraldGreen,
                AppColors.primaryGreen,
                AppColors.darkGreen,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                const AppLogo.splash(animated: false),
                const SizedBox(height: 32),
                const Text(
                  'Ingresa tu PIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                PinDots(length: _pinLength, filled: _pin.length, error: _error),
                const SizedBox(height: 12),
                if (_error)
                  const Text(
                    'PIN incorrecto',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  )
                else
                  const SizedBox(height: 18),
                const Spacer(flex: 1),
                NumericKeypad(
                  onDigit: _onDigit,
                  onBackspace: _onBackspace,
                  enabled: !_verifying,
                  onBiometricTap: _biometricAvailable ? _tryBiometric : null,
                ),
                const Spacer(flex: 1),
                TextButton(
                  onPressed: _showForgotPinDialog,
                  child: const Text(
                    '¿Olvidaste tu PIN?',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
