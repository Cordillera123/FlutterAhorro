import 'dart:async';

import 'package:flutter/material.dart';

import '../models/budget.dart';
import '../services/budget_service.dart';
import '../theme/app_colors.dart';

/// Muestra los avisos de presupuesto ("ya usaste el 85 %", "presupuesto
/// excedido") en el momento en que un gasto cruza el porcentaje de alerta o
/// el límite, desde cualquier pantalla: el formulario, el historial, el
/// calendario, un aporte a una meta o un gasto automático.
///
/// Se ubica en la navegación principal. Usa el ScaffoldMessenger de la app,
/// así que el aviso sigue visible aunque se cierre la pantalla en la que se
/// guardó el gasto (el formulario y su animación de éxito).
class BudgetAlertListener extends StatefulWidget {
  final Widget child;

  const BudgetAlertListener({super.key, required this.child});

  @override
  State<BudgetAlertListener> createState() => _BudgetAlertListenerState();
}

class _BudgetAlertListenerState extends State<BudgetAlertListener> {
  StreamSubscription<BudgetAlert>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = BudgetService().alerts.listen(_show);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _show(BudgetAlert alert) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final color = alert.isExceeded
        ? AppColors.dangerRed
        : AppColors.warningYellow;

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textDark,
        duration: const Duration(seconds: 8),
        showCloseIcon: true,
        closeIconColor: Colors.white70,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                alert.isExceeded
                    ? Icons.error_outline_rounded
                    : Icons.notifications_active_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    alert.title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alert.message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
