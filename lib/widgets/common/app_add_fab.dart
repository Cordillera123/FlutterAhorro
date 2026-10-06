import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Botón flotante "Agregar": el mismo en las pestañas principales y en las
/// pantallas que también se abren sueltas (Metas, Gastos automáticos), para
/// que crear algo se vea y se encuentre igual en toda la app.
class AppAddFab extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;

  const AppAddFab({super.key, required this.onPressed, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text(
        'Agregar',
        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}
