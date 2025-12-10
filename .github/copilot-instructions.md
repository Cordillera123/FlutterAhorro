# GitHub Copilot Instructions - Ahorro App

## Project Overview
Flutter personal finance app for expense tracking, budgets, savings goals, and recurring expenses. Spanish language throughout, Colombian peso (COP) format (`$1.500.000`).

**Tech Stack**: Flutter 3.9+, SharedPreferences for persistence, fl_chart for visualizations, json_annotation for serialization.

## Architecture & Core Patterns

### Service Layer (Singleton + Repository Pattern)
All services follow singleton pattern and persist to SharedPreferences:
- **TransactionService**: Extends `ChangeNotifier` for reactive updates across screens
- **GoalService**: 15 goal limit, auto-calculated contributions
- **BudgetService**: 15 active budget limit, depends on TransactionService
- **RecurringExpenseService**: Auto-creates transactions based on schedule, integrates with BudgetService
- **StatsService**: Read-only aggregations from TransactionService

### Data Flow Architecture
```
UI Layer (Screens) 
  ↓ setState() + manual refresh
Service Layer (Singletons)
  ↓ JSON serialization via SharedPreferences
Persistence Layer (SharedPreferences)
```

**Key Pattern**: Services hold in-memory lists, persist via `_save*()` private methods. Only `TransactionService` uses `ChangeNotifier` for cross-screen updates.

### Cross-Service Dependencies
```dart
// RecurringExpenseService creates transactions AND checks budgets
final transactionService = TransactionService();
final budgetService = BudgetService();
await transactionService.addTransaction(transaction);
// BudgetService auto-calculates spent amounts from transactions
```

**Critical**: BudgetService doesn't store spent amounts - it calculates them by filtering TransactionService transactions by date/category.

### Budget Auto-Reset System
Budgets automatically reset on specific dates regardless of creation date:
- **Weekly**: Every Monday (sets startDate to current Monday, endDate to Sunday)
- **Monthly**: 1st day of month (sets startDate to day 1, endDate to last day)
- **Yearly**: January 1st (sets startDate to Jan 1, endDate to Dec 31)

Reset logic runs on `BudgetService.loadBudgets()` via `processAutomaticResets()`:
```dart
// In Budget model
bool get needsReset {
  // Checks if today matches reset day AND hasn't been reset today yet
  // Uses lastResetDate (or createdAt if null) to prevent duplicate resets
}

DateRange getNextPeriodRange() {
  // Returns new startDate/endDate based on period type
  // Weekly: Monday-Sunday of current week
  // Monthly: 1st to last day of current month
  // Yearly: Jan 1 to Dec 31 of current year
}
```

Transactions from previous periods remain in history but are excluded from current budget calculations.

## Model Layer Patterns

### JSON Serialization Strategy
- Manual `toJson()`/`fromJson()` for most models (Goal, Budget, Transaction)
- `json_serializable` only for RecurringExpense (`.g.dart` files)
- Regenerate with: `flutter pub run build_runner build`

### Business Logic in Models
Models contain computed getters for derived state:
```dart
// FinancialGoal
double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, double.infinity);
double get progressPercentage => (currentAmount / targetAmount).clamp(0.0, 1.0);
int get daysRemaining => targetDate.difference(DateTime.now()).inDays + 1;

// Budget
bool get isCurrentlyActive => DateTime.now().isBetween(startDate, endDate);
```

## Critical Implementation Details

### Currency & Date Formatting
Always use `FormatUtils` utilities:
```dart
FormatUtils.formatMoney(amount)        // $1.500.000,00 (2 decimals)
FormatUtils.formatDateShort(date)      // "15 Ene"
FormatUtils.formatDateForList(date)    // "Hoy", "Ayer", "15 Ene"
FormatUtils.isSameMonth(date1, date2)  // Month comparison helper
```

### Entity Limits & Validation
- **Goals**: Max 15 total, validate in `GoalService.addGoal()`
- **Budgets**: Max 15 active, validate in `BudgetService.addBudget()` and `toggleBudget()`
- **Goal Contributions**: Cannot exceed `goal.remainingAmount`
- **Budget Spending**: Calculated dynamically, no stored state

### Recurring Expense Processing
```dart
// Called on HomeScreen init - auto-creates transactions for today
await _recurringExpenseService.processRecurringExpensesForToday();

// Model method determines if expense should run
bool shouldRunToday() {
  // Checks frequency (daily/weekly/monthly/custom)
  // Compares lastProcessed date to prevent duplicates
  // Respects startDate/endDate boundaries
}
```

### Animation Patterns
Consistent across all screens:
```dart
// In initState()
_animationController = AnimationController(
  duration: const Duration(milliseconds: 800),
  vsync: this,
);
_fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
  CurvedAnimation(
    parent: _animationController,
    curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
  ),
);
// Always dispose in widget lifecycle
```

## Development Workflows

### Running the App
```powershell
# Development mode (hot reload enabled)
flutter run

# Build for Android
flutter build apk

# Build for iOS
flutter build ios

# Generate JSON serialization code (when modifying @JsonSerializable models)
flutter pub run build_runner build

# Watch mode for continuous code generation
flutter pub run build_runner watch --delete-conflicting-outputs
```

### Adding New Transaction Categories
1. Update `ExpenseCategory` enum in `lib/models/transaction.dart`
2. Add category name/icon in `Transaction.categoryName` getter
3. Update `Budget` model's category getters and icon mappings
4. Update all screen dropdowns (AddTransaction, CreateBudget, etc.)
5. Regenerate `transaction.g.dart`: `flutter pub run build_runner build`
6. **Important**: For recurring expenses, only include categories that make sense for recurring patterns (exclude sporadic categories like Gifts/Clothing)

### Modifying Persisted Models
1. Update model class with new fields
2. Update `toJson()`/`fromJson()` with defaults for backward compatibility:
   ```dart
   isActive: json['isActive'] ?? true,  // Default if field missing
   ```
3. Test app restart to ensure old data loads without crashes
4. Optional: Add migration logic in service `load*()` methods

### Cross-Service Feature Development
Example: Adding budget alerts to recurring expenses
1. Load both services: `await budgetService.loadBudgets()`
2. Check budget status: `budgetService.getBudgetProgress(budget)`
3. Create transaction: `await transactionService.addTransaction()`
4. Budget progress auto-updates on next read (no manual sync needed)

### Testing Features Locally
Use `debug_*.dart` files in project root:
```dart
// debug_budget_test.dart pattern
void main() async {
  final service = BudgetService();
  await service.loadBudgets();
  service.debugPrintBudgets(); // Services expose debug methods
  // Test operations...
}
```
Run: `dart debug_budget_test.dart`

**Available Debug Scripts**:
- `debug_budget_test.dart` - Budget creation and validation
- `debug_budget_reset_test.dart` - Auto-reset functionality
- `debug_budget.dart` - General budget operations

### App Initialization Pattern
Entry point in `lib/main.dart`:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Configure system UI
  SystemChrome.setSystemUIOverlayStyle(...);
  
  runApp(const AhorroApp());
}
```
**Key Points**:
- Always use `WidgetsFlutterBinding.ensureInitialized()` before async operations
- Spanish localization configured: `Locale('es', 'CO')`
- Portrait-only orientation enforced
- Global theme defined in MaterialApp

## Project-Specific Conventions

### Navigation Structure
Main navigation uses bottom nav bar with 5 tabs (see `main_navigation_screen.dart`):
1. Home (HomeScreen) - Overview with recurring expense processing
2. Budgets (BudgetsScreen) - Budget management
3. Goals (GoalsScreen) - Savings goals
4. History (HistoryScreen) - Transaction history
5. Recurring (RecurringExpensesScreen) - Automatic expenses
6
**PageView Pattern**: Uses PageController for swipe navigation between tabs with animation sync.

### UI Entry Points
- **Main Screens**: All screens accessible via `MainNavigationScreen` with PageView
- **Modals**: Add/Edit screens use `showModalBottomSheet` or `Navigator.push`
- **Success Screens**: Dedicated success screens (`budget_success_screen.dart`, `goal_success_screen.dart`, `transaction_success_screen.dart`) shown after create operations
- **Splash Screen**: Initial screen loads in `main.dart`, transitions to `MainNavigationScreen`

### Color System
Define color constants at top of each screen:
```dart
static const Color primaryBlue = Color(0xFF3B82F6);
static const Color successGreen = Color(0xFF059669);
static const Color warningYellow = Color(0xFFF59E0B);
static const Color dangerRed = Color(0xFFDC2626);
```

### Widget Components
Reusable widgets in `lib/widgets/`:
- **AppLogo**: Animated logo used in headers (`AppLogo(size: 80)`)
- Custom widgets follow same animation/color patterns as screens

### Screen Widget Structure
Large screens follow this `_build*()` decomposition:
```dart
Widget build(BuildContext context) {
  return Scaffold(
    body: CustomScrollView(
      slivers: [
        _buildModernAppBar(),      // SliverAppBar with logo
        SliverToBoxAdapter(
          child: Column([
            _buildHeaderSection(),   // Summary cards
            _build*Section(),        // Feature-specific sections
          ]),
        ),
      ],
    ),
    floatingActionButton: _buildModernFAB(),  // Consistent FAB style
  );
}
```

### Error Handling Pattern
```dart
try {
  await _service.operation();
  _showSuccessMessage('Operación exitosa');
} catch (e) {
  _showErrorMessage(e.toString());  // Exception messages are user-friendly
}
```

### Spanish Text Guidelines
- All UI text in Spanish (Colombian dialect preferred)
- Error messages descriptive: "No puedes crear más de 15 metas"
- Use informal tone for messages: "¡Meta completada!" not "Su meta ha sido completada"

## Common Pitfalls

### Service Persistence Issues
❌ Modifying list without persisting:
```dart
_goals.add(newGoal);  // In-memory change only
```
✅ Always call save method:
```dart
_goals.add(newGoal);
await _saveGoals();  // Persist to SharedPreferences
```

### Budget Calculation Confusion
❌ Trying to update budget spent amount:
```dart
budget.spentAmount += transaction.amount;  // No such field!
```
✅ Budget spending is calculated dynamically:
```dart
final progress = budgetService.getBudgetProgress(budget);
final spentAmount = progress.spentAmount;  // Calculated from transactions
```

### Animation Controller Leaks
❌ Forgetting to dispose:
```dart
// Memory leak if not disposed
```
✅ Always dispose in State lifecycle:
```dart
@override
void dispose() {
  _animationController.dispose();
  super.dispose();
}
```

### Listener Management
Only `TransactionService` uses listeners - don't add to other services:
```dart
// HomeScreen listens for transaction changes
_transactionService.addListener(_onTransactionServiceChanged);

// Don't forget to remove listener
@override
void dispose() {
  _transactionService.removeListener(_onTransactionServiceChanged);
  super.dispose();
}
```