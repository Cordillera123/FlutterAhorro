import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/backup_service.dart';
import '../theme/app_colors.dart';
import '../widgets/common/common.dart';
import 'main_navigation_screen.dart';

/// Pantalla de copia de seguridad: crear (guardar en el teléfono) y restaurar
/// (seleccionar archivo + validar + reemplazar datos).
///
/// Sigue el mismo patrón visual que [ExportScreen]: SliverAppBar, tarjetas
/// blancas con sombra suave, banner de error y botón principal con estado
/// de carga.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupService _backupService = BackupService();

  bool _isCreating = false;
  bool _isRestoring = false;
  String? _errorMessage;

  // ─── Paleta de colores (igual que en el resto de la app) ──────────────
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color dangerRed = AppColors.dangerRed;
  static const Color darkRed = AppColors.darkRed;
  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color backgroundLight = AppColors.backgroundLight;
  static const Color borderLight = AppColors.borderLight;

  // ─── Acciones ───────────────────────────────────────────────────────────

  Future<void> _createBackup() async {
    if (_isCreating || _isRestoring) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final savedPath = await _backupService.createAndSaveBackup();
      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copia de seguridad guardada en tu teléfono'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'No se pudo generar la copia de seguridad. Verifica el espacio disponible e intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _pickAndValidateBackup() async {
    if (_isCreating || _isRestoring) return;
    HapticFeedback.mediumImpact();

    setState(() => _errorMessage = null);

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      setState(
        () => _errorMessage =
            'No se pudo leer el archivo seleccionado. Intenta de nuevo.',
      );
      return;
    }

    ParsedBackup parsed;
    try {
      final jsonString = utf8.decode(bytes);
      parsed = _backupService.validateAndParse(jsonString);
    } on BackupValidationException catch (e) {
      setState(() => _errorMessage = e.message);
      return;
    } catch (_) {
      setState(
        () => _errorMessage =
            'El archivo seleccionado no es una copia de seguridad válida de AhorroApp.',
      );
      return;
    }

    if (!mounted) return;
    _showRestoreConfirmation(parsed);
  }

  Future<void> _showRestoreConfirmation(ParsedBackup backup) async {
    final exportedLabel =
        '${backup.exportedAt.day.toString().padLeft(2, '0')}/'
        '${backup.exportedAt.month.toString().padLeft(2, '0')}/'
        '${backup.exportedAt.year} '
        '${backup.exportedAt.hour.toString().padLeft(2, '0')}:'
        '${backup.exportedAt.minute.toString().padLeft(2, '0')}';

    final confirmed = await showAppConfirmDialog(
      context,
      title: '¿Restaurar copia de seguridad?',
      message:
          'Copia del $exportedLabel · ${backup.accounts.length} '
          'cuenta(s) · ${backup.transactions.length} transacción(es)',
      icon: Icons.warning_amber_rounded,
      confirmLabel: 'Restaurar',
      extra: const Text(
        'Esto reemplazará TODOS los datos actuales de la app (cuentas, '
        'transacciones, presupuestos, metas, categorías y gastos '
        'recurrentes). Esta acción no se puede deshacer.',
        style: TextStyle(fontSize: 13, color: textMedium, height: 1.4),
        textAlign: TextAlign.center,
      ),
    );
    if (confirmed == true) {
      _restoreBackup(backup);
    }
  }

  Future<void> _restoreBackup(ParsedBackup backup) async {
    setState(() {
      _isRestoring = true;
      _errorMessage = null;
    });

    try {
      await _backupService.restoreParsedBackup(backup);
      if (!mounted) return;

      // Todas las pantallas deben remontar con los datos restaurados.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Ocurrió un error restaurando los datos. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildErrorBanner(),
                  _buildSectionLabel('Crear copia de seguridad'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.backup_outlined,
                    iconColor: primaryBlue,
                    text:
                        'Genera un archivo con todas tus cuentas, '
                        'transacciones, presupuestos, metas, categorías y '
                        'gastos recurrentes, y lo guarda en tu teléfono '
                        '(por ejemplo, en Descargas).',
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    label: 'Descargar copia de seguridad',
                    icon: Icons.backup_outlined,
                    isLoading: _isCreating,
                    loadingLabel: 'Generando...',
                    gradientColors: const [primaryBlue, darkBlue],
                    onTap: _createBackup,
                  ),
                  const SizedBox(height: 32),
                  _buildSectionLabel('Restaurar copia de seguridad'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.restore_outlined,
                    iconColor: dangerRed,
                    text:
                        'Selecciona un archivo de copia de seguridad '
                        'generado por AhorroApp. Antes de restaurar se '
                        'valida que el archivo sea correcto — si algo no '
                        'coincide, tus datos actuales no se tocan.',
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    label: 'Seleccionar archivo y restaurar',
                    icon: Icons.file_open_outlined,
                    isLoading: _isRestoring,
                    loadingLabel: 'Restaurando...',
                    gradientColors: const [dangerRed, darkRed],
                    onTap: _pickAndValidateBackup,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
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
          'Copia de seguridad',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
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

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textMedium,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                color: textMedium,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _errorMessage != null
          ? Container(
              key: const ValueKey('error_banner'),
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: dangerRed.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dangerRed.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: dangerRed, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: dangerRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _errorMessage = null),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close, size: 18, color: dangerRed),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('no_error')),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required String loadingLabel,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    final disabled = _isCreating || _isRestoring;
    return AppPrimaryButton(
      label: isLoading ? loadingLabel : label,
      icon: icon,
      loading: isLoading,
      gradientColors: gradientColors,
      onPressed: disabled ? null : onTap,
    );
  }
}
