import '../models/transaction.dart';
import '../models/calendar/day_calendar_data.dart';
import '../models/calendar/month_calendar_data.dart';
import 'transaction_service.dart';
import 'account_service.dart';

/// Servicio que construye los datos del Calendario Financiero reutilizando
/// las transacciones ya cargadas por [TransactionService].
///
/// Principios de diseño:
/// - NO persiste nada: solo agrega/transforma datos existentes.
/// - Agrupa los movimientos por día en UN SOLO recorrido O(n) por mes.
/// - Cachea el resultado por (cuenta activa, año, mes) para no recalcular al
///   redibujar celdas ni al navegar entre meses ya visitados.
/// - Invalida la cache automáticamente cuando cambian las transacciones o la
///   cuenta activa (escucha a los servicios existentes).
///
/// Patrón Singleton, igual que el resto de servicios del proyecto.
class CalendarService {
  static final CalendarService _instance = CalendarService._internal();
  factory CalendarService() => _instance;

  CalendarService._internal() {
    // La cache deja de ser válida si cambian los datos o la cuenta activa.
    _transactionService.addListener(_invalidateCache);
    _accountService.addListener(_invalidateCache);
  }

  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();

  /// Cache en memoria. Clave: "${accountId}_${year}_${month}".
  final Map<String, MonthCalendarData> _cache = {};

  void _invalidateCache() => _cache.clear();

  String _cacheKey(DateTime month) =>
      '${_accountService.activeAccountId}_${month.year}_${month.month}';

  /// Obtiene (o construye y cachea) los datos del mes indicado.
  ///
  /// [month] puede ser cualquier fecha dentro del mes; se normaliza al día 1.
  MonthCalendarData getMonthData(DateTime month) {
    final normalized = DateTime(month.year, month.month, 1);
    final key = _cacheKey(normalized);

    final cached = _cache[key];
    if (cached != null) return cached;

    final data = _buildMonthData(normalized);
    _cache[key] = data;
    return data;
  }

  /// Obtiene los datos de un día concreto reutilizando la cache mensual.
  DayCalendarData getDayData(DateTime day) {
    final monthData = getMonthData(DateTime(day.year, day.month, 1));
    return monthData.dayData(day.day);
  }

  /// Limpia manualmente la cache (por si se requiere forzar recálculo).
  void clearCache() => _invalidateCache();

  // --- Construcción interna -------------------------------------------------

  MonthCalendarData _buildMonthData(DateTime month) {
    // `transactions` ya viene filtrado por la cuenta activa desde el service.
    final monthTransactions = _transactionService.transactions.where((t) =>
        t.date.year == month.year && t.date.month == month.month);

    // Un solo pase: agrupamos por día y acumulamos totales a la vez.
    final Map<int, List<Transaction>> movementsByDay = {};
    double monthIncome = 0;
    double monthExpense = 0;
    int monthCount = 0;

    for (final t in monthTransactions) {
      (movementsByDay[t.date.day] ??= []).add(t);
      if (t.type == TransactionType.income) {
        monthIncome += t.amount;
      } else {
        monthExpense += t.amount;
      }
      monthCount++;
    }

    final Map<int, DayCalendarData> daysByNumber = {};
    movementsByDay.forEach((day, movements) {
      // Orden cronológico ascendente dentro del día.
      movements.sort((a, b) => a.date.compareTo(b.date));

      double dayIncome = 0;
      double dayExpense = 0;
      for (final m in movements) {
        if (m.type == TransactionType.income) {
          dayIncome += m.amount;
        } else {
          dayExpense += m.amount;
        }
      }

      daysByNumber[day] = DayCalendarData(
        date: DateTime(month.year, month.month, day),
        movements: movements,
        totalIncome: dayIncome,
        totalExpense: dayExpense,
      );
    });

    return MonthCalendarData(
      month: month,
      daysByNumber: daysByNumber,
      totalIncome: monthIncome,
      totalExpense: monthExpense,
      movementCount: monthCount,
    );
  }
}
