import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import 'transaction_service.dart';
import 'budget_service.dart';
import 'goal_service.dart';

/// Servicio para gestionar las cuentas financieras del usuario.
/// Usa patrón Singleton y persiste en SharedPreferences.
/// Extiende ChangeNotifier para notificar a las pantallas cuando cambie la cuenta activa.
class AccountService extends ChangeNotifier {
  static const String _accountsKey = 'accounts';
  static const String _activeAccountKey = 'active_account_id';
  static const String _dataMigratedKey = 'data_migrated_to_accounts';
  static const int _minAccounts = 1;
  static const int _maxAccounts = 10;

  // Singleton
  static final AccountService _instance = AccountService._internal();
  factory AccountService() => _instance;
  AccountService._internal();

  // Lista en memoria de cuentas
  List<Account> _accounts = [];
  String _activeAccountId = Account.defaultAccountId;

  // Getters
  List<Account> get accounts => List.unmodifiable(_accounts);
  String get activeAccountId => _activeAccountId;
  int get accountCount => _accounts.length;
  bool get canCreateMoreAccounts => _accounts.length < _maxAccounts;
  int get remainingAccountSlots => _maxAccounts - _accounts.length;

  /// Obtiene la cuenta activa actual
  Account get activeAccount {
    try {
      return _accounts.firstWhere((a) => a.id == _activeAccountId);
    } catch (e) {
      // Si no se encuentra, retornar la cuenta por defecto
      return _accounts.isNotEmpty ? _accounts.first : Account.defaultAccount();
    }
  }

  /// Obtiene la cuenta por defecto (principal)
  Account get defaultAccount {
    try {
      return _accounts.firstWhere((a) => a.isDefault);
    } catch (e) {
      return _accounts.isNotEmpty ? _accounts.first : Account.defaultAccount();
    }
  }

  /// Verifica si los datos ya fueron migrados al sistema multi-cuenta
  Future<bool> isDataMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dataMigratedKey) ?? false;
  }

  /// Cargar cuentas desde SharedPreferences
  Future<void> loadAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString(_accountsKey);

      if (accountsJson != null) {
        final List<dynamic> accountsList = json.decode(accountsJson);
        _accounts = accountsList
            .map((json) => Account.fromJson(json))
            .toList();

        // Ordenar: cuenta por defecto primero, luego por fecha de creación
        _accounts.sort((a, b) {
          if (a.isDefault && !b.isDefault) return -1;
          if (!a.isDefault && b.isDefault) return 1;
          return a.createdAt.compareTo(b.createdAt);
        });
      }

      // Si no hay cuentas, crear la cuenta por defecto
      if (_accounts.isEmpty) {
        await _createDefaultAccount();
      }

      // Cargar cuenta activa
      _activeAccountId = prefs.getString(_activeAccountKey) ?? Account.defaultAccountId;

      // Verificar que la cuenta activa existe
      final activeExists = _accounts.any((a) => a.id == _activeAccountId);
      if (!activeExists) {
        _activeAccountId = _accounts.first.id;
        await prefs.setString(_activeAccountKey, _activeAccountId);
      }

      print('=== CUENTAS CARGADAS ===');
      print('Total cuentas: ${_accounts.length}');
      print('Cuenta activa: ${activeAccount.name} ($_activeAccountId)');
      print('========================');

      notifyListeners();
    } catch (e) {
      print('Error cargando cuentas: $e');
      _accounts = [];
      await _createDefaultAccount();
      notifyListeners();
    }
  }

  /// Crear la cuenta principal por defecto
  Future<void> _createDefaultAccount() async {
    final defaultAcc = Account.defaultAccount();
    _accounts = [defaultAcc];
    _activeAccountId = defaultAcc.id;
    await _saveAccounts();
    await _saveActiveAccountId();
  }

  /// Guardar cuentas en SharedPreferences
  Future<void> _saveAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = json.encode(
        _accounts.map((a) => a.toJson()).toList(),
      );
      await prefs.setString(_accountsKey, accountsJson);
    } catch (e) {
      print('Error guardando cuentas: $e');
    }
  }

  /// Guardar ID de cuenta activa
  Future<void> _saveActiveAccountId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeAccountKey, _activeAccountId);
    } catch (e) {
      print('Error guardando cuenta activa: $e');
    }
  }

  /// Cambiar la cuenta activa
  Future<void> setActiveAccount(String accountId) async {
    final accountExists = _accounts.any((a) => a.id == accountId);
    if (!accountExists) {
      throw Exception('Cuenta no encontrada');
    }

    _activeAccountId = accountId;
    await _saveActiveAccountId();

    print('🔄 Cuenta activa cambiada a: ${activeAccount.name}');
    notifyListeners();
  }

  /// Agregar nueva cuenta
  Future<Account> addAccount({
    required String name,
    required AccountType type,
    String? emoji,
    Color? color,
  }) async {
    // Validar límite máximo
    if (!canCreateMoreAccounts) {
      throw Exception('Has alcanzado el límite máximo de $_maxAccounts cuentas');
    }

    // Validar que no exista otra con el mismo nombre
    final nameExists = _accounts.any(
          (a) => a.name.toLowerCase() == name.toLowerCase(),
    );
    if (nameExists) {
      throw Exception('Ya existe una cuenta con el nombre "$name"');
    }

    final newAccount = Account(
      id: Account.generateId(),
      name: name.trim(),
      type: type,
      emoji: emoji ?? Account.defaultEmojiForType(type),
      color: color ?? Account.defaultColorForType(type),
      isDefault: false,
      createdAt: DateTime.now(),
    );

    _accounts.add(newAccount);
    await _saveAccounts();
    notifyListeners();

    print('✅ Cuenta creada: ${newAccount.name}');
    return newAccount;
  }

  /// Actualizar cuenta existente
  Future<void> updateAccount({
    required String id,
    required String name,
    required AccountType type,
    required String emoji,
    required Color color,
  }) async {
    final index = _accounts.indexWhere((a) => a.id == id);
    if (index == -1) {
      throw Exception('Cuenta no encontrada');
    }

    // Validar que no exista otra con el mismo nombre
    final nameExists = _accounts.any(
          (a) => a.id != id && a.name.toLowerCase() == name.toLowerCase(),
    );
    if (nameExists) {
      throw Exception('Ya existe una cuenta con el nombre "$name"');
    }

    _accounts[index] = _accounts[index].copyWith(
      name: name.trim(),
      type: type,
      emoji: emoji,
      color: color,
      updatedAt: DateTime.now(),
    );

    await _saveAccounts();
    notifyListeners();
  }

  /// Eliminar cuenta (no se puede eliminar la cuenta por defecto)
  Future<void> deleteAccount(String accountId) async {
    final account = _accounts.firstWhere(
          (a) => a.id == accountId,
      orElse: () => throw Exception('Cuenta no encontrada'),
    );

    if (account.isDefault) {
      throw Exception('No se puede eliminar la cuenta principal');
    }

    if (_accounts.length <= _minAccounts) {
      throw Exception('Debe haber al menos $_minAccounts cuenta');
    }

    _accounts.removeWhere((a) => a.id == accountId);

    // Si se eliminó la cuenta activa, cambiar a la cuenta por defecto
    if (_activeAccountId == accountId) {
      _activeAccountId = defaultAccount.id;
      await _saveActiveAccountId();
    }

    await _saveAccounts();

    // Eliminar también las transacciones, presupuestos y metas de la cuenta,
    // tal como se le advierte al usuario en el diálogo de confirmación.
    await TransactionService().clearTransactionsForAccount(accountId);
    await BudgetService().clearBudgetsForAccount(accountId);
    await GoalService().clearGoalsForAccount(accountId);

    notifyListeners();

    print('🗑️ Cuenta eliminada: ${account.name}');
  }

  /// Actualiza el balance inicial de una cuenta.
  /// Persiste el cambio en SharedPreferences y notifica listeners.
  Future<void> updateInitialBalance(String accountId, double balance) async {
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index == -1) throw Exception('Cuenta no encontrada');

    _accounts[index] = _accounts[index].copyWith(
      initialBalance: balance,
      updatedAt: DateTime.now(),
    );
    await _saveAccounts();
    notifyListeners();
  }

  /// Obtener cuenta por ID
  Account? getAccountById(String id) {
    try {
      return _accounts.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Resuelve un accountId válido. Si está vacío o no existe en ninguna cuenta,
  /// usa la cuenta activa (evita que registros queden ocultos tras el filtro).
  String resolveAccountId(String? accountId) {
    final id = accountId?.trim() ?? '';
    if (id.isNotEmpty && _accounts.any((a) => a.id == id)) {
      return id;
    }
    return activeAccountId;
  }

  /// Marcar migración de datos como completada
  Future<void> markDataMigrated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dataMigratedKey, true);
    print('✅ Migración de datos marcada como completada');
  }

  /// Migrar datos existentes a la cuenta principal por defecto.
  /// Agrega accountId a transacciones, presupuestos, metas,
  /// gastos recurrentes y categorías que no lo tengan.
  Future<void> migrateExistingData() async {
    final migrated = await isDataMigrated();
    if (migrated) {
      print('✓ Datos ya migrados previamente');
      return;
    }

    print('=== MIGRANDO DATOS A SISTEMA MULTI-CUENTA ===');

    final prefs = await SharedPreferences.getInstance();
    final defaultId = Account.defaultAccountId;

    // Migrar transacciones
    await _migrateJsonList(prefs, 'transactions', defaultId);

    // Migrar presupuestos
    await _migrateJsonList(prefs, 'budgets', defaultId);

    // Migrar metas
    await _migrateJsonList(prefs, 'financial_goals', defaultId);

    // Migrar contribuciones de metas
    await _migrateJsonList(prefs, 'goal_contributions', defaultId);

    // Migrar gastos recurrentes
    await _migrateJsonList(prefs, 'recurring_expenses', defaultId);

    // Migrar categorías personalizadas
    await _migrateJsonList(prefs, 'custom_categories', defaultId);

    await markDataMigrated();
    print('=== MIGRACIÓN COMPLETADA ===');
  }

  /// Migra una lista JSON agregando accountId a cada elemento que no lo tenga
  Future<void> _migrateJsonList(SharedPreferences prefs, String key, String defaultAccountId) async {
    try {
      final jsonStr = prefs.getString(key);
      if (jsonStr == null) {
        print('  ⏭️ $key: sin datos');
        return;
      }

      final List<dynamic> items = json.decode(jsonStr);
      int migrated = 0;

      for (int i = 0; i < items.length; i++) {
        if (items[i] is Map<String, dynamic> && items[i]['accountId'] == null) {
          items[i]['accountId'] = defaultAccountId;
          migrated++;
        }
      }

      if (migrated > 0) {
        await prefs.setString(key, json.encode(items));
        print('  ✅ $key: $migrated elementos migrados');
      } else {
        print('  ✓ $key: ya migrados (${items.length} elementos)');
      }
    } catch (e) {
      print('  ❌ Error migrando $key: $e');
    }
  }
}
