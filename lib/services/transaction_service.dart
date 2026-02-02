import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

class TransactionService extends ChangeNotifier {
  static const String _transactionsKey = 'transactions';

  // Instancia única del servicio (Singleton)
  static final TransactionService _instance = TransactionService._internal();
  factory TransactionService() => _instance;
  TransactionService._internal();

  // Lista en memoria de todas las transacciones
  List<Transaction> _transactions = [];

  // Getter para obtener todas las transacciones
  List<Transaction> get transactions => List.unmodifiable(_transactions);

  // Cargar transacciones desde el almacenamiento local
  Future<void> loadTransactions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final transactionsJson = prefs.getString(_transactionsKey);

      if (transactionsJson != null) {
        final List<dynamic> transactionsList = json.decode(transactionsJson);
        _transactions = transactionsList
            .map((json) => Transaction.fromJson(json))
            .toList();

        // Ordenar por fecha (más reciente primero)
        _transactions.sort((a, b) => b.date.compareTo(a.date));
      }

      // Notificar a los listeners que los datos han cambiado
      notifyListeners();
    } catch (e) {
      print('Error cargando transacciones: $e');
      _transactions = [];
      notifyListeners();
    }
  }

  // Guardar transacciones en el almacenamiento local
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

  // Agregar una nueva transacción
  Future<void> addTransaction(Transaction transaction) async {
    _transactions.add(transaction);
    // Mantener ordenado por fecha
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    await _saveTransactions();

    // Notificar a los listeners que los datos han cambiado
    notifyListeners();
  }

  // Eliminar una transacción
  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((transaction) => transaction.id == id);
    await _saveTransactions();

    // Notificar a los listeners que los datos han cambiado
    notifyListeners();
  }

  // Obtener el balance total (ingresos - gastos)
  double get totalBalance {
    double balance = 0;
    for (var transaction in _transactions) {
      if (transaction.type == TransactionType.income) {
        balance += transaction.amount;
      } else {
        balance -= transaction.amount;
      }
    }
    return balance;
  }

  // Obtener total de ingresos
  double get totalIncome {
    return _transactions
        .where((t) => t.type == TransactionType.income)
        .fold(0, (sum, t) => sum + t.amount);
  }

  // Obtener total de gastos
  double get totalExpenses {
    return _transactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0, (sum, t) => sum + t.amount);
  }

  // Obtener transacciones de este mes
  List<Transaction> get thisMonthTransactions {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    return _transactions.where((transaction) {
      return transaction.date.isAfter(firstDayOfMonth.subtract(Duration(days: 1))) &&
          transaction.date.isBefore(lastDayOfMonth.add(Duration(days: 1)));
    }).toList();
  }

  // Obtener gastos por categoría del mes actual
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

  // Limpiar todas las transacciones (útil para desarrollo)
  Future<void> clearAllTransactions() async {
    _transactions.clear();
    await _saveTransactions();
    notifyListeners();
  }

  // Forzar actualización manual
  void forceUpdate() {
    notifyListeners();
  }

  // Actualizar una transacción existente
  Future<void> updateTransaction(Transaction updatedTransaction) async {
    final index = _transactions.indexWhere((t) => t.id == updatedTransaction.id);
    if (index != -1) {
      _transactions[index] = updatedTransaction;
      // Mantener ordenado por fecha
      _transactions.sort((a, b) => b.date.compareTo(a.date));
      await _saveTransactions();
      notifyListeners();
    }
  }

  /// Reasigna todas las transacciones de una categoría personalizada a "Otros"
  /// Se usa cuando se elimina una categoría personalizada
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