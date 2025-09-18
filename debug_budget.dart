// Script temporal para debugging de presupuestos
// ELIMINAR después de verificar que todo funciona

import 'lib/models/budget.dart';
import 'lib/models/transaction.dart';
import 'lib/services/budget_service.dart';

void main() async {
  print('=== INICIANDO DEBUG DE PRESUPUESTOS ===');
  
  final budgetService = BudgetService();
  
  // Cargar presupuestos existentes
  await budgetService.loadBudgets();
  print('Presupuestos cargados: ${budgetService.budgets.length}');
  print('Presupuestos activos: ${budgetService.activeBudgets.length}');
  
  // Crear presupuestos de prueba
  try {
    // Presupuesto 1: Comida mensual
    final budget1 = Budget(
      name: 'Comida Enero',
      amount: 500.0,
      period: BudgetPeriod.monthly,
      category: ExpenseCategory.food,
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 1, 31),
      createdAt: DateTime.now(),
    );
    
    await budgetService.addBudget(budget1);
    print('✅ Presupuesto 1 agregado exitosamente');
    
    // Presupuesto 2: Transporte mensual (diferente categoría)
    final budget2 = Budget(
      name: 'Transporte Enero',
      amount: 200.0,
      period: BudgetPeriod.monthly,
      category: ExpenseCategory.transport,
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 1, 31),
      createdAt: DateTime.now(),
    );
    
    await budgetService.addBudget(budget2);
    print('✅ Presupuesto 2 agregado exitosamente');
    
    // Presupuesto 3: Comida febrero (mismo tipo pero diferente mes)
    final budget3 = Budget(
      name: 'Comida Febrero',
      amount: 550.0,
      period: BudgetPeriod.monthly,
      category: ExpenseCategory.food,
      startDate: DateTime(2025, 2, 1),
      endDate: DateTime(2025, 2, 28),
      createdAt: DateTime.now(),
    );
    
    await budgetService.addBudget(budget3);
    print('✅ Presupuesto 3 agregado exitosamente');
    
    // Presupuesto 4: Entretenimiento semanal
    final budget4 = Budget(
      name: 'Entretenimiento Semana 1',
      amount: 100.0,
      period: BudgetPeriod.weekly,
      category: ExpenseCategory.entertainment,
      startDate: DateTime(2025, 1, 6), // Lunes
      endDate: DateTime(2025, 1, 12), // Domingo
      createdAt: DateTime.now(),
    );
    
    await budgetService.addBudget(budget4);
    print('✅ Presupuesto 4 agregado exitosamente');
    
    // Presupuesto 5: Salud anual
    final budget5 = Budget(
      name: 'Salud 2025',
      amount: 2000.0,
      period: BudgetPeriod.yearly,
      category: ExpenseCategory.health,
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 12, 31),
      createdAt: DateTime.now(),
    );
    
    await budgetService.addBudget(budget5);
    print('✅ Presupuesto 5 agregado exitosamente');
    
  } catch (e) {
    print('❌ Error agregando presupuesto: $e');
  }
  
  // Verificar estado final
  budgetService.debugPrintBudgets();
  
  final summary = budgetService.getBudgetSummary();
  print('\n=== RESUMEN FINAL ===');
  print('Total presupuestos: ${summary.totalBudgets}');
  print('Presupuesto total: \$${summary.totalBudgeted}');
  print('Slots restantes: ${summary.remainingSlots}/${summary.maxBudgets}');
  
  print('\n=== DEBUG COMPLETADO ===');
}
