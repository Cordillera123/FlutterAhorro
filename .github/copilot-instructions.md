# GitHub Copilot Instructions - Ahorro App

## Project Overview
Flutter personal finance app (Spanish UI, Colombian peso `$1.500.000,00`). Manages expense tracking, budgets with auto-reset, savings goals, recurring expenses, and custom categories.

**Tech Stack**: Flutter 3.9+, SharedPreferences persistence, fl_chart, json_annotation.

## Architecture

### Service Layer (Singletons)
All services in [lib/services/](lib/services/) use singleton pattern with SharedPreferences:
- **TransactionService**: Extends `ChangeNotifier` for reactive cross-screen updates - screens must call `addListener()`/`removeListener()` in lifecycle
- **BudgetService**: Calculates spent amounts dynamically from TransactionService (no stored state)
- **CategoryService**: Extends `ChangeNotifier` for custom categories - tracks system + user-created categories
- **RecurringExpenseService**: Auto-creates transactions on `HomeScreen.initState()` via `processRecurringExpensesForToday()`
- **GoalService/BudgetService**: 15 entity limit enforced via `_maxActiveBudgets` constant

```
UI (setState + listeners) → Services (in-memory + _save*()) → SharedPreferences (JSON)
```

### Critical Pattern: Budget Spending
BudgetService **never** stores `spentAmount` - always calculated by filtering transactions:
```dart
final progress = budgetService.getBudgetProgress(budget);  // Filters transactions by category + date range
```

### Budget Auto-Reset
Triggered on `loadBudgets()` → `processAutomaticResets()`. Checks `Budget.needsReset` getter which evaluates:
- **Weekly**: Resets every Monday (`DateTime.monday`)
- **Monthly**: Resets on day 1 of month
- **Yearly**: Resets January 1st

Uses `Budget.getNextPeriodRange()` to calculate new `startDate`/`endDate`, then calls `copyWith()` to update. See [REINICIO_AUTOMATICO_PRESUPUESTOS.md](REINICIO_AUTOMATICO_PRESUPUESTOS.md).

### Custom Categories System
Dual category model: system enums + user-created:
- **System**: `ExpenseCategory` enum (12 fixed categories: transport, food, utilities, etc.)
- **Custom**: `CustomCategory` model with ID format `custom_{timestamp}` managed by `CategoryService`
- Models store both: `category` (enum) + `customCategoryId/Name/Emoji` (nullable)
- Check with `hasCustomCategory` getter before accessing category fields

## Key Patterns

### JSON Serialization
- **Manual**: Budget, Goal, Transaction, CustomCategory (`toJson()`/`fromJson()` methods)
- **Generated**: RecurringExpense only (uses `@JsonSerializable` → `recurring_expense.g.dart`)
- Regenerate: `flutter pub run build_runner build`
- **Backward compat**: Always add defaults in `fromJson()`: `json['field'] ?? defaultValue`

### Formatting (always use [lib/utils/format_utils.dart](lib/utils/format_utils.dart))
```dart
FormatUtils.formatMoney(amount)       // $1.500.000,00 (Colombian format with 2 decimals)
FormatUtils.formatDateForList(date)   // "Hoy", "Ayer", "15 Ene" (Spanish relative dates)
FormatUtils.formatDateShort(date)     // "15 Ene"
```

### Screen Structure
Screens use `CustomScrollView` with `_build*()` method decomposition pattern:
```dart
_buildModernAppBar()    // SliverAppBar with gradient
_buildHeaderSection()   // Summary cards/stats
_buildModernFAB()       // Floating action button
```

### Animation Pattern (all screens)
```dart
_animationController = AnimationController(duration: Duration(milliseconds: 800), vsync: this);
_fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(...);
// CRITICAL: Always dispose in widget lifecycle
@override void dispose() {
  _animationController.dispose();
  super.dispose();
}
```

### Listener Pattern (ChangeNotifier Services)
TransactionService and CategoryService use `ChangeNotifier`:
```dart
// In initState():
_transactionService.addListener(_onTransactionServiceChanged);
_categoryService.addListener(_onCategoryServiceChanged);

// In dispose():
_transactionService.removeListener(_onTransactionServiceChanged);
_categoryService.removeListener(_onCategoryServiceChanged);
```

## Development Commands
```powershell
flutter run                            # Dev mode (portrait-only, Spanish locale es_CO)
flutter pub run build_runner build     # Regenerate .g.dart files after model changes
dart debug_budget_test.dart            # Run debug/test scripts for budget logic
```

## Adding Categories
1. Update `ExpenseCategory` enum in [lib/models/transaction.dart](lib/models/transaction.dart)
2. Add display logic in `Transaction.categoryName` and `Budget.categoryName` getters
3. Add emoji mapping in `Transaction.categoryIcon` and `Budget.categoryIcon` getters
4. Update category pickers in screens: [add_transaction_screen.dart](lib/screens/add_transaction_screen.dart), [create_budget_screen.dart](lib/screens/create_budget_screen.dart)
5. Add Spanish name in `CategoryService._getSystemCategoryName()` if adding system category
6. Run `flutter pub run build_runner build` if modifying `@JsonSerializable` models

## Common Pitfalls
- **Persistence**: Always call `_save*()` after modifying service lists (e.g., `_saveBudgets()`, `_saveTransactions()`)
- **Budget spending**: Never try to set `budget.spentAmount` - it's dynamically calculated from transactions
- **Animation leaks**: Always `dispose()` AnimationControllers in widget lifecycle
- **Category access**: Check `hasCustomCategory` before accessing category fields to avoid enum mismatch
- **Listener cleanup**: Remove listeners in `dispose()` to prevent memory leaks
- **Backward compat**: Add defaults in `fromJson()` when adding new fields: `json['field'] ?? defaultValue`
- **Recurring expenses**: Only show categories that make sense - see filtered list in [add_recurring_expense_screen.dart](lib/screens/add_recurring_expense_screen.dart#L200-L220)

## Conventions
- **Language**: Spanish UI text with informal tone ("¡Meta completada!", "Hoy", "Ayer")
- **Currency**: Colombian pesos with 2 decimals via `FormatUtils.formatMoney()`
- **Colors**: Defined per-screen (not global theme): `primaryBlue: Color(0xFF3B82F6)`, `successGreen: Color(0xFF059669)`, `dangerRed: Color(0xFFDC2626)`
- **Navigation**: 5-tab bottom nav via [main_navigation_screen.dart](lib/screens/main_navigation_screen.dart)
- **Logging**: Use `print()` for debug - see extensive logging in `BudgetService.processAutomaticResets()`
- **ID generation**: Timestamp-based: `'${DateTime.now().millisecondsSinceEpoch}'` or `CustomCategory.generateId()`

## Integration Points
- **RecurringExpense → Transaction**: Auto-creates on `HomeScreen.initState()` via `processRecurringExpensesForToday()`
- **Budget → Transaction**: Spending calculated by filtering transactions by category + date range in `getBudgetProgress()`
- **RecurringExpense → Budget**: Impact calculated in `getBudgetImpactSummary()` - see [INTEGRACION_GASTOS_RECURRENTES.md](INTEGRACION_GASTOS_RECURRENTES.md)
- **Category changes**: Propagate via `CategoryService` ChangeNotifier to all listening screens