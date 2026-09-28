import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import '../widgets/common/common.dart';

class TransactionSuccessScreen extends StatefulWidget {
  final Transaction transaction;
  final bool isEdit;

  const TransactionSuccessScreen({
    super.key,
    required this.transaction,
    this.isEdit = false,
  });

  @override
  State<TransactionSuccessScreen> createState() =>
      _TransactionSuccessScreenState();
}

class _TransactionSuccessScreenState extends State<TransactionSuccessScreen> {
  bool _showSuccess = false;

  @override
  Widget build(BuildContext context) {
    final isIncome = widget.transaction.type == TransactionType.income;
    final isTransfer = widget.transaction.type == TransactionType.transfer;
    final primaryColor = isTransfer
        ? AppColors.primaryBlue
        : (isIncome ? AppColors.primaryGreen : AppColors.dangerRed);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppSuccessAnimation(
                loadingColor: primaryColor,
                successColor: primaryColor,
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
                      ? (widget.isEdit
                            ? '¡Transacción actualizada!'
                            : '¡Transacción guardada!')
                      : (widget.isEdit
                            ? 'Actualizando transacción...'
                            : 'Guardando transacción...'),
                  key: ValueKey(_showSuccess),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _showSuccess ? primaryColor : AppColors.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // Subtítulo
              if (_showSuccess) ...[
                Text(
                  '${isTransfer ? 'Transferencia' : (isIncome ? 'Ingreso' : 'Gasto')} de ${FormatUtils.formatMoney(widget.transaction.amount)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.transaction.description,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textMedium,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                const Text(
                  'Actualizando tu balance...',
                  style: TextStyle(fontSize: 16, color: AppColors.textMedium),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
