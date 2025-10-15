# GitHub Copilot Instructions - Ahorro App

## Project Overview
Flutter personal finance application focused on expense tracking and savings goals management. The app uses Spanish language throughout and follows a Colombian peso (COP) currency format.

## Architecture & Core Patterns

### Service Layer Pattern
- **Services** (`lib/services/`): Handle data persistence using SharedPreferences
- **Models** (`lib/models/`): JSON-serializable data classes with business logic
- **Screens** (`lib/screens/`): UI layer following StatefulWidget pattern with animations

### Key Data Flow
1. Services load data from SharedPreferences on app start
2. Models contain computed getters for business logic (progress, validation, etc.)
3. Screens use service methods and rebuild UI via setState()

### Financial Goal System
Goals support multiple states and automatic contributions:
- **States**: `active`, `paused`, `completed`, `cancelled`  
- **Frequencies**: `daily`, `weekly`, `monthly` auto-save
- **Limit**: Maximum 15 goals per user
- **Validation**: Contributions cannot exceed target amount

## Critical Implementation Details

### Currency & Formatting
Always use `FormatUtils.formatMoney()` for displaying amounts. Colombian peso format: `$1.500.000`

### Goal Contribution Logic
```dart
// Suggested contribution auto-calculated based on frequency and time remaining
double calculateSuggestedContribution() {
  switch (autoSaveFrequency) {
    case AutoSaveFrequency.daily: return remainingAmount / daysRemaining;
    case AutoSaveFrequency.weekly: return remainingAmount / (daysRemaining / 7);
    case AutoSaveFrequency.monthly: return remainingAmount / monthsRemaining;
  }
}
```

### Animation Patterns
Screens use consistent animation controllers with staggered fade-in and slide-up effects:
- Duration: 800ms
- Curves: `Curves.easeOut` with intervals
- Always dispose controllers in widget lifecycle

### State Management
- No external state management (no Provider/Bloc)
- Services act as singletons with in-memory lists
- Persistence through SharedPreferences JSON serialization
- Manual refresh via service calls and setState()

## Development Workflows

### Adding New Goal Features
1. Update `FinancialGoal` model with new fields
2. Update `toJson()/fromJson()` serialization methods
3. Update `GoalService` methods for new functionality
4. Update UI screens with new form fields and validation
5. Test persistence by restarting app

### Color Consistency
Use predefined color constants throughout:
```dart
static const Color primaryBlue = Color(0xFF3B82F6);
static const Color successGreen = Color(0xFF059669);
static const Color warningYellow = Color(0xFFF59E0B);
static const Color dangerRed = Color(0xFFDC2626);
```

### Error Handling Pattern
Always wrap service calls in try-catch and show user-friendly messages:
```dart
try {
  await _goalService.addGoal(goal);
  _showSuccessMessage();
} catch (e) {
  _showErrorMessage(e.toString());
}
```

## Project-Specific Conventions

### Spanish Text & Validation
- All user-facing text in Spanish
- Error messages should be descriptive and actionable
- Use Colombian Spanish terms (e.g., "plata" instead of "dinero" for informal contexts)

### File Naming
- Screens: `*_screen.dart`
- Services: `*_service.dart` 
- Models: singular nouns (`financial_goal.dart`)
- Utils: `*_utils.dart`

### Widget Structure
Large screens split into private `_build*()` methods following this pattern:
1. `_buildModernAppBar()`
2. `_buildHeaderSection()`
3. `_build*Section()` for each UI section
4. `_buildModernFAB()` for floating action buttons

## Testing & Debugging
- Use `debug_*.dart` files for testing specific features
- Services include print statements for error debugging
- Always test goal limits (15 max) and contribution validation
- Test app restart to verify SharedPreferences persistence

## Common Pitfalls
- Don't forget to call `_saveGoals()` after modifying goal lists
- Always validate contribution amounts against remaining goal amount
- Ensure proper disposal of animation controllers
- Test edge cases: 0 days remaining, completed goals, paused goals
- Handle JSON parsing errors gracefully with default values