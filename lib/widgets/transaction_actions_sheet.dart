import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/transaction.dart';
import '../screens/add_transaction_screen.dart';
import '../services/category_service.dart';
import '../services/goal_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import 'common/common.dart';

enum _TransactionAction { edit, delete }

/// Muestra el detalle de una transacción con las acciones Editar y Eliminar.
///
/// Es el único punto de la app que edita/elimina una transacción desde una
/// lista (Inicio, Historial, Calendario): la edición reutiliza
/// [AddTransactionScreen] y el borrado [TransactionService.deleteTransaction],
/// así que las pantallas que escuchan al servicio se actualizan solas.
///
/// Devuelve `true` si la transacción se editó o eliminó.
Future<bool> showTransactionActions(
  BuildContext context,
  Transaction transaction,
) async {
  HapticFeedback.lightImpact();
  final action = await showModalBottomSheet<_TransactionAction>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _TransactionActionsSheet(transaction: transaction),
  );
  if (action == null || !context.mounted) return false;

  switch (action) {
    case _TransactionAction.edit:
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => AddTransactionScreen(
            initialType: transaction.type,
            transactionToEdit: transaction,
          ),
        ),
      );
      return result == true;

    case _TransactionAction.delete:
      final goalName = GoalService().goalNameForTransaction(transaction.id);
      final confirmed = await showAppConfirmDialog(
        context,
        title: '¿Eliminar transacción?',
        message: transaction.isTransfer
            ? 'Esta acción no se puede deshacer. Se eliminará la '
                  'transferencia completa (en ambas cuentas).'
            : 'Esta acción no se puede deshacer. ¿Estás seguro de eliminar '
                  '"${transaction.description}"?',
        extra: goalName == null
            ? null
            : Text(
                'Es un aporte a la meta "$goalName": también se descontará '
                'de lo ahorrado en esa meta.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMedium,
                  height: 1.4,
                ),
              ),
      );
      if (confirmed != true) return false;

      await TransactionService().deleteTransaction(transaction.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transacción eliminada: ${transaction.description}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
  }
}

class _TransactionActionsSheet extends StatelessWidget {
  final Transaction transaction;

  const _TransactionActionsSheet({required this.transaction});

  Color get _color {
    switch (transaction.type) {
      case TransactionType.income:
        return AppColors.primaryGreen;
      case TransactionType.expense:
        return AppColors.dangerRed;
      case TransactionType.transfer:
        return AppColors.primaryBlue;
    }
  }

  String get _sign {
    switch (transaction.type) {
      case TransactionType.income:
        return '+';
      case TransactionType.expense:
        return '-';
      case TransactionType.transfer:
        return (transaction.isTransferOut ?? true) ? '-' : '+';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;

    // Nombre/emoji vigentes de la categoría (una personalizada pudo renombrarse).
    String categoryName = transaction.categoryName;
    String categoryEmoji = transaction.categoryIcon;
    if (transaction.hasCustomCategory) {
      final info = CategoryService().getCategoryInfo(
        transaction.customCategoryId,
        transaction.expenseCategory,
      );
      categoryName = info['name']!;
      categoryEmoji = info['emoji']!;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      categoryEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  AmountText(
                    '$_sign${FormatUtils.formatMoney(transaction.amount)}',
                    alignment: Alignment.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FormatUtils.formatDateFull(transaction.date),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                if (!transaction.isTransfer) ...[
                  Expanded(
                    child: _ActionButton(
                      title: 'Editar',
                      subtitle: 'Modificar datos',
                      icon: Icons.edit_rounded,
                      color: AppColors.primaryBlue,
                      onTap: () =>
                          Navigator.pop(context, _TransactionAction.edit),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: _ActionButton(
                    title: 'Eliminar',
                    subtitle: 'Borrar transacción',
                    icon: Icons.delete_rounded,
                    color: AppColors.dangerRed,
                    onTap: () =>
                        Navigator.pop(context, _TransactionAction.delete),
                  ),
                ),
              ],
            ),
            if (transaction.isTransfer) ...[
              const SizedBox(height: 12),
              const Text(
                'Las transferencias no se pueden editar. Elimínala y crea una '
                'nueva si necesitas corregirla.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMedium,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
