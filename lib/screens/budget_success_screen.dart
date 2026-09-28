import 'package:flutter/material.dart';
import '../models/budget.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import '../widgets/common/common.dart';

class BudgetSuccessScreen extends StatefulWidget {
  final Budget budget;
  final bool isEdit;

  const BudgetSuccessScreen({
    super.key,
    required this.budget,
    this.isEdit = false,
  });

  @override
  State<BudgetSuccessScreen> createState() => _BudgetSuccessScreenState();
}

class _BudgetSuccessScreenState extends State<BudgetSuccessScreen> {
  bool _showSuccess = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSuccessAnimation(
                loadingColor: AppColors.primaryBlue,
                successColor: AppColors.primaryGreen,
                icon: Icons.account_balance_wallet_rounded,
                onShowSuccess: () => setState(() => _showSuccess = true),
                onComplete: () => Navigator.of(context).pop(true),
              ),

              const SizedBox(height: 32),

              // Título
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _showSuccess
                      ? widget.isEdit
                            ? '¡Presupuesto actualizado!'
                            : '¡Presupuesto creado!'
                      : widget.isEdit
                      ? 'Actualizando presupuesto...'
                      : 'Creando presupuesto...',
                  key: ValueKey(_showSuccess),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _showSuccess
                        ? AppColors.primaryGreen
                        : AppColors.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Subtítulo
              if (_showSuccess) ...[
                Text(
                  '${widget.budget.categoryName} - ${widget.budget.periodName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Límite: ${FormatUtils.formatMoney(widget.budget.amount)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.budget.name,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  widget.isEdit
                      ? 'Guardando cambios...'
                      : 'Configurando tu control de gastos...',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textMedium,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
