import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../models/calendar/month_calendar_data.dart';
import '../services/calendar_service.dart';
import '../services/transaction_service.dart';
import '../services/account_service.dart';
import '../services/category_service.dart';
import '../widgets/calendar/calendar_theme.dart';
import '../widgets/calendar/calendar_month_summary.dart';
import '../widgets/calendar/calendar_month_navigator.dart';
import '../widgets/calendar/calendar_month_grid.dart';
import '../widgets/calendar/calendar_legend.dart';
import '../widgets/calendar/calendar_day_sheet.dart';
import '../widgets/common/common.dart';
import 'add_transaction_screen.dart';

/// Pantalla "Calendario Financiero".
///
/// Muestra la actividad financiera del usuario (ingresos y gastos reales) en
/// una vista mensual. Toda la lógica de agregación vive en [CalendarService];
/// esta pantalla solo orquesta estado de UI (mes visible, día seleccionado) y
/// escucha a los servicios existentes para refrescarse.
class FinancialCalendarScreen extends StatefulWidget {
  const FinancialCalendarScreen({super.key});

  @override
  State<FinancialCalendarScreen> createState() =>
      _FinancialCalendarScreenState();
}

class _FinancialCalendarScreenState extends State<FinancialCalendarScreen>
    with TickerProviderStateMixin {
  final CalendarService _calendarService = CalendarService();
  final TransactionService _transactionService = TransactionService();
  final AccountService _accountService = AccountService();
  final CategoryService _categoryService = CategoryService();

  late DateTime _visibleMonth;
  DateTime? _selectedDay;
  MonthCalendarData? _monthData;
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<double>(begin: 16.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
      ),
    );

    _transactionService.addListener(_onDataChanged);
    _accountService.addListener(_onDataChanged);
    _categoryService.addListener(_onDataChanged);

    _loadData();
  }

  @override
  void dispose() {
    _transactionService.removeListener(_onDataChanged);
    _accountService.removeListener(_onDataChanged);
    _categoryService.removeListener(_onDataChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    // La cache del CalendarService se invalida sola vía sus listeners.
    setState(() {
      _monthData = _calendarService.getMonthData(_visibleMonth);
    });
  }

  Future<void> _loadData() async {
    await _transactionService.loadTransactions();
    if (!mounted) return;
    setState(() {
      _monthData = _calendarService.getMonthData(_visibleMonth);
      _isLoading = false;
    });
    _animationController.forward();
  }

  void _refreshMonth() {
    setState(() {
      _monthData = _calendarService.getMonthData(_visibleMonth);
    });
  }

  void _goToPreviousMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
      _selectedDay = null;
    });
    _refreshMonth();
  }

  void _goToNextMonth() {
    HapticFeedback.lightImpact();
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
      _selectedDay = null;
    });
    _refreshMonth();
  }

  void _goToToday() {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month, 1);
      _selectedDay = null;
    });
    _refreshMonth();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _visibleMonth.year == now.year && _visibleMonth.month == now.month;
  }

  void _onDaySelected(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() => _selectedDay = day);

    final dayData = _calendarService.getDayData(day);
    CalendarDaySheet.show(
      context,
      data: dayData,
      onMovementTap: _openMovementEditor,
    );
  }

  Future<void> _openMovementEditor(Transaction movement) async {
    Navigator.of(context).pop(); // Cierra el bottom sheet.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          initialType: movement.type,
          transactionToEdit: movement,
        ),
      ),
    );
    // Al volver, los listeners ya habrán refrescado los datos.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalendarTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: const AppBackButton(),
        title: const Text(
          'Calendario Financiero',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: CalendarTheme.textDark,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  CalendarTheme.primaryBlue,
                ),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final monthData = _monthData ?? MonthCalendarData.empty(_visibleMonth);

    return RefreshIndicator(
      color: CalendarTheme.primaryBlue,
      onRefresh: _loadData,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: child,
            ),
          );
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CalendarMonthSummary(monthData: monthData),
              const SizedBox(height: 20),
              CalendarMonthNavigator(
                month: _visibleMonth,
                onPrevious: _goToPreviousMonth,
                onNext: _goToNextMonth,
                onToday: _goToToday,
                isCurrentMonth: _isCurrentMonth,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CalendarTheme.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CalendarMonthGrid(
                  monthData: monthData,
                  selectedDay: _selectedDay,
                  onDaySelected: _onDaySelected,
                ),
              ),
              const SizedBox(height: 16),
              const CalendarLegend(),
            ],
          ),
        ),
      ),
    );
  }
}
