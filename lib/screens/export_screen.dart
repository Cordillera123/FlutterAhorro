import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/export_config.dart';
import '../services/account_service.dart';
import '../services/export_service.dart';
import '../theme/app_colors.dart';

// Metadatos de cada formato disponible para la UI.
const _formatOptions = [
  (ExportFormat.excel, Icons.table_chart_outlined, 'Excel', '.xlsx', 'Estilos y múltiples hojas'),
  (ExportFormat.csv,   Icons.code_outlined,        'CSV',   '.csv',  'Texto plano universal'),
];

/// Pantalla de configuración y ejecución de exportación de reportes.
///
/// Permite seleccionar período, cuenta y tipo de reporte antes de generar
/// el archivo Excel. La generación corre en un isolate (via [ExcelService])
/// por lo que la UI refleja el estado de espera real, no cosmético.
class ExportScreen extends StatefulWidget {
  /// Configuración inicial opcional. Si se omite, se usa el mes actual.
  final ExportConfig? initialConfig;

  const ExportScreen({super.key, this.initialConfig});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

// Atajos de rango de fechas visibles en la UI.
enum _DatePreset { thisMonth, thisYear, allTime, custom }

class _ExportScreenState extends State<ExportScreen>
    with TickerProviderStateMixin {
  final ExportService _exportService = ExportService();
  final AccountService _accountService = AccountService();

  late ExportFilters _filters;
  ReportType _reportType = ReportType.fullReport;
  ExportFormat _format = ExportFormat.excel;

  /// `true` = exportar todas las cuentas; `false` = solo la cuenta activa.
  bool _allAccounts = false;
  _DatePreset _activePreset = _DatePreset.thisMonth;

  bool _isExporting = false;
  String? _errorMessage;
  int _estimatedCount = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ─── Paleta de colores (igual que en el resto de la app) ──────────────
  static const Color primaryBlue = AppColors.primaryBlue;
  static const Color darkBlue = AppColors.darkBlue;
  static const Color warningYellow = AppColors.warningYellow;
  static const Color dangerRed = AppColors.dangerRed;
  static const Color textDark = AppColors.textDark;
  static const Color textMedium = AppColors.textMedium;
  static const Color backgroundLight = AppColors.backgroundLight;
  static const Color borderLight = AppColors.borderLight;

  static const int _rowLimit = 50000;
  static const int _warnThreshold = 45000;

  // ─── Ciclo de vida ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initAnimations();

    if (widget.initialConfig != null) {
      _filters = widget.initialConfig!.filters;
      _reportType = widget.initialConfig!.reportType;
      _format = widget.initialConfig!.format;
      _allAccounts = !_filters.hasAccountFilter;
      _activePreset = _detectPreset(_filters);
    } else {
      _filters = ExportFilters.currentMonth();
      _allAccounts = false;
      _activePreset = _DatePreset.thisMonth;
    }

    _updateEstimate();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  // ─── Helpers de estado ────────────────────────────────────────────────

  _DatePreset _detectPreset(ExportFilters f) {
    final now = DateTime.now();
    if (_isSameDay(f.dateFrom, DateTime(now.year, now.month, 1)) &&
        _isSameDay(f.dateTo, DateTime(now.year, now.month + 1, 0))) {
      return _DatePreset.thisMonth;
    }
    if (_isSameDay(f.dateFrom, DateTime(now.year, 1, 1)) &&
        _isSameDay(f.dateTo, DateTime(now.year, 12, 31))) {
      return _DatePreset.thisYear;
    }
    if (f.dateFrom.year <= 2000) return _DatePreset.allTime;
    return _DatePreset.custom;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _updateEstimate() {
    final count = _exportService.estimateTransactionCount(_buildConfig());
    if (mounted) setState(() => _estimatedCount = count);
  }

  ExportConfig _buildConfig() {
    final accountIds = _allAccounts
        ? <String>[]
        : [_accountService.activeAccountId];
    return ExportConfig(
      filters: _filters.copyWith(accountIds: accountIds),
      reportType: _reportType,
      format: _format,
    );
  }

  // ─── Acciones del usuario ─────────────────────────────────────────────

  void _applyPreset(_DatePreset preset) {
    setState(() {
      _activePreset = preset;
      _errorMessage = null;
    });

    ExportFilters updated;
    switch (preset) {
      case _DatePreset.thisMonth:
        final base = ExportFilters.currentMonth();
        updated = _filters.copyWith(dateFrom: base.dateFrom, dateTo: base.dateTo);
        break;
      case _DatePreset.thisYear:
        final base = ExportFilters.currentYear();
        updated = _filters.copyWith(dateFrom: base.dateFrom, dateTo: base.dateTo);
        break;
      case _DatePreset.allTime:
        final base = ExportFilters.allTime();
        updated = _filters.copyWith(dateFrom: base.dateFrom, dateTo: base.dateTo);
        break;
      case _DatePreset.custom:
        return;
    }

    setState(() => _filters = updated);
    _updateEstimate();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? _filters.dateFrom : _filters.dateTo;
    final first = DateTime(2000);
    final last = isFrom
        ? _filters.dateTo
        : DateTime.now().add(const Duration(days: 365 * 5));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textDark,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      _activePreset = _DatePreset.custom;
      _errorMessage = null;
      if (isFrom) {
        _filters = _filters.copyWith(
          dateFrom: picked,
          // Mantener dateTo >= dateFrom
          dateTo: _filters.dateTo.isBefore(picked) ? picked : null,
        );
      } else {
        _filters = _filters.copyWith(dateTo: picked);
      }
    });
    _updateEstimate();
  }

  Future<void> _export() async {
    if (_isExporting) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      await _exportService.generateAndShare(_buildConfig());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte generado correctamente'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ExportEmptyDataException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage =
            'No se pudo generar el reporte. Verifica el espacio disponible e intenta de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    _buildSectionLabel('Período'),
                    const SizedBox(height: 12),
                    _buildDatePresetChips(),
                    const SizedBox(height: 12),
                    _buildDateRangeRow(),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Cuenta'),
                    const SizedBox(height: 12),
                    _buildAccountSelector(),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Formato'),
                    const SizedBox(height: 12),
                    _buildFormatSelector(),
                    const SizedBox(height: 28),
                    _buildSectionLabel('Tipo de reporte'),
                    const SizedBox(height: 12),
                    _buildReportTypeGrid(),
                    const SizedBox(height: 20),
                    _buildLimitWarning(),
                    _buildErrorBanner(),
                    _buildExportButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: textDark,
          ),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'Exportar reporte',
          style: TextStyle(
            color: textDark,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8FAFC)],
            ),
          ),
        ),
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // ─── Helpers de layout ─────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textMedium,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ─── Sección: Período ─────────────────────────────────────────────────

  Widget _buildDatePresetChips() {
    const presets = [
      (_DatePreset.thisMonth, 'Este mes'),
      (_DatePreset.thisYear, 'Este año'),
      (_DatePreset.allTime, 'Todo'),
    ];

    return Row(
      children: presets.map((entry) {
        final isActive = _activePreset == entry.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _applyPreset(entry.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isActive ? primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? primaryBlue : borderLight,
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: primaryBlue.withOpacity(0.22),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : [],
              ),
              child: Text(
                entry.$2,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : textMedium,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateRangeRow() {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(child: _buildDateButton(isFrom: true)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.arrow_forward, size: 18, color: textMedium),
            ),
            Expanded(child: _buildDateButton(isFrom: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateButton({required bool isFrom}) {
    final date = isFrom ? _filters.dateFrom : _filters.dateTo;
    final label = isFrom ? 'Desde' : 'Hasta';
    final formatted =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    return GestureDetector(
      onTap: () => _pickDate(isFrom: isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: textMedium,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: primaryBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sección: Cuenta ──────────────────────────────────────────────────

  Widget _buildAccountSelector() {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            _buildAccountOption(
              isAll: false,
              label: 'Cuenta activa',
              icon: Icons.person_outline,
            ),
            _buildAccountOption(
              isAll: true,
              label: 'Todas las cuentas',
              icon: Icons.account_balance_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountOption({
    required bool isAll,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _allAccounts == isAll;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _allAccounts = isAll;
            _errorMessage = null;
          });
          _updateEstimate();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.white : textMedium,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : textMedium,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Sección: Formato ─────────────────────────────────────────────────

  Widget _buildFormatSelector() {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: _formatOptions.map((opt) {
            final isSelected = _format == opt.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _format = opt.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        opt.$2,
                        size: 22,
                        color: isSelected ? Colors.white : primaryBlue,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            opt.$3,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : textDark,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.25)
                                  : backgroundLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              opt.$4,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : textMedium,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        opt.$5,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? Colors.white70 : textMedium,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─── Sección: Tipo de reporte ─────────────────────────────────────────

  Widget _buildReportTypeGrid() {
    final options = [
      (
        ReportType.fullReport,
        Icons.dashboard_outlined,
        'Completo',
        'Todas las hojas',
      ),
      (
        ReportType.transactions,
        Icons.receipt_long_outlined,
        'Transacciones',
        'Movimientos',
      ),
      (
        ReportType.budgets,
        Icons.pie_chart_outline,
        'Presupuestos',
        'Límites de gasto',
      ),
      (
        ReportType.goals,
        Icons.flag_outlined,
        'Metas',
        'Objetivos de ahorro',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: options.map((opt) {
        final isSelected = _reportType == opt.$1;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _reportType = opt.$1);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? primaryBlue : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? primaryBlue : borderLight,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? primaryBlue.withOpacity(0.22)
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    opt.$2,
                    size: 20,
                    color: isSelected ? Colors.white : primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          opt.$3,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : textDark,
                          ),
                        ),
                        Text(
                          opt.$4,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? Colors.white70
                                : textMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Banners ──────────────────────────────────────────────────────────

  Widget _buildLimitWarning() {
    final show = _estimatedCount > _warnThreshold;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: show
          ? Container(
              key: const ValueKey('limit_warning'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: warningYellow.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: warningYellow.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: warningYellow,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: textDark),
                        children: [
                          const TextSpan(
                            text: 'El período contiene muchas transacciones. ',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: 'El reporte incluirá las primeras '
                                '$_rowLimit '
                                '(~$_estimatedCount en el rango).',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('no_limit')),
    );
  }

  Widget _buildErrorBanner() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _errorMessage != null
          ? Container(
              key: const ValueKey('error_banner'),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              decoration: BoxDecoration(
                color: dangerRed.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dangerRed.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: dangerRed,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: dangerRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _errorMessage = null),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close, size: 18, color: dangerRed),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(key: ValueKey('no_error')),
    );
  }

  // ─── Botón Exportar ───────────────────────────────────────────────────

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: _isExporting
              ? null
              : const LinearGradient(
                  colors: [primaryBlue, darkBlue],
                ),
          color: _isExporting ? const Color(0xFFE2E8F0) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isExporting
              ? []
              : [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isExporting ? null : _export,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: _isExporting
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(textMedium),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Generando reporte...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textMedium,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.file_download_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _format == ExportFormat.csv
                              ? 'Exportar CSV'
                              : 'Exportar Excel',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
