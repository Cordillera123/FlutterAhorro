import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/security_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';
import 'pin_setup_screen.dart';

/// Pantalla de Configuración > Seguridad: activar/desactivar bloqueo con
/// PIN, biometría (si el dispositivo la soporta) y la opción de ocultar
/// saldos.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final SecurityService _securityService = SecurityService();

  bool _biometricAvailable = false;
  bool _checkingBiometrics = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await _securityService.isBiometricAvailable();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _checkingBiometrics = false;
      });
    }
  }

  Future<void> _onToggleLock(bool enable) async {
    HapticFeedback.selectionClick();
    if (enable) {
      final created = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const PinSetupScreen()),
      );
      if (created == true && mounted) {
        setState(() {});
        _showSnack('Bloqueo con PIN activado');
      }
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Desactivar bloqueo',
      message:
          'Se eliminará el PIN configurado. Cualquier persona con acceso al '
          'dispositivo podrá abrir la app sin restricción. Tus datos no se '
          'ven afectados.',
      confirmLabel: 'Desactivar',
      icon: Icons.lock_open_rounded,
    );
    if (confirmed == true) {
      await _securityService.disableLock();
      if (mounted) setState(() {});
    }
  }

  Future<void> _onChangePin() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
    if (changed == true && mounted) {
      _showSnack('PIN actualizado');
    }
  }

  Future<void> _onToggleBiometric(bool enable) async {
    HapticFeedback.selectionClick();
    await _securityService.setBiometricEnabled(enable);
    if (mounted) setState(() {});
  }

  Future<void> _onToggleHideBalances(bool hide) async {
    HapticFeedback.selectionClick();
    await _securityService.setHideBalances(hide);
    if (mounted) setState(() {});
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockEnabled = _securityService.isLockEnabled;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const AppBackButton(),
        title: const Text(
          'Seguridad',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionHeader('Bloqueo de la app'),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                AppListTile(
                  icon: Icons.lock_outline,
                  iconColor: AppColors.primaryBlue,
                  title: 'Bloqueo con PIN',
                  subtitle: lockEnabled
                      ? 'La app pide tu PIN al abrirla'
                      : 'Protege el acceso a tus datos',
                  onTap: () => _onToggleLock(!lockEnabled),
                  trailing: Switch(
                    value: lockEnabled,
                    onChanged: _onToggleLock,
                    activeThumbColor: AppColors.primaryBlue,
                  ),
                  showDivider: lockEnabled,
                ),
                if (lockEnabled)
                  AppListTile(
                    icon: Icons.password_outlined,
                    iconColor: AppColors.primaryBlue,
                    title: 'Cambiar PIN',
                    subtitle: 'Configura un nuevo PIN de 4 dígitos',
                    onTap: _onChangePin,
                    showDivider: true,
                  ),
                if (lockEnabled)
                  AppListTile(
                    icon: Icons.fingerprint,
                    iconColor: AppColors.primaryBlue,
                    title: 'Usar biometría',
                    subtitle: _checkingBiometrics
                        ? 'Verificando disponibilidad...'
                        : _biometricAvailable
                        ? 'Huella o Face ID como atajo del PIN'
                        : 'No disponible en este dispositivo',
                    onTap: _biometricAvailable
                        ? () => _onToggleBiometric(
                            !_securityService.isBiometricEnabled,
                          )
                        : null,
                    trailing: Switch(
                      value: _securityService.isBiometricEnabled,
                      onChanged: _biometricAvailable
                          ? _onToggleBiometric
                          : null,
                      activeThumbColor: AppColors.primaryBlue,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const SectionHeader('Privacidad'),
          const SizedBox(height: 12),
          AppCard(
            child: AppListTile(
              icon: Icons.visibility_off_outlined,
              iconColor: AppColors.primaryPurple,
              title: 'Ocultar saldos',
              subtitle: 'Oculta el balance principal hasta que lo toques',
              onTap: () =>
                  _onToggleHideBalances(!_securityService.hideBalances),
              trailing: Switch(
                value: _securityService.hideBalances,
                onChanged: _onToggleHideBalances,
                activeThumbColor: AppColors.primaryPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
