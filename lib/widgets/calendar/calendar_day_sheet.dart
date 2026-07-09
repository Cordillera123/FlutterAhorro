import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../models/calendar/day_calendar_data.dart';
import '../../services/account_service.dart';
import '../../utils/format_utils.dart';
import 'calendar_theme.dart';

/// Panel inferior (Bottom Sheet) que muestra el detalle de un día:
/// fecha, resumen (ingresos/gastos/balance) y lista cronológica de movimientos.
/// Si no hay movimientos muestra un estado vacío agradable.
class CalendarDaySheet extends StatelessWidget {
  final DayCalendarData data;

  /// Callback opcional al tocar un movimiento (p. ej. abrir edición).
  final ValueChanged<Transaction>? onMovementTap;

  const CalendarDaySheet({
    super.key,
    required this.data,
    this.onMovementTap,
  });

  /// Helper para presentar el sheet con el estilo estándar del proyecto.
  static Future<void> show(
    BuildContext context, {
    required DayCalendarData data,
    ValueChanged<Transaction>? onMovementTap,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarDaySheet(data: data, onMovementTap: onMovementTap),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: CalendarTheme.backgroundCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(),
              if (data.hasMovements) _buildSummary(),
              Expanded(
                child: data.hasMovements
                    ? _buildMovementsList(scrollController)
                    : _buildEmptyState(scrollController),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: CalendarTheme.borderLight,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: CalendarTheme.primaryBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: CalendarTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FormatUtils.formatDateFull(data.date),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: CalendarTheme.textDark,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.hasMovements
                      ? '${data.movementCount} '
                          '${data.movementCount == 1 ? 'movimiento' : 'movimientos'}'
                      : 'Sin movimientos',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CalendarTheme.textMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final balance = data.balance;
    final balanceColor = balance >= 0
        ? CalendarTheme.incomeGreen
        : CalendarTheme.expenseRed;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CalendarTheme.borderLight),
      ),
      child: Row(
        children: [
          _summaryTile(
            label: 'Ingresos',
            value: FormatUtils.formatMoney(data.totalIncome),
            color: CalendarTheme.incomeGreen,
          ),
          _divider(),
          _summaryTile(
            label: 'Gastos',
            value: FormatUtils.formatMoney(data.totalExpense),
            color: CalendarTheme.expenseRed,
          ),
          _divider(),
          _summaryTile(
            label: 'Balance',
            value: FormatUtils.formatMoney(balance),
            color: balanceColor,
          ),
        ],
      ),
    );
  }

  Widget _summaryTile({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CalendarTheme.textMedium,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 34,
      color: CalendarTheme.borderLight,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildMovementsList(ScrollController controller) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: data.movements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildMovementTile(context, data.movements[index]);
      },
    );
  }

  Widget _buildMovementTile(BuildContext context, Transaction movement) {
    final isIncome = movement.type == TransactionType.income;
    final color =
        isIncome ? CalendarTheme.incomeGreen : CalendarTheme.expenseRed;
    final sign = isIncome ? '+' : '-';
    final accountName = _accountName(movement.accountId);

    return GestureDetector(
      onTap: onMovementTap == null ? null : () => onMovementTap!(movement),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CalendarTheme.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  movement.categoryIcon,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movement.categoryName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CalendarTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (movement.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      movement.description,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: CalendarTheme.textMedium,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 12,
                        color: CalendarTheme.textLight,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          accountName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: CalendarTheme.textLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: CalendarTheme.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(movement.date),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: CalendarTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$sign${FormatUtils.formatMoney(movement.amount)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: CalendarTheme.primaryBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 40,
              color: CalendarTheme.primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Sin movimientos este día',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: CalendarTheme.textDark,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'No registraste ingresos ni gastos en esta fecha.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CalendarTheme.textMedium,
          ),
        ),
      ],
    );
  }

  String _accountName(String accountId) {
    final accounts = AccountService().accounts;
    for (final account in accounts) {
      if (account.id == accountId) return account.name;
    }
    return 'Cuenta';
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
