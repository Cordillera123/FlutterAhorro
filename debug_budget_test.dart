import 'lib/services/budget_service.dart';
import 'lib/models/budget.dart';
import 'lib/models/transaction.dart';

// Script para probar la funcionalidad de presupuestos
void main() async {
  print('=== TESTING BUDGET FUNCTIONALITY ===');
  
  final budgetService = BudgetService();
  
  // Cargar presupuestos existentes
  await budgetService.loadBudgets();
  
  print('\n1. ESTADO INICIAL');
  budgetService.debugPrintBudgets();
  
  // Crear presupuestos de prueba
  final budget1 = Budget(
    name: 'Presupuesto Comida Septiembre',
    amount: 500.0,
    period: BudgetPeriod.monthly,
    category: ExpenseCategory.food,
    startDate: DateTime(2025, 9, 1),
    endDate: DateTime(2025, 9, 30),
    createdAt: DateTime.now(),
    isActive: true,
  );
  
  final budget2 = Budget(
    name: 'Presupuesto Transporte Septiembre',
    amount: 300.0,
    period: BudgetPeriod.monthly,
    category: ExpenseCategory.transport,
    startDate: DateTime(2025, 9, 1),
    endDate: DateTime(2025, 9, 30),
    createdAt: DateTime.now(),
    isActive: true,
  );
  
  final budget3 = Budget(
    name: 'Presupuesto Entretenimiento Septiembre',
    amount: 200.0,
    period: BudgetPeriod.monthly,
    category: ExpenseCategory.entertainment,
    startDate: DateTime(2025, 9, 1),
    endDate: DateTime(2025, 9, 30),
    createdAt: DateTime.now(),
    isActive: true,
  );
  
  try {
    print('\n2. AGREGANDO PRESUPUESTOS');
    
    await budgetService.addBudget(budget1);
    print('✅ Budget 1 agregado');
    
    await budgetService.addBudget(budget2);
    print('✅ Budget 2 agregado');
    
    await budgetService.addBudget(budget3);
    print('✅ Budget 3 agregado');
    
    print('\n3. ESTADO DESPUÉS DE AGREGAR');
    budgetService.debugPrintBudgets();
    
    // Probar activar/desactivar
    final budgets = budgetService.activeBudgets;
    if (budgets.isNotEmpty) {
      print('\n4. PAUSANDO PRIMER PRESUPUESTO');
      await budgetService.toggleBudget(budgets.first.id!);
      budgetService.debugPrintBudgets();
      
      print('\n5. REACTIVANDO PRIMER PRESUPUESTO');
      await budgetService.toggleBudget(budgets.first.id!);
      budgetService.debugPrintBudgets();
    }
    
    print('\n6. RESUMEN FINAL');
    final summary = budgetService.getBudgetSummary();
    print('Total presupuestos: ${summary.totalBudgets}');
    print('Presupuestos activos: ${budgetService.activeBudgets.length}');
    print('Slots restantes: ${summary.remainingSlots}');
    
    print('\n✅ TODAS LAS PRUEBAS COMPLETADAS EXITOSAMENTE');
    
  } catch (e) {
    print('\n❌ ERROR: $e');
  }
}
