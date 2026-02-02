import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/budget.dart';
import '../models/transaction.dart';
import 'transaction_service.dart';

class BudgetService {
  static const String _budgetsKey = 'budgets';
  static const int _maxActiveBudgets = 15; // NUEVO: Límite máximo de presupuestos

  List<Budget> _budgets = [];
  final TransactionService _transactionService = TransactionService();

  List<Budget> get budgets => _budgets;
  
  // CORREGIDO: Mostrar todos los presupuestos activos (no pausados), independientemente de las fechas
  List<Budget> get activeBudgets => _budgets.where((b) => b.isActive).toList();
  
  // NUEVO: Getter para presupuestos que están en su período actual
  List<Budget> get currentPeriodBudgets => _budgets.where((b) => b.isActive && b.isCurrentlyActive).toList();

  // Cargar presupuestos desde almacenamiento local
  Future<void> loadBudgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetsJson = prefs.getString(_budgetsKey);

      if (budgetsJson != null) {
        final List<dynamic> budgetsList = json.decode(budgetsJson);
        _budgets = budgetsList.map((json) => Budget.fromJson(json)).toList();

        // AGREGAR DEBUGGING DESPUÉS DE CARGAR:
        print('=== CARGANDO PRESUPUESTOS ===');
        print('JSON encontrado, cargados ${_budgets.length} presupuestos:');
        for (int i = 0; i < _budgets.length; i++) {
          print('  $i: ${_budgets[i].name} - ID: ${_budgets[i].id}');
        }
        print('============================');

        // Ordenar por fecha de creación (más recientes primero)
        _budgets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // NUEVO: Procesar reinicios automáticos después de cargar
        await processAutomaticResets();
      } else {
        print('=== NO SE ENCONTRÓ JSON DE PRESUPUESTOS ===');
        _budgets = [];
      }
    } catch (e) {
      print('Error loading budgets: $e');
      _budgets = [];
    }
  }

  // NUEVO: Procesar reinicios automáticos de presupuestos
  Future<void> processAutomaticResets() async {
    bool hasChanges = false;
    
    print('=== PROCESANDO REINICIOS AUTOMÁTICOS ===');
    
    for (int i = 0; i < _budgets.length; i++) {
      final budget = _budgets[i];
      
      // Solo procesar presupuestos activos
      if (!budget.isActive) continue;
      
      if (budget.needsReset) {
        print('🔄 Reiniciando presupuesto: ${budget.name} (${budget.periodName})');
        
        // Obtener el nuevo rango de fechas
        final newRange = budget.getNextPeriodRange();
        
        // Actualizar el presupuesto con las nuevas fechas y marcar el reinicio
        _budgets[i] = budget.copyWith(
          startDate: newRange.start,
          endDate: newRange.end,
          lastResetDate: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        hasChanges = true;
        
        print('✅ Reiniciado: ${budget.name}');
        print('   Nuevo período: ${_formatDate(newRange.start)} - ${_formatDate(newRange.end)}');
      }
    }
    
    // Solo guardar si hubo cambios
    if (hasChanges) {
      await _saveBudgets();
      print('💾 Cambios guardados: $hasChanges presupuestos reiniciados');
    } else {
      print('✓ No hay presupuestos que necesiten reiniciarse');
    }
    
    print('========================================');
  }

  // Método auxiliar para formatear fechas en logs
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // Guardar presupuestos en almacenamiento local
  Future<void> _saveBudgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final budgetsJson = json.encode(_budgets.map((b) => b.toJson()).toList());
      await prefs.setString(_budgetsKey, budgetsJson);
      
      // AGREGAR DEBUGGING DESPUÉS DE GUARDAR:
      print('=== GUARDANDO EN SHAREDPREFERENCES ===');
      print('Guardando ${_budgets.length} presupuestos');
      // Mostrar solo primeros 100 caracteres si el JSON es lo suficientemente largo
      if (budgetsJson.length > 100) {
        print('JSON generado: ${budgetsJson.substring(0, 100)}...');
      } else {
        print('JSON generado: $budgetsJson');
      }
      print('=====================================');
    } catch (e) {
      print('Error saving budgets: $e');
      throw Exception('No se pudo guardar el presupuesto');
    }
  }

  // NUEVO: Verificar si se puede crear un nuevo presupuesto
  bool canCreateBudget() {
    return activeBudgets.length < _maxActiveBudgets;
  }

  // NUEVO: Obtener el número de presupuestos disponibles
  int get remainingBudgetsSlots => _maxActiveBudgets - activeBudgets.length;

  // CORREGIDO: Agregar nuevo presupuesto con validación mejorada
  Future<void> addBudget(Budget budget) async {
    print('=== AGREGANDO PRESUPUESTO ===');
    print('Presupuestos antes de agregar: ${_budgets.length}');
    print('Presupuestos activos: ${activeBudgets.length}');
    print('Nombre: ${budget.name}');
    print('Categoría: ${budget.categoryName}');
    print('Período: ${budget.periodName}');
    
    // 1. Validar límite máximo de presupuestos activos
    if (!canCreateBudget()) {
      throw Exception('Has alcanzado el límite máximo de $_maxActiveBudgets presupuestos activos');
    }

    // 2. CORREGIDO: Validación más específica - solo bloquear duplicados EXACTOS
    final duplicateBudgets = _budgets.where((b) {
      // Primero verificar período y estado activo
      if (b.period != budget.period || !b.isActive) return false;
      if (!_isSamePeriodExact(b, budget)) return false;
      
      // Verificar categoría (sistema o personalizada)
      if (budget.hasCustomCategory) {
        // Nuevo presupuesto tiene categoría personalizada
        return b.customCategoryId == budget.customCategoryId;
      } else {
        // Nuevo presupuesto tiene categoría del sistema
        return b.category == budget.category && b.customCategoryId == null;
      }
    }).toList();

    print('Presupuestos duplicados encontrados: ${duplicateBudgets.length}');

    if (duplicateBudgets.isNotEmpty) {
      throw Exception('Ya existe un presupuesto ${budget.periodName.toLowerCase()} de ${budget.categoryName} para este mismo período');
    }

    // 3. Crear nuevo presupuesto
    final newBudget = budget.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    _budgets.add(newBudget);
    
    // CORREGIDO: Ordenar por fecha de creación (más recientes primero)
    _budgets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    await _saveBudgets();

    // AGREGAR DEBUGGING DESPUÉS DE GUARDAR:
    print('=== DESPUÉS DE GUARDAR ===');
    print('Lista _budgets tiene ${_budgets.length} elementos:');
    for (int i = 0; i < _budgets.length; i++) {
      print('  $i: ${_budgets[i].name} - ID: ${_budgets[i].id}');
    }
    print('========================');
    
    print('Presupuesto agregado: ${newBudget.name}');
    print('Total presupuestos: ${_budgets.length}');
    print('Presupuestos activos: ${activeBudgets.length}');
    print('=== FIN AGREGAR PRESUPUESTO ===');
  }

  // NUEVO: Función mejorada para detectar períodos exactamente iguales
  bool _isSamePeriodExact(Budget existing, Budget newBudget) {
    switch (newBudget.period) {
      case BudgetPeriod.weekly:
        // Para semanal: mismo lunes de inicio
        final existingMonday = _getMondayOfWeek(existing.startDate);
        final newMonday = _getMondayOfWeek(newBudget.startDate);
        return existingMonday.isAtSameMomentAs(newMonday);

      case BudgetPeriod.monthly:
        // Para mensual: mismo mes y año
        return existing.startDate.year == newBudget.startDate.year &&
               existing.startDate.month == newBudget.startDate.month;

      case BudgetPeriod.yearly:
        // Para anual: mismo año
        return existing.startDate.year == newBudget.startDate.year;
    }
  }

  // NUEVO: Obtener el lunes de una semana específica
  DateTime _getMondayOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  // MEJORADO: Verificar solapamiento temporal más flexible (mantenido por compatibilidad)
  bool _hasExactPeriodOverlap(Budget existing, Budget newBudget) {
    // Solo considerar como duplicado si es EXACTAMENTE la misma categoría Y período Y fechas
    switch (newBudget.period) {
      case BudgetPeriod.weekly:
        // Para semanal: mismo rango de fechas exacto
        return existing.startDate.isAtSameMomentAs(newBudget.startDate) &&
               existing.endDate.isAtSameMomentAs(newBudget.endDate);

      case BudgetPeriod.monthly:
        // Para mensual: mismo mes y año exacto
        return existing.startDate.year == newBudget.startDate.year &&
               existing.startDate.month == newBudget.startDate.month;

      case BudgetPeriod.yearly:
        // Para anual: mismo año exacto
        return existing.startDate.year == newBudget.startDate.year;
    }
  }

  // NUEVO: Método auxiliar para verificar solapamiento de rangos de fechas
  bool _dateRangesOverlap(DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    return start1.isBefore(end2.add(Duration(days: 1))) &&
        end1.isAfter(start2.subtract(Duration(days: 1)));
  }

  // CORREGIDO: Verificar si dos presupuestos se superponen en tiempo (mantenido por compatibilidad)
  bool _periodsOverlap(Budget existing, Budget newBudget) {
    return _dateRangesOverlap(existing.startDate, existing.endDate,
        newBudget.startDate, newBudget.endDate);
  }

  // Actualizar presupuesto existente
  Future<void> updateBudget(Budget budget) async {
    final index = _budgets.indexWhere((b) => b.id == budget.id);
    if (index == -1) {
      throw Exception('Presupuesto no encontrado');
    }

    // Validar que no haya conflictos con otros presupuestos al actualizar
    final conflictingBudgets = _budgets.where((b) {
      // Excluir el presupuesto actual
      if (b.id == budget.id) return false;
      // Solo presupuestos activos con mismo período exacto
      if (b.period != budget.period || !b.isActive) return false;
      if (!_isSamePeriodExact(b, budget)) return false;
      
      // Verificar categoría (sistema o personalizada)
      if (budget.hasCustomCategory) {
        return b.customCategoryId == budget.customCategoryId;
      } else {
        return b.category == budget.category && b.customCategoryId == null;
      }
    }).toList();

    if (conflictingBudgets.isNotEmpty) {
      throw Exception('Ya existe otro presupuesto ${budget.periodName.toLowerCase()} de ${budget.categoryName} para este período');
    }

    _budgets[index] = budget.copyWith(updatedAt: DateTime.now());
    await _saveBudgets();
  }

  // Eliminar presupuesto
  Future<void> deleteBudget(String budgetId) async {
    final initialLength = _budgets.length;
    _budgets.removeWhere((b) => b.id == budgetId);

    if (_budgets.length == initialLength) {
      throw Exception('Presupuesto no encontrado');
    }

    await _saveBudgets();
  }

  // Activar/desactivar presupuesto
  Future<void> toggleBudget(String budgetId) async {
    final index = _budgets.indexWhere((b) => b.id == budgetId);
    if (index == -1) {
      throw Exception('Presupuesto no encontrado');
    }

    final currentBudget = _budgets[index];
    final newActiveState = !currentBudget.isActive;

    // Si se está activando, verificar límite
    if (newActiveState && !canCreateBudget()) {
      throw Exception('No puedes activar más presupuestos. Límite máximo: $_maxActiveBudgets');
    }

    _budgets[index] = _budgets[index].copyWith(
      isActive: newActiveState,
      updatedAt: DateTime.now(),
    );
    await _saveBudgets();
  }

  // Obtener presupuesto por ID
  Budget? getBudgetById(String budgetId) {
    try {
      return _budgets.firstWhere((b) => b.id == budgetId);
    } catch (e) {
      return null;
    }
  }

  // Obtener progreso de un presupuesto específico
  BudgetProgress getBudgetProgress(Budget budget) {
    // Asegurar que las transacciones estén cargadas
    final transactions = _transactionService.transactions;

    // Filtrar transacciones del período y categoría del presupuesto
    final budgetTransactions = transactions.where((transaction) {
      // Debe ser un gasto
      if (transaction.type != TransactionType.expense) return false;
      
      // Verificar que esté dentro del período
      if (!transaction.date.isAfter(budget.startDate.subtract(const Duration(days: 1))) ||
          !transaction.date.isBefore(budget.endDate.add(const Duration(days: 1)))) {
        return false;
      }
      
      // Verificar categoría
      if (budget.hasCustomCategory) {
        // Presupuesto con categoría personalizada
        return transaction.customCategoryId == budget.customCategoryId;
      } else {
        // Presupuesto con categoría del sistema
        return transaction.expenseCategory == budget.category && 
               transaction.customCategoryId == null;
      }
    }).toList();

    // Calcular monto gastado
    final spentAmount = budgetTransactions.fold(0.0, (sum, t) => sum + t.amount);

    return BudgetProgress(
      budget: budget,
      spentAmount: spentAmount,
      transactions: budgetTransactions,
    );
  }

  // Obtener progreso de todos los presupuestos activos
  List<BudgetProgress> getAllBudgetProgress() {
    return activeBudgets.map((budget) => getBudgetProgress(budget)).toList();
  }

  // Obtener presupuestos por categoría
  List<Budget> getBudgetsByCategory(ExpenseCategory category) {
    return _budgets.where((b) => b.category == category).toList();
  }

  // Obtener presupuestos que necesitan atención (cerca del límite o excedidos)
  List<BudgetProgress> getBudgetsNeedingAttention() {
    return getAllBudgetProgress().where((progress) =>
    progress.status == BudgetStatus.warning ||
        progress.status == BudgetStatus.danger ||
        progress.status == BudgetStatus.exceeded
    ).toList();
  }

  // Verificar si se puede realizar un gasto (para alertas en tiempo real)
  BudgetCheckResult checkExpenseAgainstBudgets(double amount, ExpenseCategory category) {
    final relevantBudgets = activeBudgets.where((b) => b.category == category).toList();

    if (relevantBudgets.isEmpty) {
      return BudgetCheckResult(
        canSpend: true,
        message: 'Sin restricciones de presupuesto',
        affectedBudgets: [],
      );
    }

    List<BudgetProgress> affectedBudgets = [];
    List<String> warnings = [];
    bool canSpend = true;

    for (var budget in relevantBudgets) {
      final progress = getBudgetProgress(budget);
      final newSpentAmount = progress.spentAmount + amount;
      final newStatus = budget.getStatus(newSpentAmount);

      affectedBudgets.add(BudgetProgress(
        budget: budget,
        spentAmount: newSpentAmount,
        transactions: progress.transactions,
      ));

      if (newStatus == BudgetStatus.exceeded) {
        final excess = newSpentAmount - budget.amount;
        warnings.add('Excederías el presupuesto de ${budget.categoryName} por \$${excess.toStringAsFixed(0)}');
        canSpend = false;
      } else if (newStatus == BudgetStatus.danger) {
        warnings.add('Te acercarías al límite del presupuesto de ${budget.categoryName}');
      } else if (newStatus == BudgetStatus.warning) {
        warnings.add('Estarías usando el ${((newSpentAmount / budget.amount) * 100).toStringAsFixed(0)}% de tu presupuesto de ${budget.categoryName}');
      }
    }

    return BudgetCheckResult(
      canSpend: canSpend,
      message: warnings.isEmpty ? 'Gasto dentro del presupuesto' : warnings.join('\n'),
      affectedBudgets: affectedBudgets,
    );
  }

  // MEJORADO: Obtener resumen de todos los presupuestos con información del límite
  BudgetSummary getBudgetSummary() {
    final allProgress = getAllBudgetProgress();

    double totalBudgeted = 0;
    double totalSpent = 0;
    int onTrackCount = 0;
    int warningCount = 0;
    int exceededCount = 0;

    for (var progress in allProgress) {
      totalBudgeted += progress.budget.amount;
      totalSpent += progress.spentAmount;

      switch (progress.status) {
        case BudgetStatus.safe:
          onTrackCount++;
          break;
        case BudgetStatus.warning:
          warningCount++;
          break;
        case BudgetStatus.danger:
        case BudgetStatus.exceeded:
          exceededCount++;
          break;
      }
    }

    // Debug para verificar la carga de presupuestos
    print('Debug - Total budgets loaded: ${_budgets.length}');
    print('Debug - Active budgets: ${activeBudgets.length}');
    print('Debug - Current period budgets: ${currentPeriodBudgets.length}');

    return BudgetSummary(
      totalBudgets: allProgress.length,
      totalBudgeted: totalBudgeted,
      totalSpent: totalSpent,
      onTrackCount: onTrackCount,
      warningCount: warningCount,
      exceededCount: exceededCount,
      budgetProgress: allProgress,
      maxBudgets: _maxActiveBudgets, // NUEVO
      remainingSlots: remainingBudgetsSlots, // NUEVO
    );
  }

  // Generar fechas automáticas para presupuestos según el período
  static Map<String, DateTime> generateBudgetDates(BudgetPeriod period, DateTime? startDate) {
    final start = startDate ?? DateTime.now();
    DateTime end;

    switch (period) {
      case BudgetPeriod.weekly:
      // Comenzar el lunes de la semana actual
        final mondayOfWeek = start.subtract(Duration(days: start.weekday - 1));
        end = mondayOfWeek.add(const Duration(days: 6));
        return {'start': mondayOfWeek, 'end': end};

      case BudgetPeriod.monthly:
      // Primer día del mes actual
        final firstDayOfMonth = DateTime(start.year, start.month, 1);
        final lastDayOfMonth = DateTime(start.year, start.month + 1, 0);
        return {'start': firstDayOfMonth, 'end': lastDayOfMonth};

      case BudgetPeriod.yearly:
      // Primer día del año actual
        final firstDayOfYear = DateTime(start.year, 1, 1);
        final lastDayOfYear = DateTime(start.year, 12, 31);
        return {'start': firstDayOfYear, 'end': lastDayOfYear};
    }
  }

  // Método temporal para debugging
  void debugPrintBudgets() {
    print('=== DEBUG BUDGETS ===');
    print('Total budgets: ${_budgets.length}');
    for (int i = 0; i < _budgets.length; i++) {
      final budget = _budgets[i];
      print('Budget $i: ${budget.name} - ${budget.categoryName} - ${budget.periodName} - Active: ${budget.isActive}');
    }
    print('Active budgets: ${activeBudgets.length}');
    print('==================');
  }
}

// Clase para el resultado de verificación de gastos
class BudgetCheckResult {
  final bool canSpend;
  final String message;
  final List<BudgetProgress> affectedBudgets;

  BudgetCheckResult({
    required this.canSpend,
    required this.message,
    required this.affectedBudgets,
  });
}

// ACTUALIZADA: Clase para el resumen general de presupuestos
class BudgetSummary {
  final int totalBudgets;
  final double totalBudgeted;
  final double totalSpent;
  final int onTrackCount;
  final int warningCount;
  final int exceededCount;
  final List<BudgetProgress> budgetProgress;
  final int maxBudgets; // NUEVO
  final int remainingSlots; // NUEVO

  BudgetSummary({
    required this.totalBudgets,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.onTrackCount,
    required this.warningCount,
    required this.exceededCount,
    required this.budgetProgress,
    required this.maxBudgets, // NUEVO
    required this.remainingSlots, // NUEVO
  });

  double get remainingBudget => (totalBudgeted - totalSpent).clamp(0.0, double.infinity);
  double get spentPercentage => totalBudgeted > 0 ? (totalSpent / totalBudgeted) : 0.0;
  bool get overallHealthy => exceededCount == 0 && warningCount <= (totalBudgets * 0.3);
  bool get isNearLimit => remainingSlots <= 3; // NUEVO: Alerta cuando quedan pocos slots
}