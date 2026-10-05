import 'package:flutter_test/flutter_test.dart';
import 'package:ahorro_app/models/history_filters.dart';
import 'package:ahorro_app/models/transaction.dart';

Transaction _tx({
  String id = 't1',
  double amount = 100,
  TransactionType type = TransactionType.expense,
  String description = 'Café con leche',
  DateTime? date,
  ExpenseCategory? expenseCategory = ExpenseCategory.food,
  IncomeCategory? incomeCategory,
  String? customCategoryId,
  String? customCategoryName,
  String accountId = 'acc1',
  bool? isTransferOut,
}) {
  return Transaction(
    id: id,
    amount: amount,
    type: type,
    description: description,
    date: date ?? DateTime(2026, 6, 15),
    expenseCategory: type == TransactionType.expense ? expenseCategory : null,
    incomeCategory: type == TransactionType.income ? incomeCategory : null,
    customCategoryId: customCategoryId,
    customCategoryName: customCategoryName,
    accountId: accountId,
    isTransferOut: isTransferOut,
  );
}

void main() {
  group('HistoryFilters.matches — búsqueda de texto', () {
    test('sin filtro, todo coincide', () {
      expect(HistoryFilters.empty.matches(_tx()), true);
    });

    test('encuentra por descripción, insensible a mayúsculas', () {
      const f = HistoryFilters(searchQuery: 'CAFÉ');
      expect(f.matches(_tx(description: 'Café con leche')), true);
    });

    test('ignora acentos al buscar', () {
      const f = HistoryFilters(searchQuery: 'cafe');
      expect(f.matches(_tx(description: 'Café con leche')), true);
    });

    test('no encuentra texto que no aparece', () {
      const f = HistoryFilters(searchQuery: 'gasolina');
      expect(f.matches(_tx(description: 'Café con leche')), false);
    });

    test('también busca en el nombre de categoría personalizada', () {
      const f = HistoryFilters(searchQuery: 'mascotas');
      expect(
        f.matches(
          _tx(
            description: 'Comida del perro',
            customCategoryId: 'custom_1',
            customCategoryName: 'Mascotas',
          ),
        ),
        true,
      );
    });
  });

  group('HistoryFilters.matches — rango de fechas', () {
    test('respeta dateFrom', () {
      final f = HistoryFilters(dateFrom: DateTime(2026, 6, 10));
      expect(f.matches(_tx(date: DateTime(2026, 6, 9))), false);
      expect(f.matches(_tx(date: DateTime(2026, 6, 10))), true);
      expect(f.matches(_tx(date: DateTime(2026, 6, 11))), true);
    });

    test('respeta dateTo', () {
      final f = HistoryFilters(dateTo: DateTime(2026, 6, 20));
      expect(f.matches(_tx(date: DateTime(2026, 6, 21))), false);
      expect(f.matches(_tx(date: DateTime(2026, 6, 20))), true);
    });

    test('dateFrom y dateTo juntos delimitan un rango cerrado', () {
      final f = HistoryFilters(
        dateFrom: DateTime(2026, 6, 10),
        dateTo: DateTime(2026, 6, 20),
      );
      expect(f.matches(_tx(date: DateTime(2026, 6, 15))), true);
      expect(f.matches(_tx(date: DateTime(2026, 5, 30))), false);
      expect(f.matches(_tx(date: DateTime(2026, 7, 1))), false);
    });
  });

  group('HistoryFilters.matches — cuenta, tipo y monto', () {
    test('filtra por cuenta', () {
      const f = HistoryFilters(accountIds: {'acc1'});
      expect(f.matches(_tx(accountId: 'acc1')), true);
      expect(f.matches(_tx(accountId: 'acc2')), false);
    });

    test('filtra por tipo (incluye transfer)', () {
      const f = HistoryFilters(transactionTypes: {TransactionType.transfer});
      expect(
        f.matches(_tx(type: TransactionType.transfer, isTransferOut: true)),
        true,
      );
      expect(f.matches(_tx(type: TransactionType.expense)), false);
    });

    test('filtra por rango de monto', () {
      const f = HistoryFilters(amountMin: 50, amountMax: 150);
      expect(f.matches(_tx(amount: 49.99)), false);
      expect(f.matches(_tx(amount: 50)), true);
      expect(f.matches(_tx(amount: 150)), true);
      expect(f.matches(_tx(amount: 150.01)), false);
    });
  });

  group('HistoryFilters.matches — categoría', () {
    test('filtra por categoría de gasto del sistema', () {
      const f = HistoryFilters(expenseCategories: {ExpenseCategory.food});
      expect(f.matches(_tx(expenseCategory: ExpenseCategory.food)), true);
      expect(f.matches(_tx(expenseCategory: ExpenseCategory.transport)), false);
    });

    test('filtra por categoría de ingreso', () {
      const f = HistoryFilters(incomeCategories: {IncomeCategory.salary});
      expect(
        f.matches(
          _tx(
            type: TransactionType.income,
            incomeCategory: IncomeCategory.salary,
          ),
        ),
        true,
      );
      expect(
        f.matches(
          _tx(
            type: TransactionType.income,
            incomeCategory: IncomeCategory.freelance,
          ),
        ),
        false,
      );
    });

    test('filtra por categoría personalizada', () {
      const f = HistoryFilters(customCategoryIds: {'custom_1'});
      expect(f.matches(_tx(customCategoryId: 'custom_1')), true);
      expect(f.matches(_tx(customCategoryId: 'custom_2')), false);
    });

    test(
      'con un filtro de categoría activo, las transferencias quedan fuera',
      () {
        const f = HistoryFilters(expenseCategories: {ExpenseCategory.food});
        expect(
          f.matches(_tx(type: TransactionType.transfer, isTransferOut: true)),
          false,
        );
      },
    );

    test('sin filtro de categoría, las transferencias sí pasan', () {
      expect(
        HistoryFilters.empty.matches(
          _tx(type: TransactionType.transfer, isTransferOut: true),
        ),
        true,
      );
    });
  });

  group('HistoryFilters — flags y copyWith', () {
    test('hasAnyFilter refleja cualquier criterio activo', () {
      expect(HistoryFilters.empty.hasAnyFilter, false);
      expect(const HistoryFilters(searchQuery: 'x').hasAnyFilter, true);
      expect(HistoryFilters(dateFrom: DateTime(2026, 1, 1)).hasAnyFilter, true);
    });

    test('advancedFilterCount cuenta grupos, no criterios individuales', () {
      const f = HistoryFilters(
        accountIds: {'a', 'b'},
        expenseCategories: {ExpenseCategory.food, ExpenseCategory.transport},
      );
      expect(f.advancedFilterCount, 2); // cuentas + categorías, no 4
    });

    test('clearAdvanced conserva búsqueda y tipo, limpia el resto', () {
      final f = HistoryFilters(
        searchQuery: 'café',
        transactionTypes: const {TransactionType.expense},
        accountIds: const {'acc1'},
        amountMin: 10,
      );
      final cleared = f.clearAdvanced();
      expect(cleared.searchQuery, 'café');
      expect(cleared.transactionTypes, {TransactionType.expense});
      expect(cleared.hasAdvancedFilters, false);
    });

    test('copyWith con clearDateFrom limpia solo esa fecha', () {
      final f = HistoryFilters(
        dateFrom: DateTime(2026, 1, 1),
        dateTo: DateTime(2026, 12, 31),
      );
      final result = f.copyWith(clearDateFrom: true);
      expect(result.dateFrom, isNull);
      expect(result.dateTo, DateTime(2026, 12, 31));
    });
  });

  group('HistoryFilters.matches — combinación de criterios (AND)', () {
    test('todos los criterios deben cumplirse a la vez', () {
      final f = HistoryFilters(
        searchQuery: 'café',
        dateFrom: DateTime(2026, 6, 1),
        dateTo: DateTime(2026, 6, 30),
        accountIds: const {'acc1'},
        expenseCategories: const {ExpenseCategory.food},
        amountMin: 5,
        amountMax: 200,
      );

      final matching = _tx(
        description: 'Café con leche',
        date: DateTime(2026, 6, 15),
        accountId: 'acc1',
        expenseCategory: ExpenseCategory.food,
        amount: 100,
      );
      expect(f.matches(matching), true);

      // Falla un solo criterio (cuenta) → debe rechazar todo.
      expect(f.matches(matching.copyWith(accountId: 'acc2')), false);
    });
  });
}
