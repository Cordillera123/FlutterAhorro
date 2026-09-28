import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/security_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pin_pad.dart';

enum _SetupStep { create, confirm }

/// Flujo de creación (o cambio) de PIN: primero se ingresa, luego se
/// confirma repitiéndolo. Si no coinciden, se reinicia solo el paso de
/// confirmación (no hace falta repetir el primer PIN).
///
/// Al terminar con éxito hace `Navigator.pop(context, true)`.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  static const int _pinLength = 4;

  final SecurityService _securityService = SecurityService();

  _SetupStep _step = _SetupStep.create;
  String _firstPin = '';
  String _currentInput = '';
  bool _error = false;
  bool _saving = false;

  void _onDigit(String digit) {
    if (_saving || _currentInput.length >= _pinLength) return;
    setState(() {
      _error = false;
      _currentInput += digit;
    });
    if (_currentInput.length == _pinLength) {
      _onStepCompleted();
    }
  }

  void _onBackspace() {
    if (_saving || _currentInput.isEmpty) return;
    setState(() {
      _error = false;
      _currentInput = _currentInput.substring(0, _currentInput.length - 1);
    });
  }

  Future<void> _onStepCompleted() async {
    if (_step == _SetupStep.create) {
      final entered = _currentInput;
      setState(() {
        _firstPin = entered;
        _currentInput = '';
        _step = _SetupStep.confirm;
      });
      return;
    }

    // Paso de confirmación
    if (_currentInput != _firstPin) {
      HapticFeedback.heavyImpact();
      setState(() => _error = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => _currentInput = '');
      return;
    }

    setState(() => _saving = true);
    await _securityService.setPin(_firstPin);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context, true);
  }

  void _restart() {
    setState(() {
      _step = _SetupStep.create;
      _firstPin = '';
      _currentInput = '';
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConfirmStep = _step == _SetupStep.confirm;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(
              Icons.lock_outline,
              size: 40,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 20),
            Text(
              isConfirmStep ? 'Confirma tu PIN' : 'Crea un PIN de 4 dígitos',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConfirmStep
                  ? 'Ingresa el mismo PIN una vez más'
                  : 'Lo usarás para desbloquear la app',
              style: const TextStyle(fontSize: 13, color: AppColors.textMedium),
            ),
            const SizedBox(height: 24),
            PinDots(
              length: _pinLength,
              filled: _currentInput.length,
              error: _error,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 12),
            if (_error)
              TextButton(
                onPressed: _restart,
                child: const Text('No coincide. Reintentar desde el inicio'),
              )
            else
              const SizedBox(height: 32),
            const Spacer(flex: 1),
            NumericKeypad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              enabled: !_saving,
              textColor: AppColors.textDark,
              digitBackgroundColor: Colors.white,
              iconColor: AppColors.textMedium,
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
