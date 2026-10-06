import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/financial_goal.dart';
import '../models/transaction.dart';
import '../services/goal_service.dart';
import '../services/transaction_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import 'common/common.dart';
import 'transaction_actions_sheet.dart';

/// Lista de los aportes de una meta, desde la pantalla de Metas, para
/// editarlos o eliminarlos sin ir al historial.
///
/// Cada aporte enlazado se edita a través de su transacción (la misma hoja
/// Editar/Eliminar del historial y el mismo formulario), que es la fuente de
/// verdad: meta, historial, balance y estadísticas quedan siempre iguales.
/// Los aportes antiguos sin transacción se corrigen aquí directamente.
///
/// [onAddContribution] (opcional) muestra el botón "Aportar".
Future<void> showGoalContributionsSheet(
  BuildContext context, {
  required String goalId,
  VoidCallback? onAddContribution,
}) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => GoalContributionsSheet(
      goalId: goalId,
      onAddContribution: onAddContribution,
    ),
  );
}

class GoalContributionsSheet extends StatefulWidget {
  final String goalId;
  final VoidCallback? onAddContribution;

  const GoalContributionsSheet({
    super.key,
    required this.goalId,
    this.onAddContribution,
  });

  @override
  State<GoalContributionsSheet> createState() => _GoalContributionsSheetState();
}

class _GoalContributionsSheetState extends State<GoalContributionsSheet> {
  final GoalService _goalService = GoalService();
  final TransactionService _transactionService = TransactionService();

  @override
  void initState() {
    super.initState();
    // Al editar o eliminar un aporte (aquí o en otra pantalla) la meta se
    // sincroniza y la lista se actualiza sola.
    _goalService.addListener(_onDataChanged);
    _transactionService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _goalService.removeListener(_onDataChanged);
    _transactionService.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  Transaction? _transactionOf(GoalContribution c) {
    final id = c.transactionId;
    if (id == null) return null;
    for (final t in _transactionService.allTransactions) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _openContribution(GoalContribution contribution) async {
    final transaction = _transactionOf(contribution);
    if (transaction != null) {
      await showTransactionActions(context, transaction);
      return;
    }
    await _editUnlinked(contribution);
  }

  /// Aporte antiguo sin movimiento en el historial: se ajusta el monto o se
  /// quita de la meta directamente.
  Future<void> _editUnlinked(GoalContribution contribution) async {
    final controller = TextEditingController(
      text: contribution.amount.abs().toStringAsFixed(2),
    );
    String? error;

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Aporte antiguo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Este aporte no tiene un movimiento en el historial. Puedes '
                'corregir su monto o quitarlo de la meta.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMedium,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [AmountInputFormatter()],
                onChanged: (_) {
                  if (error != null) setDialogState(() => error = null);
                },
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixIcon: Icon(FormatUtils.currencyIcon),
                  errorText: error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'delete'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.dangerRed,
              ),
              child: const Text('Quitar de la meta'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(controller.text);
                if (amount == null || !amount.isFinite || amount <= 0) {
                  setDialogState(() => error = 'Ingresa un monto mayor a 0');
                  return;
                }
                Navigator.pop(dialogContext, 'save');
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    try {
      if (action == 'save') {
        await _goalService.updateUnlinkedContribution(
          contribution,
          double.parse(controller.text),
        );
      } else {
        final confirmed = await showAppConfirmDialog(
          context,
          title: '¿Quitar aporte?',
          message:
              'Se descontará ${FormatUtils.formatMoney(contribution.amount.abs())} '
              'de lo ahorrado en la meta. Esta acción no se puede deshacer.',
          confirmLabel: 'Quitar',
        );
        if (confirmed != true) return;
        await _goalService.deleteUnlinkedContribution(contribution);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el aporte'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = _goalService.getGoalById(widget.goalId);
    final contributions = goal == null
        ? <GoalContribution>[]
        : (_goalService.getGoalContributions(widget.goalId)
            ..sort((a, b) => b.date.compareTo(a.date)));
    final canAdd =
        widget.onAddContribution != null && goal?.status == GoalStatus.active;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
              const SizedBox(height: 20),
              if (goal != null) _buildHeader(goal, contributions.length),
              const SizedBox(height: 16),
              if (contributions.isEmpty)
                _buildEmpty()
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: contributions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildTile(contributions[i]),
                  ),
                ),
              if (canAdd) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onAddContribution!();
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Aportar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FinancialGoal goal, int count) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: goal.priorityColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(goal.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aportes a ${goal.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count == 0
                        ? 'Todavía no hay aportes'
                        : 'Toca un aporte para editarlo o eliminarlo',
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
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: AmountText(
                  'Ahorrado ${FormatUtils.formatMoney(goal.currentAmount)} '
                  'de ${FormatUtils.formatMoney(goal.targetAmount)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(goal.progressPercentage * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: goal.progressColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.savings_outlined, size: 40, color: AppColors.textMedium),
          SizedBox(height: 8),
          Text(
            'Cuando aportes a esta meta, verás cada aporte aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(GoalContribution contribution) {
    final transaction = _transactionOf(contribution);
    final isWithdrawal = contribution.isWithdrawal;
    final color = isWithdrawal ? AppColors.dangerRed : AppColors.primaryGreen;
    // La transacción manda (pudo editarse); si no hay, lo guardado en el
    // aporte.
    final amount = transaction?.amount ?? contribution.amount.abs();
    final date = transaction?.date ?? contribution.date;
    final title =
        transaction?.description ??
        contribution.note ??
        (isWithdrawal ? 'Retiro' : 'Aporte');
    final subtitle = transaction == null
        ? '${FormatUtils.formatDateFull(date)} · Sin movimiento en el historial'
        : FormatUtils.formatDateFull(date);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openContribution(contribution),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isWithdrawal
                      ? Icons.south_west_rounded
                      : Icons.savings_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: AmountText(
                  '${isWithdrawal ? '-' : '+'}${FormatUtils.formatMoney(amount)}',
                  alignment: Alignment.centerRight,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMedium,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
