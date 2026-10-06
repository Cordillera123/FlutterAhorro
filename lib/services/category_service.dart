import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_category.dart';
import '../models/transaction.dart';
import '../utils/app_log.dart';
import 'transaction_service.dart';
import 'budget_service.dart';
import 'account_service.dart';

/// Servicio para gestionar categorías personalizadas de gastos.
/// Usa patrón Singleton y persiste en SharedPreferences.
class CategoryService extends ChangeNotifier {
  static const String _categoriesKey = 'custom_categories';

  // Singleton
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  final AccountService _accountService = AccountService();

  // Lista en memoria de TODAS las categorías personalizadas
  List<CustomCategory> _customCategories = [];

  // Getter para categorías personalizadas de la cuenta activa
  List<CustomCategory> get customCategories => List.unmodifiable(
    _customCategories
        .where((c) => c.accountId == _accountService.activeAccountId)
        .toList(),
  );

  // Getter para TODAS las categorías personalizadas (sin filtro)
  List<CustomCategory> get allCustomCategories =>
      List.unmodifiable(_customCategories);

  /// Retorna todas las categorías: sistema + personalizadas
  /// Formato: List<Map> con {id, name, emoji, isSystem}
  List<Map<String, dynamic>> getAllExpenseCategories() {
    final List<Map<String, dynamic>> allCategories = [];

    // 1. Agregar categorías del sistema
    for (final category in ExpenseCategory.values) {
      allCategories.add({
        'id': category.name, // 'transport', 'food', etc.
        'name': _getSystemCategoryName(category),
        'emoji': _getSystemCategoryEmoji(category),
        'isSystem': true,
        'systemCategory': category,
      });
    }

    // 2. Agregar categorías personalizadas de la cuenta activa
    for (final custom in customCategories) {
      allCategories.add({
        'id': custom.id,
        'name': custom.name,
        'emoji': custom.emoji,
        'isSystem': false,
        'customCategory': custom,
      });
    }

    return allCategories;
  }

  /// Obtiene nombre de categoría del sistema
  String _getSystemCategoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.transport:
        return 'Transporte';
      case ExpenseCategory.food:
        return 'Alimentación';
      case ExpenseCategory.utilities:
        return 'Servicios Básicos';
      case ExpenseCategory.health:
        return 'Salud';
      case ExpenseCategory.education:
        return 'Educación';
      case ExpenseCategory.entertainment:
        return 'Entretenimiento';
      case ExpenseCategory.clothing:
        return 'Ropa y Calzado';
      case ExpenseCategory.home:
        return 'Hogar y Muebles';
      case ExpenseCategory.technology:
        return 'Tecnología';
      case ExpenseCategory.savings:
        return 'Ahorros e Inversión';
      case ExpenseCategory.gifts:
        return 'Regalos y Donaciones';
      case ExpenseCategory.other:
        return 'Otros';
    }
  }

  /// Obtiene emoji de categoría del sistema
  String _getSystemCategoryEmoji(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.transport:
        return '🚗';
      case ExpenseCategory.food:
        return '🍕';
      case ExpenseCategory.utilities:
        return '💡';
      case ExpenseCategory.health:
        return '🏥';
      case ExpenseCategory.education:
        return '📚';
      case ExpenseCategory.entertainment:
        return '🎬';
      case ExpenseCategory.clothing:
        return '👕';
      case ExpenseCategory.home:
        return '🏠';
      case ExpenseCategory.technology:
        return '📱';
      case ExpenseCategory.savings:
        return '💰';
      case ExpenseCategory.gifts:
        return '🎁';
      case ExpenseCategory.other:
        return '📦';
    }
  }

  /// Obtiene nombre y emoji de cualquier categoría por su ID
  Map<String, String> getCategoryInfo(
    String? categoryId,
    ExpenseCategory? systemCategory,
  ) {
    // Si es categoría del sistema
    if (systemCategory != null) {
      return {
        'name': _getSystemCategoryName(systemCategory),
        'emoji': _getSystemCategoryEmoji(systemCategory),
      };
    }

    // Buscar en categorías personalizadas
    if (categoryId != null && categoryId.startsWith('custom_')) {
      final custom = _customCategories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => CustomCategory(
          id: 'deleted',
          name: 'Otros',
          emoji: '📦',
          createdAt: DateTime.now(),
        ),
      );
      return {'name': custom.name, 'emoji': custom.emoji};
    }

    // Fallback a "Otros"
    return {'name': 'Otros', 'emoji': '📦'};
  }

  /// Cargar categorías desde SharedPreferences
  Future<void> loadCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = prefs.getString(_categoriesKey);

      if (categoriesJson != null) {
        final List<dynamic> categoriesList = json.decode(categoriesJson);
        _customCategories = categoriesList
            .map((json) => CustomCategory.fromJson(json))
            .toList();

        // Ordenar por fecha de creación (más recientes primero)
        _customCategories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } else {
        _customCategories = [];
      }

      notifyListeners();
    } catch (e) {
      AppLog.error('Error cargando categorías personalizadas', e);
      _customCategories = [];
      notifyListeners();
    }
  }

  /// Guardar categorías en SharedPreferences
  Future<void> _saveCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categoriesJson = json.encode(
        _customCategories.map((c) => c.toJson()).toList(),
      );
      await prefs.setString(_categoriesKey, categoriesJson);
    } catch (e) {
      AppLog.error('Error guardando categorías personalizadas', e);
    }
  }

  /// Reemplaza TODAS las categorías personalizadas (usado al restaurar una
  /// copia de seguridad). El llamador es responsable de validar los datos
  /// antes.
  Future<void> replaceAllForRestore(List<CustomCategory> categories) async {
    _customCategories = List.of(categories)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveCategories();
    notifyListeners();
  }

  /// Agregar nueva categoría personalizada
  Future<CustomCategory> addCategory({
    required String name,
    required String emoji,
  }) async {
    // Se compara sin espacios sobrantes: "Mascotas " y "Mascotas" son la
    // misma categoría (antes se creaban dos con el mismo nombre).
    name = name.trim();

    // Validar que no exista una categoría con el mismo nombre en la cuenta activa
    final nameExists = customCategories.any(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (nameExists) {
      throw Exception('Ya existe una categoría con el nombre "$name"');
    }

    // Validar que no coincida con categorías del sistema
    final systemNames = ExpenseCategory.values
        .map((c) => _getSystemCategoryName(c).toLowerCase())
        .toList();
    if (systemNames.contains(name.toLowerCase())) {
      throw Exception('No puedes usar el nombre de una categoría del sistema');
    }

    final newCategory = CustomCategory(
      id: CustomCategory.generateId(
        existingIds: {for (final c in _customCategories) c.id},
      ),
      name: name.trim(),
      emoji: emoji,
      createdAt: DateTime.now(),
      accountId: _accountService.activeAccountId,
    );

    _customCategories.insert(0, newCategory);
    await _saveCategories();
    notifyListeners();

    return newCategory;
  }

  /// Actualizar categoría personalizada existente
  Future<void> updateCategory({
    required String id,
    required String name,
    required String emoji,
  }) async {
    final index = _customCategories.indexWhere((c) => c.id == id);
    if (index == -1) {
      throw Exception('Categoría no encontrada');
    }
    name = name.trim();

    // Validar que no exista otra categoría con el mismo nombre en la cuenta activa
    final nameExists = customCategories.any(
      (c) => c.id != id && c.name.toLowerCase() == name.toLowerCase(),
    );
    if (nameExists) {
      throw Exception('Ya existe una categoría con el nombre "$name"');
    }

    _customCategories[index] = _customCategories[index].copyWith(
      name: name.trim(),
      emoji: emoji,
      updatedAt: DateTime.now(),
    );

    await _saveCategories();
    notifyListeners();
  }

  /// Verificar si una categoría tiene presupuestos asociados
  Future<bool> categoryHasBudgets(String categoryId) async {
    final budgetService = BudgetService();
    await budgetService.loadBudgets();

    return budgetService.budgets.any((b) => b.customCategoryId == categoryId);
  }

  /// Obtener presupuestos asociados a una categoría
  Future<List<dynamic>> getBudgetsForCategory(String categoryId) async {
    final budgetService = BudgetService();
    await budgetService.loadBudgets();

    return budgetService.budgets
        .where((b) => b.customCategoryId == categoryId)
        .toList();
  }

  /// Verificar si una categoría tiene transacciones asociadas
  Future<bool> categoryHasTransactions(String categoryId) async {
    final transactionService = TransactionService();
    await transactionService.loadTransactions();

    return transactionService.transactions.any(
      (t) => t.customCategoryId == categoryId,
    );
  }

  /// Eliminar categoría personalizada
  /// - Si hay presupuestos: los elimina
  /// - Si hay transacciones: las reasigna a "Otros"
  Future<DeleteCategoryResult> deleteCategory(
    String categoryId, {
    bool deleteBudgets = false,
  }) async {
    final index = _customCategories.indexWhere((c) => c.id == categoryId);
    if (index == -1) {
      throw Exception('Categoría no encontrada');
    }

    final category = _customCategories[index];
    final result = DeleteCategoryResult(categoryName: category.name);

    // 1. Verificar presupuestos
    final budgetService = BudgetService();
    await budgetService.loadBudgets();
    final budgetsWithCategory = budgetService.budgets
        .where((b) => b.customCategoryId == categoryId)
        .toList();

    if (budgetsWithCategory.isNotEmpty && !deleteBudgets) {
      throw CategoryHasBudgetsException(
        'La categoría tiene ${budgetsWithCategory.length} presupuesto(s) asociado(s)',
        budgetsWithCategory.length,
      );
    }

    // 2. Eliminar presupuestos si se autorizó
    if (budgetsWithCategory.isNotEmpty && deleteBudgets) {
      for (final budget in budgetsWithCategory) {
        await budgetService.deleteBudget(budget.id!);
        result.deletedBudgets++;
      }
    }

    // 3. Reasignar transacciones a "Otros"
    final transactionService = TransactionService();
    await transactionService.loadTransactions();
    final transactionsWithCategory = transactionService.transactions
        .where((t) => t.customCategoryId == categoryId)
        .toList();

    if (transactionsWithCategory.isNotEmpty) {
      await transactionService.reassignCategoryToOther(categoryId);
      result.reassignedTransactions = transactionsWithCategory.length;
    }

    // 4. Eliminar la categoría
    _customCategories.removeAt(index);
    await _saveCategories();
    notifyListeners();

    return result;
  }

  /// Buscar categoría personalizada por ID
  CustomCategory? getCategoryById(String id) {
    try {
      return _customCategories.firstWhere((c) => c.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Verificar si un ID corresponde a categoría personalizada
  bool isCustomCategory(String? categoryId) {
    return categoryId != null && categoryId.startsWith('custom_');
  }
}

/// Resultado de eliminar una categoría
class DeleteCategoryResult {
  final String categoryName;
  int deletedBudgets = 0;
  int reassignedTransactions = 0;

  DeleteCategoryResult({required this.categoryName});

  String get summary {
    final parts = <String>[];
    if (deletedBudgets > 0) {
      parts.add('$deletedBudgets presupuesto(s) eliminado(s)');
    }
    if (reassignedTransactions > 0) {
      parts.add(
        '$reassignedTransactions transacción(es) reasignada(s) a "Otros"',
      );
    }
    if (parts.isEmpty) {
      return 'Categoría "$categoryName" eliminada';
    }
    return 'Categoría "$categoryName" eliminada: ${parts.join(', ')}';
  }
}

/// Excepción cuando la categoría tiene presupuestos
class CategoryHasBudgetsException implements Exception {
  final String message;
  final int budgetCount;

  CategoryHasBudgetsException(this.message, this.budgetCount);

  @override
  String toString() => message;
}
