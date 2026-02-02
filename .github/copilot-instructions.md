# GitHub Copilot Instructions - Ahorro App

## Project Overview
Flutter personal finance app (Spanish UI, Colombian peso `$1.500.000,00`). Manages expense tracking, budgets with auto-reset, savings goals, and recurring expenses.

**Tech Stack**: Flutter 3.9+, SharedPreferences persistence, fl_chart, json_annotation.

## Architecture

### Service Layer (Singletons)
All services in [lib/services/](lib/services/) use singleton pattern with SharedPreferences:
- **TransactionService**: Extends `ChangeNotifier` for reactive cross-screen updates
- **BudgetService**: Calculates spent amounts dynamically from TransactionService (no stored state)
- **GoalService/BudgetService**: 15 entity limit enforced
- **RecurringExpenseService**: Auto-creates transactions on HomeScreen init

```
UI (setState + listeners) → Services (in-memory + _save*()) → SharedPreferences (JSON)
```

### Critical Pattern: Budget Spending
BudgetService calculates spending by filtering transactions - never stores `spentAmount`:
```dart
final progress = budgetService.getBudgetProgress(budget);  // Calculated from transactions
```

### Budget Auto-Reset
Runs on `loadBudgets()` → `processAutomaticResets()`. Resets based on period (weekly=Monday, monthly=1st, yearly=Jan 1) using `Budget.needsReset` and `getNextPeriodRange()`.

## Key Patterns

### JSON Serialization
- Manual `toJson()`/`fromJson()` for Budget, Goal, Transaction
- `@JsonSerializable` only for RecurringExpense (generates `.g.dart`)
- Regenerate: `flutter pub run build_runner build`

### Formatting (always use [lib/utils/format_utils.dart](lib/utils/format_utils.dart))
```dart
FormatUtils.formatMoney(amount)       // $1.500.000,00
FormatUtils.formatDateForList(date)   // "Hoy", "Ayer", "15 Ene"
```

### Screen Structure
Screens use `CustomScrollView` with `_build*()` decomposition:
```dart
_buildModernAppBar()    // SliverAppBar
_buildHeaderSection()   // Summary cards
_buildModernFAB()       // Floating action button
```

### Animation Pattern (all screens)
```dart
_animationController = AnimationController(duration: Duration(milliseconds: 800), vsync: this);
// ALWAYS dispose in widget lifecycle
```

### Listener Pattern (TransactionService only)
```dart
_transactionService.addListener(_onChanged);
// dispose: _transactionService.removeListener(_onChanged);
```

## Development Commands
```powershell
flutter run                                              # Dev mode
flutter pub run build_runner build                       # Regenerate .g.dart files
dart debug_budget_test.dart                              # Run debug scripts
```

## Adding Categories
1. Update `ExpenseCategory` enum in [lib/models/transaction.dart](lib/models/transaction.dart)
2. Update `categoryName`/`categoryIcon` getters in Transaction and Budget models
3. Update screen dropdowns (AddTransaction, CreateBudget)
4. Run `flutter pub run build_runner build`

## Common Pitfalls
- **Persistence**: Always call `_save*()` after modifying service lists
- **Budget spending**: Never try to set `budget.spentAmount` - it's calculated
- **Animation leaks**: Always `dispose()` AnimationControllers
- **Backward compat**: Add defaults in `fromJson()`: `json['field'] ?? defaultValue`

## Conventions
- Spanish UI text (informal tone: "¡Meta completada!")
- Colors defined per-screen: `primaryBlue: Color(0xFF3B82F6)`, `successGreen: Color(0xFF059669)`
- Navigation: 5-tab bottom nav via [main_navigation_screen.dart](lib/screens/main_navigation_screen.dart)