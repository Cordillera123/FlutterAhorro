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
    print('🔵 GETTER - Total transacciones en memoria: ${_transactions.length}');
    print('🔵 GETTER - activeAccountId: ${_accountService.activeAccountId}');
    for (var t in _transactions) {
      print('🔵   - ${t.description} (accountId: ${t.accountId})');
    }
    print('🔵 GETTER - Transacciones filtradas: ${filtered.length}');
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
          final resolved =
          _accountService.resolveAccountId(_transactions[i].accountId);
          if (resolved != _transactions[i].accountId) {
            _transactions[i] = _transactions[i].copyWith(accountId: resolved);
            necesitaGuardar = true;
            print(
                '🛠️ Migrada transacción huérfana: ${_transactions[i].description}');
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

  // Agregar una nueva transacción (asigna cuenta activa si no tiene)
  Future<void> addTransaction(Transaction transaction) async {
    final transactionWithAccount = transaction.copyWith(
      accountId: _accountService.resolveAccountId(transaction.accountId),
    );

    print('🟢 ADD - accountId asignado: ${transactionWithAccount.accountId}');
    print('🟢 ADD - activeAccountId actual: ${_accountService.activeAccountId}');

    _transactions.add(transactionWithAccount);
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    await _saveTransactions();
    notifyListeners();
  }
  // Eliminar una transacción
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((transaction) => transaction.id == id);
    await _saveTransactions();
    notifyListeners();
  }

  // Actualizar una transacción existente (con protección de accountId)
  Future<void> updateTransaction(Transaction updatedTransaction) async {
    final index = _transactions.indexWhere((t) => t.id == updatedTransaction.id);
    if (index != -1) {
      final existing = _transactions[index];

      print('🟡 UPDATE - ID: ${updatedTransaction.id}');
      print('🟡 UPDATE - accountId recibido: ${updatedTransaction.accountId}');
      print('🟡 UPDATE - accountId existente: ${existing.accountId}');
      print('🟡 UPDATE - activeAccountId actual: ${_accountService.activeAccountId}');

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
  // Balance total de la cuenta activa (balance inicial + transacciones)
  double get totalBalance {
    double balance = _accountService.activeAccount.initialBalance;
    for (var transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        balance += transaction.amount;
      } else {
        balance -= transaction.amount;
      }
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
      return transaction.date
          .isAfter(firstDayOfMonth.subtract(const Duration(days: 1))) &&
          transaction.date.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
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
      categoryTotals[category] = (categoryTotals[category] ?? 0) + transaction.amount;
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