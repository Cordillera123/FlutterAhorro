import '../transaction.dart';

/// Representación ligera de un movimiento financiero.
/// Desacopla el análisis del modelo [Transaction] para futuras extensiones.
class MovementRecord {
  final DateTime date;
  final double amount;
  final bool isIncome;
  final String categoryKey;
  final String displayName;
  final String? emoji;
  final String accountId;
  final IncomeCategory? incomeCategory;
  final ExpenseCategory? expenseCategory;

  const MovementRecord({
    required this.date,
    required this.amount,
    required this.isIncome,
    required this.categoryKey,
    required this.displayName,
    this.emoji,
    required this.accountId,
    this.incomeCategory,
    this.expenseCategory,
  });

  factory MovementRecord.fromTransaction(Transaction transaction) {
    final isIncome = transaction.type == TransactionType.income;
    return MovementRecord(
      date: transaction.date,
      amount: transaction.amount,
      isIncome: isIncome,
      categoryKey: categoryKeyFromTransaction(transaction),
      displayName: transaction.categoryName,
      emoji: transaction.customCategoryEmoji,
      accountId: transaction.accountId,
      incomeCategory: transaction.incomeCategory,
      expenseCategory: transaction.expenseCategory,
    );
  }

  static String categoryKeyFromTransaction(Transaction transaction) {
    if (transaction.type == TransactionType.expense) {
      if (transaction.hasCustomCategory) {
        return 'custom:${transaction.customCategoryId}';
      }
      return 'system:${transaction.expenseCategory?.name ?? 'other'}';
    }
    return 'income:${transaction.incomeCategory?.name ?? 'other'}';
  }

  static String categoryKeyFromBudget(BudgetCategoryRef ref) => ref.categoryKey;

  static String budgetCategoryKey({
    required bool hasCustomCategory,
    String? customCategoryId,
    ExpenseCategory? systemCategory,
  }) {
    if (hasCustomCategory && customCategoryId != null) {
      return 'custom:$customCategoryId';
    }
    return 'system:${systemCategory?.name ?? 'other'}';
  }
}

/// Referencia mínima de categoría de presupuesto para el snapshot builder.
class BudgetCategoryRef {
  final String categoryKey;
  final bool hasCustomCategory;
  final String? customCategoryId;
  final ExpenseCategory category;

  const BudgetCategoryRef({
    required this.categoryKey,
    required this.hasCustomCategory,
    this.customCategoryId,
    required this.category,
  });
}
