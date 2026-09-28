import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/account.dart';
import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Transaction.applyToBalance', () {
    final base = DateTime(2026, 1, 1);

    Transaction build({
      required TransactionType type,
      bool? isTransferOut,
    }) {
      return Transaction(
        id: 't1',
        amount: 100,
        type: type,
        description: 'x',
        date: base,
        accountId: 'acc',
        isTransferOut: isTransferOut,
      );
    }

    test('ingreso suma al balance', () {
      final t = build(type: TransactionType.income);
      expect(t.applyToBalance(500), 600);
    });

    test('gasto resta del balance', () {
      final t = build(type: TransactionType.expense);
      expect(t.applyToBalance(500), 400);
    });

    test('transferencia saliente resta del balance', () {
      final t = build(type: TransactionType.transfer, isTransferOut: true);
      expect(t.applyToBalance(500), 400);
    });

    test('transferencia entrante suma al balance', () {
      final t = build(type: TransactionType.transfer, isTransferOut: false);
      expect(t.applyToBalance(500), 600);
    });
  });

  group('Transaction.categoryName / categoryIcon para transferencias', () {
    test('una transferencia no cae en el switch de gastos', () {
      final t = Transaction(
        id: 't1',
        amount: 50,
        type: TransactionType.transfer,
        description: 'x',
        date: DateTime.now(),
        accountId: 'acc',
      );
      expect(t.categoryName, 'Transferencia');
      expect(t.categoryIcon, '🔄');
    });
  });

  group('TransactionService.createTransfer — ciclo de vida completo', () {
    late String accountA;
    late String accountB;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
      final accountService = AccountService();
      await accountService.loadAccounts(); // crea la cuenta por defecto
      accountA = accountService.activeAccountId;

      final second = await accountService.addAccount(
        name: 'Banco Pichincha',
        type: AccountType.savings,
      );
      accountB = second.id;
    });

    test('crea dos transacciones enlazadas y actualiza ambos balances', () async {
      final transactionService = TransactionService();
      final balanceABefore = transactionService.balanceForAccount(accountA);
      final balanceBBefore = transactionService.balanceForAccount(accountB);

      await transactionService.createTransfer(
        fromAccountId: accountA,
        toAccountId: accountB,
        amount: 50,
        date: DateTime.now(),
        note: 'Ahorro del mes',
      );

      expect(transactionService.balanceForAccount(accountA), balanceABefore - 50);
      expect(transactionService.balanceForAccount(accountB), balanceBBefore + 50);

      final legs = transactionService.allTransactions
          .where((t) => t.type == TransactionType.transfer)
          .toList();
      expect(legs.length, 2);

      final outgoing = legs.firstWhere((t) => t.accountId == accountA);
      final incoming = legs.firstWhere((t) => t.accountId == accountB);

      expect(outgoing.isTransferOut, true);
      expect(outgoing.relatedAccountId, accountB);
      expect(incoming.isTransferOut, false);
      expect(incoming.relatedAccountId, accountA);
      expect(outgoing.transferId, incoming.transferId);
      expect(outgoing.transferId, isNotNull);

      // NO debe contarse como ingreso ni gasto en ninguna de las dos cuentas
      expect(transactionService.totalIncome, 0);
      expect(transactionService.totalExpenses, 0);
    });

    test('rechaza transferir a la misma cuenta', () async {
      final transactionService = TransactionService();
      expect(
        () => transactionService.createTransfer(
          fromAccountId: accountA,
          toAccountId: accountA,
          amount: 10,
          date: DateTime.now(),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('rechaza montos negativos o cero', () async {
      final transactionService = TransactionService();
      expect(
        () => transactionService.createTransfer(
          fromAccountId: accountA,
          toAccountId: accountB,
          amount: 0,
          date: DateTime.now(),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('borrar una pata de la transferencia borra también la otra', () async {
      final transactionService = TransactionService();

      await transactionService.createTransfer(
        fromAccountId: accountA,
        toAccountId: accountB,
        amount: 25,
        date: DateTime.now(),
      );

      final legs = transactionService.allTransactions
          .where((t) => t.type == TransactionType.transfer && t.amount == 25)
          .toList();
      expect(legs.length, 2);
      final transferId = legs.first.transferId;

      await transactionService.deleteTransaction(legs.first.id);

      final remaining = transactionService.allTransactions
          .where((t) => t.transferId == transferId)
          .toList();
      expect(remaining, isEmpty);
    });
  });
}
