import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import 'account_service.dart';

class TransactionService extends ChangeNotifier {
  static const String _transactionsKey = 'transactions';

  // Singleton
  static final TransactionService _instance = TransactionService._internal();
  factory TransactionService() => _instance;
  TransactionService._internal();

  final AccountService _accountService = AccountService();

  List<Transaction> _transactions = [];

  // Getter para todas las transacciones (sin filtrar por cuenta)
  List<Transaction> get allTransactions => List.unmodifiable(_transactions);

  // Getter para transacciones de la cuenta activa
  List<Transaction> get transactions {
    final filtered = _transactions
        .where((t) => t.accountId == _accountService.activeAccountId)
        .toList();
    return List.unmodifiable(filtered);
  }

  // Obtener transacciones de una cuenta específica
  List<Transaction> transactionsForAccount(String accountId) {
    return _transactions.where((t) => t.accountId == accountId).toList();
  }

  // Cargar transacciones desde SharedPreferences con migración automática
  Future<void> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = prefs.getString(_transactionsKey);

      if (transactionsJson != null) {
        final List<dynamic> transactionsList = json.decode(transactionsJson);
        _transactions = transactionsList
            .map((json) => Transaction.fromJson(json))
            .toList();

        // Migración: reasignar transacciones con accountId vacío o huérfano
        bool necesitaGuardar = false;
        for (int i = 0; i < _transactions.length; i++) {
          final resolved = _accountService.resolveAccountId(
            _transactions[i].accountId,
          );
          if (resolved != _transactions[i].accountId) {
            _transactions[i] = _transactions[i].copyWith(accountId: resolved);
            necesitaGuardar = true;
            print(
              '🛠️ Migrada transacción huérfana: ${_transactions[i].description}',
            );
          }
        }

        // Ordenar por fecha (más reciente primero)
        _transactions.sort((a, b) => b.date.compareTo(a.date));

        // Guardar cambios si se migró alguna transacción
        if (necesitaGuardar) {
          await _saveTransactions();
          print('✅ Transacciones huérfanas migradas y guardadas');
        }
      }

      notifyListeners();
    } catch (e) {
      print('❌ Error cargando transacciones: $e');
      _transactions = [];
      notifyListeners();
    }
  }

  // Guardar transacciones en SharedPreferences
  Future<void> _saveTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = json.encode(
        _transactions.map((transaction) => transaction.toJson()).toList(),
      );
      await prefs.setString(_transactionsKey, transactionsJson);
    } catch (e) {
      print('Error guardando transacciones: $e');
    }
  }

  // Reemplaza TODAS las transacciones (usado al restaurar una copia de
  // seguridad). El llamador es responsable de validar los datos antes.
  Future<void> replaceAllForRestore(List<Transaction> transactions) async {
    _transactions = List.of(transactions)
      ..sort((a, b) => b.date.compareTo(a.date));
    await _saveTransactions();
    notifyListeners();
  }

  /// Un monto debe ser finito y positivo: NaN/infinito romperían los balances
  /// y ni siquiera se pueden serializar a JSON.
  void _assertValidAmount(double amount) {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('El monto debe ser un número válido mayor a cero.');
    }
  }

  // Agregar una nueva transacción (asigna cuenta activa si no tiene)
  Future<void> addTransaction(Transaction transaction) async {
    _assertValidAmount(transaction.amount);
    final transactionWithAccount = transaction.copyWith(
      accountId: _accountService.resolveAccountId(transaction.accountId),
    );

    print('🟢 ADD - accountId asignado: ${transactionWithAccount.accountId}');
    print(
      '🟢 ADD - activeAccountId actual: ${_accountService.activeAccountId}',
    );

    _transactions.add(transactionWithAccount);
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    await _saveTransactions();
    notifyListeners();
  }

  /// Crea una transferencia contable entre dos cuentas propias: resta
  /// [amount] de [fromAccountId] y suma [amount] a [toAccountId]. NO es un
  /// ingreso ni un gasto — no se contabiliza en presupuestos ni estadísticas.
  ///
  /// Internamente crea DOS [Transaction] (una por cuenta) enlazadas por el
  /// mismo `transferId`; [deleteTransaction] las borra siempre juntas.
  Future<void> createTransfer({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    if (fromAccountId == toAccountId) {
      throw Exception('La cuenta de origen y destino no pueden ser la misma.');
    }
    if (!amount.isFinite || amount <= 0) {
      throw Exception('El monto de la transferencia debe ser mayor a cero.');
    }
    if (_accountService.getAccountById(fromAccountId) == null ||
        _accountService.getAccountById(toAccountId) == null) {
      throw Exception('Una de las cuentas seleccionadas ya no existe.');
    }

    final transferId = 'transfer_${DateTime.now().millisecondsSinceEpoch}';
    final description = (note != null && note.trim().isNotEmpty)
        ? note.trim()
        : 'Transferencia entre cuentas';

    final outgoing = Transaction(
      id: '${transferId}_out',
      amount: amount,
      type: TransactionType.transfer,
      description: description,
      date: date,
      accountId: fromAccountId,
      transferId: transferId,
      relatedAccountId: toAccountId,
      isTransferOut: true,
    );

    final incoming = Transaction(
      id: '${transferId}_in',
      amount: amount,
      type: TransactionType.transfer,
      description: description,
      date: date,
      accountId: toAccountId,
      transferId: transferId,
      relatedAccountId: fromAccountId,
      isTransferOut: false,
    );

    _transactions.addAll([outgoing, incoming]);
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    await _saveTransactions();
    notifyListeners();
  }

  // Eliminar una transacción. Si es una pata de una transferencia, se borra
  // también su pareja (no puede quedar una transferencia a medias).
  Future<void> deleteTransaction(String id) async {
    Transaction? target;
    for (final t in _transactions) {
      if (t.id == id) {
        target = t;
        break;
      }
    }

    if (target != null && target.transferId != null) {
      _transactions.removeWhere((t) => t.transferId == target!.transferId);
    } else {
      _transactions.removeWhere((transaction) => transaction.id == id);
    }
    await _saveTransactions();
    notifyListeners();
  }

  // Actualizar una transacción existente (con protección de accountId)
  Future<void> updateTransaction(Transaction updatedTransaction) async {
    _assertValidAmount(updatedTransaction.amount);
    final index = _transactions.indexWhere(
      (t) => t.id == updatedTransaction.id,
    );
    if (index != -1) {
      final existing = _transactions[index];

      print('🟡 UPDATE - ID: ${updatedTransaction.id}');
      print('🟡 UPDATE - accountId recibido: ${updatedTransaction.accountId}');
      print('🟡 UPDATE - accountId existente: ${existing.accountId}');
      print(
        '🟡 UPDATE - activeAccountId actual: ${_accountService.activeAccountId}',
      );

      final rawAccountId = updatedTransaction.accountId.isNotEmpty
          ? updatedTransaction.accountId
          : existing.accountId;
      final accountId = _accountService.resolveAccountId(rawAccountId);

      print('🟡 UPDATE - accountId final a guardar: $accountId');

      _transactions[index] = updatedTransaction.copyWith(accountId: accountId);
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      await _saveTransactions();
      notifyListeners();
    }
  }

  // Balance total de la cuenta activa (balance inicial + transacciones,
  // incluyendo el efecto de las transferencias entrantes/salientes)
  double get totalBalance => balanceForAccount(_accountService.activeAccountId);

  // Balance de cualquier cuenta (no solo la activa) — usado por la pantalla
  // de transferencias para mostrar el saldo disponible de origen/destino.
  double balanceForAccount(String accountId) {
    double balance =
        _accountService.getAccountById(accountId)?.initialBalance ?? 0.0;
    for (var transaction in transactionsForAccount(accountId)) {
      balance = transaction.applyToBalance(balance);
    }
    return balance;
  }

  // Total de ingresos de la cuenta activa
  double get totalIncome {
    return transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0, (sum, t) => sum + t.amount);
  }

  // Total de gastos de la cuenta activa
  double get totalExpenses {
    return transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0, (sum, t) => sum + t.amount);
  }

  // Transacciones del mes actual (cuenta activa)
  List<Transaction> get thisMonthTransactions {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    return transactions.where((transaction) {
      return transaction.date.isAfter(
            firstDayOfMonth.subtract(const Duration(days: 1)),
          ) &&
          transaction.date.isBefore(
            lastDayOfMonth.add(const Duration(days: 1)),
          );
    }).toList();
  }

  // Gastos por categoría del mes actual
  Map<ExpenseCategory, double> get monthlyExpensesByCategory {
    final monthlyExpenses = thisMonthTransactions
        .where((t) => t.type == TransactionType.expense)
        .toList();

    Map<ExpenseCategory, double> categoryTotals = {};

    for (var transaction in monthlyExpenses) {
      final category = transaction.expenseCategory ?? ExpenseCategory.other;
      categoryTotals[category] =
          (categoryTotals[category] ?? 0) + transaction.amount;
    }

    return categoryTotals;
  }

  // Limpiar todas las transacciones (solo para desarrollo)
  Future<void> clearAllTransactions() async {
    _transactions.clear();
    await _saveTransactions();
    notifyListeners();
  }

  /// Elimina únicamente las transacciones que pertenecen a [accountId].
  /// Las transacciones de otras cuentas no se tocan.
  Future<void> clearTransactionsForAccount(String accountId) async {
    _transactions.removeWhere((t) => t.accountId == accountId);
    await _saveTransactions();
    notifyListeners();
  }

  /// Elimina exactamente las transacciones cuyos IDs están en [ids].
  /// Es la forma más segura de borrar una lista concreta visible al usuario.
  Future<void> deleteTransactionsByIds(List<String> ids) async {
    final idSet = ids.toSet();
    _transactions.removeWhere((t) => idSet.contains(t.id));
    await _saveTransactions();
    notifyListeners();
  }

  // Forzar notificación manual
  void forceUpdate() {
    notifyListeners();
  }

  // Reasignar categoría personalizada a "Otros" al eliminar una categoría
  Future<int> reassignCategoryToOther(String customCategoryId) async {
    int count = 0;
    for (int i = 0; i < _transactions.length; i++) {
      if (_transactions[i].customCategoryId == customCategoryId) {
        _transactions[i] = _transactions[i].copyWithCategoryAsOther();
        count++;
      }
    }

    if (count > 0) {
      await _saveTransactions();
      notifyListeners();
    }

    return count;
  }
}
