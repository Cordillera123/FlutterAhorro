import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/transaction.dart';
import '../../models/calendar/day_calendar_data.dart';
import '../../screens/add_transaction_screen.dart';
import '../../services/account_service.dart';
import '../../services/calendar_service.dart';
import '../../services/transaction_service.dart';
import '../../utils/format_utils.dart';
import '../common/amount_text.dart';
import '../transaction_actions_sheet.dart';
import 'calendar_theme.dart';

/// Panel inferior (Bottom Sheet) con el detalle de un día: fecha, resumen
/// (ingresos/gastos/balance) y lista cronológica de movimientos.
///
/// Es un panel de trabajo, no solo de lectura:
/// - **Agregar:** botones "Ingreso" y "Gasto" que abren el formulario ya con
///   esa fecha (solo hasta hoy, igual que el selector de fecha del formulario).
/// - **Editar / Eliminar:** tocar un movimiento abre su detalle con ambas
///   acciones (el mismo menú de Inicio e Historial), sin salir del calendario.
///
/// Se mantiene "vivo": lee el día del [CalendarService] y escucha a los
/// servicios, así que al agregar, editar o eliminar la lista (y los totales)
/// se actualizan solos mientras el panel sigue abierto.
class CalendarDaySheet extends StatefulWidget {
  /// Día a mostrar (la hora se ignora).
  final DateTime date;

  const CalendarDaySheet({super.key, required this.date});

  /// Helper para presentar el sheet con el estilo estándar del proyecto.
  static Future<void> show(BuildContext context, {required DateTime date}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarDaySheet(date: date),
    );
  }

  @override
  State<CalendarDaySheet> createState() => _CalendarDaySheetState();
}

class _CalendarDaySheetState extends State<CalendarDaySheet> {
  // CalendarService se instancia primero para que su listener (que invalida
  // la caché) quede registrado antes que el de este panel.
  final CalendarService _calendarService = CalendarService();
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  @override
  void initState() {
    super.initState();
    _transactionService.addListener(_onDataChanged);
    _accountService.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    _transactionService.removeListener(_onDataChanged);
    _accountService.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  DateTime get _day =>
      DateTime(widget.date.year, widget.date.month, widget.date.day);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _isFuture => _day.isAfter(_today);

  /// Solo se puede registrar entre [AddTransactionScreen.earliestDate] y hoy:
  /// es el rango que acepta el selector de fecha del formulario.
  bool get _canAdd =>
      !_isFuture && !_day.isBefore(AddTransactionScreen.earliestDate);

  Future<void> _addTransaction(TransactionType type) async {
    HapticFeedback.lightImpact();
    // El panel sigue abierto debajo: al volver se actualiza solo.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AddTransactionScreen(initialType: type, initialDate: widget.date),
      ),
    );
  }

  Future<void> _openMovement(Transaction movement) async {
    // Detalle con Editar / Eliminar. Se apila sobre este panel.
    await showTransactionActions(context, movement);
  }

  @override
  Widget build(BuildContext context) {
    final data = _calendarService.getDayData(widget.date);
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
              _buildHeader(data),
              if (data.hasMovements) ...[
                _buildSummary(data),
                if (_canAdd)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: _buildAddActions(),
                  ),
              ],
              Expanded(
                child: data.hasMovements
                    ? _buildMovementsList(data, scrollController)
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

  Widget _buildHeader(DayCalendarData data) {
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
                  FormatUtils.formatDateFull(widget.date),
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

  Widget _buildSummary(DayCalendarData data) {
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

  Widget _buildMovementsList(
    DayCalendarData data,
    ScrollController controller,
  ) {
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      // +1: la primera fila es una pista de uso que se va al desplazar.
      itemCount: data.movements.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 2),
            child: Text(
              'Toca un movimiento para editarlo o eliminarlo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CalendarTheme.textLight,
              ),
            ),
          );
        }
        return _buildMovementTile(context, data.movements[index - 1]);
      },
    );
  }

  Widget _buildMovementTile(BuildContext context, Transaction movement) {
    final Color color;
    final String sign;
    switch (movement.type) {
      case TransactionType.income:
        color = CalendarTheme.incomeGreen;
        sign = '+';
        break;
      case TransactionType.expense:
        color = CalendarTheme.expenseRed;
        sign = '-';
        break;
      case TransactionType.transfer:
        color = CalendarTheme.primaryBlue;
        sign = (movement.isTransferOut ?? true) ? '-' : '+';
        break;
    }
    final accountName = _accountName(movement.accountId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CalendarTheme.borderLight),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openMovement(movement),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                  flex: 3,
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
                Flexible(
                  flex: 2,
                  child: AmountText(
                    '$sign${FormatUtils.formatMoney(movement.amount)}',
                    alignment: Alignment.centerRight,
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
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: CalendarTheme.primaryBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 34,
              color: CalendarTheme.primaryBlue,
            ),
          ),
        ),
        const SizedBox(height: 14),
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
        Text(
          _canAdd
              ? 'Agrega un ingreso o un gasto en esta fecha.'
              : _isFuture
              ? 'Aún no puedes registrar movimientos en una fecha futura.'
              : 'Solo se pueden registrar movimientos desde '
                    '${AddTransactionScreen.earliestDate.year}.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: CalendarTheme.textMedium,
          ),
        ),
        if (_canAdd) ...[const SizedBox(height: 18), _buildAddActions()],
        const SizedBox(height: 24),
      ],
    );
  }

  /// Par de botones "Ingreso" / "Gasto" que abren el formulario con la fecha
  /// de este día. Mismos colores semánticos del calendario (verde / rojo).
  Widget _buildAddActions() {
    return Row(
      children: [
        Expanded(
          child: _AddButton(
            label: 'Ingreso',
            semanticsLabel: 'Agregar ingreso en esta fecha',
            color: CalendarTheme.incomeGreen,
            onTap: () => _addTransaction(TransactionType.income),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AddButton(
            label: 'Gasto',
            semanticsLabel: 'Agregar gasto en esta fecha',
            color: CalendarTheme.expenseRed,
            onTap: () => _addTransaction(TransactionType.expense),
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

/// Botón tonal "+ Ingreso" / "+ Gasto" del panel del día.
class _AddButton extends StatelessWidget {
  final String label;
  final String semanticsLabel;
  final Color color;
  final VoidCallback onTap;

  const _AddButton({
    required this.label,
    required this.semanticsLabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: color, size: 20),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
