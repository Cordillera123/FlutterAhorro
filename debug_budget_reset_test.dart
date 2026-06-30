import 'lib/services/budget_service.dart';
import 'lib/models/budget.dart';
import 'lib/models/transaction.dart';

// Script para probar la funcionalidad de reinicio automático de presupuestos
void main() async {
  print('=== TESTING BUDGET AUTOMATIC RESET FUNCTIONALITY ===\n');
  
  final budgetService = BudgetService();
  
  // Cargar presupuestos existentes (esto llamará automáticamente a processAutomaticResets)
  print('1. CARGANDO PRESUPUESTOS...');
  await budgetService.loadBudgets();
  
  print('\n2. ESTADO ACTUAL DE PRESUPUESTOS');
  budgetService.debugPrintBudgets();
  
  // Crear presupuestos de prueba con diferentes períodos
  print('\n3. CREANDO PRESUPUESTOS DE PRUEBA...');
  
  // Calcular fechas para el período actual
  final now = DateTime.now();
  
  // Presupuesto semanal (debe reiniciarse cada lunes)
  final mondayOfWeek = now.subtract(Duration(days: now.weekday - DateTime.monday));
  final sundayOfWeek = mondayOfWeek.add(const Duration(days: 6));
  
  final weeklyBudget = Budget(
    name: 'Presupuesto Semanal Test',
    amount: 100.0,
    period: BudgetPeriod.weekly,
    category: ExpenseCategory.food,
    startDate: mondayOfWeek,
    endDate: sundayOfWeek,
    createdAt: now,
    isActive: true,
    accountId: 'account_default',
  );
  
  // Presupuesto mensual (debe reiniciarse el día 1 de cada mes)
  final firstDayOfMonth = DateTime(now.year, now.month, 1);
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
  
  final monthlyBudget = Budget(
    name: 'Presupuesto Mensual Test',
    amount: 500.0,
    period: BudgetPeriod.monthly,
    category: ExpenseCategory.transport,
    startDate: firstDayOfMonth,
    endDate: lastDayOfMonth,
    createdAt: now,
    isActive: true,
    accountId: 'account_default',
  );
  
  // Presupuesto anual (debe reiniciarse el 1 de enero)
  final firstDayOfYear = DateTime(now.year, 1, 1);
  final lastDayOfYear = DateTime(now.year, 12, 31);
  
  final yearlyBudget = Budget(
    name: 'Presupuesto Anual Test',
    amount: 5000.0,
    period: BudgetPeriod.yearly,
    category: ExpenseCategory.entertainment,
    startDate: firstDayOfYear,
    endDate: lastDayOfYear,
    createdAt: now,
    isActive: true,
    accountId: 'account_default',
  );
  
  try {
    // Agregar presupuestos
    await budgetService.addBudget(weeklyBudget);
    print('✅ Presupuesto semanal agregado');
    
    await budgetService.addBudget(monthlyBudget);
    print('✅ Presupuesto mensual agregado');
    
    await budgetService.addBudget(yearlyBudget);
    print('✅ Presupuesto anual agregado');
    
    print('\n4. ESTADO DESPUÉS DE AGREGAR PRESUPUESTOS');
    budgetService.debugPrintBudgets();
    
    // Verificar si algún presupuesto necesita reiniciarse
    print('\n5. VERIFICANDO SI NECESITAN REINICIARSE...');
    final budgets = budgetService.activeBudgets;
    for (final budget in budgets) {
      final needsReset = budget.needsReset;
      final status = needsReset ? '🔄 NECESITA REINICIO' : '✓ No necesita reinicio';
      print('${budget.name} (${budget.periodName}): $status');
      
      if (needsReset) {
        final nextRange = budget.getNextPeriodRange();
        print('  → Próximo período: ${_formatDate(nextRange.start)} - ${_formatDate(nextRange.end)}');
      }
    }
    
    // Simular la recarga (esto debe procesar los reinicios automáticos)
    print('\n6. SIMULANDO RECARGA DE LA APP (debería reiniciar si es necesario)...');
    await budgetService.loadBudgets();
    
    print('\n7. ESTADO FINAL DESPUÉS DE LA RECARGA');
    budgetService.debugPrintBudgets();
    
    print('\n✅ PRUEBA COMPLETADA EXITOSAMENTE');
    print('\nNOTA: Los presupuestos se reiniciarán automáticamente en:');
    print('  - Semanales: Cada lunes');
    print('  - Mensuales: El día 1 de cada mes');
    print('  - Anuales: El 1 de enero de cada año');
    
  } catch (e) {
    print('\n❌ ERROR: $e');
  }
}

String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}
