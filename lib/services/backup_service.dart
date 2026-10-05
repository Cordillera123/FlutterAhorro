import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/backup_data.dart';
import '../models/budget.dart';
import '../models/custom_category.dart';
import '../models/financial_goal.dart';
import '../models/recurring_expense.dart';
import '../models/transaction.dart';
import 'account_service.dart';
import 'budget_service.dart';
import 'category_service.dart';
import 'goal_service.dart';
import 'recurring_expense_service.dart';
import 'transaction_service.dart';
import '../utils/app_info.dart';

/// Versión de la app mostrada en la metadata del backup. Es solo
/// informativa (no participa en la validación) — actualizar junto a
/// `pubspec.yaml` en cada release.
const String kBackupAppVersion = '1.0.0';

/// Contenedor de los datos de un backup ya parseados y validados como
/// modelos concretos, listos para restaurar.
class ParsedBackup {
  final DateTime exportedAt;
  final String appVersion;
  final List<Account> accounts;
  final String activeAccountId;
  final List<Transaction> transactions;
  final List<Budget> budgets;
  final List<FinancialGoal> financialGoals;
  final List<GoalContribution> goalContributions;
  final List<CustomCategory> customCategories;
  final List<RecurringExpense> recurringExpenses;

  ParsedBackup({
    required this.exportedAt,
    required this.appVersion,
    required this.accounts,
    required this.activeAccountId,
    required this.transactions,
    required this.budgets,
    required this.financialGoals,
    required this.goalContributions,
    required this.customCategories,
    required this.recurringExpenses,
  });

  int get totalRecords =>
      accounts.length +
      transactions.length +
      budgets.length +
      financialGoals.length +
      goalContributions.length +
      customCategories.length +
      recurringExpenses.length;
}

/// Se lanza cuando un archivo de backup no es válido o no se puede
/// restaurar. El mensaje ya está en español, listo para mostrar al usuario.
class BackupValidationException implements Exception {
  final String message;
  const BackupValidationException(this.message);

  @override
  String toString() => message;
}

/// Servicio orquestador de copias de seguridad.
///
/// Sigue el patrón Singleton del resto de servicios. Responsabilidades:
/// 1. Recopilar los datos en memoria de todos los servicios y armar un
///    [BackupData].
/// 2. Guardarlo en el teléfono vía el diálogo nativo "Guardar en…" (mismo
///    flujo que [ExportService] para reportes).
/// 3. Validar y parsear un archivo de backup ANTES de tocar cualquier dato
///    existente — si algo falla, no se escribe nada.
/// 4. Aplicar un backup ya validado, reemplazando los datos de cada
///    servicio.
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final AccountService _accountService = AccountService();
  final TransactionService _transactionService = TransactionService();
  final BudgetService _budgetService = BudgetService();
  final GoalService _goalService = GoalService();
  final CategoryService _categoryService = CategoryService();
  final RecurringExpenseService _recurringExpenseService =
      RecurringExpenseService();

  bool _isBusy = false;

  /// `true` mientras hay una creación o restauración en curso.
  bool get isBusy => _isBusy;

  // ─── Crear y guardar ───────────────────────────────────────────────────

  /// Genera el archivo de backup con TODOS los datos (todas las cuentas,
  /// sin filtrar) y abre el diálogo nativo "Guardar en…" para que el
  /// usuario lo guarde en su teléfono (normalmente Descargas).
  ///
  /// Devuelve la ruta donde se guardó, o `null` si el usuario canceló el
  /// diálogo o ya había una operación en curso.
  Future<String?> createAndSaveBackup() async {
    if (_isBusy) return null;
    _isBusy = true;

    try {
      final backup = _buildBackupData();
      final jsonString = const JsonEncoder.withIndent(
        '  ',
      ).convert(backup.toJson());

      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Guardar copia de seguridad',
        fileName: _buildFileName(),
        bytes: Uint8List.fromList(utf8.encode(jsonString)),
      );
      if (savedPath != null) debugPrint('✅ Backup guardado en: $savedPath');

      return savedPath;
    } catch (e) {
      debugPrint('❌ BackupService.createAndSaveBackup error: $e');
      rethrow;
    } finally {
      _isBusy = false;
    }
  }

  BackupData _buildBackupData() {
    return BackupData(
      formatVersion: BackupData.currentFormatVersion,
      exportedAt: DateTime.now(),
      appVersion: kBackupAppVersion,
      accounts: _accountService.accounts.map((a) => a.toJson()).toList(),
      activeAccountId: _accountService.activeAccountId,
      transactions: _transactionService.allTransactions
          .map((t) => t.toJson())
          .toList(),
      budgets: _budgetService.allBudgets.map((b) => b.toJson()).toList(),
      financialGoals: _goalService.allGoals.map((g) => g.toJson()).toList(),
      goalContributions: _goalService.allContributions
          .map((c) => c.toJson())
          .toList(),
      customCategories: _categoryService.allCustomCategories
          .map((c) => c.toJson())
          .toList(),
      recurringExpenses: _recurringExpenseService.allRecurringExpenses
          .map((e) => e.toJson())
          .toList(),
    );
  }

  static String _buildFileName() {
    final now = DateTime.now();
    return '${AppInfo.name}_Backup_'
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}.json';
  }

  // ─── Validar (sin escribir nada) ───────────────────────────────────────

  /// Parsea y valida por completo un archivo de backup: estructura del
  /// sobre y CADA entidad dentro de él. Si cualquier parte falla, lanza
  /// [BackupValidationException] y no modifica ningún dato existente.
  ParsedBackup validateAndParse(String jsonString) {
    Map<String, dynamic> rawJson;
    try {
      final decoded = json.decode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('root no es un objeto JSON');
      }
      rawJson = decoded;
    } catch (_) {
      throw const BackupValidationException(
        'El archivo seleccionado no es un JSON válido de copia de '
        'seguridad de ${AppInfo.name}.',
      );
    }

    late final BackupData envelope;
    try {
      envelope = BackupData.fromJson(rawJson);
    } on FormatException catch (e) {
      throw BackupValidationException(e.message);
    }

    try {
      final accounts = envelope.accounts
          .map((j) => Account.fromJson(j))
          .toList();
      final transactions = envelope.transactions
          .map((j) => Transaction.fromJson(j))
          .toList();
      final budgets = envelope.budgets.map((j) => Budget.fromJson(j)).toList();
      final goals = envelope.financialGoals
          .map((j) => FinancialGoal.fromJson(j))
          .toList();
      final contributions = envelope.goalContributions
          .map((j) => GoalContribution.fromJson(j))
          .toList();
      final categories = envelope.customCategories
          .map((j) => CustomCategory.fromJson(j))
          .toList();
      final recurringExpenses = envelope.recurringExpenses
          .map((j) => RecurringExpense.fromJson(j))
          .toList();

      if (accounts.isEmpty) {
        throw const BackupValidationException(
          'La copia de seguridad no contiene ninguna cuenta. El archivo '
          'parece estar corrupto o incompleto.',
        );
      }

      return ParsedBackup(
        exportedAt: envelope.exportedAt,
        appVersion: envelope.appVersion,
        accounts: accounts,
        activeAccountId: envelope.activeAccountId,
        transactions: transactions,
        budgets: budgets,
        financialGoals: goals,
        goalContributions: contributions,
        customCategories: categories,
        recurringExpenses: recurringExpenses,
      );
    } on BackupValidationException {
      rethrow;
    } catch (e) {
      throw BackupValidationException(
        'El archivo contiene datos con un formato inesperado y no se '
        'puede restaurar de forma segura. Detalle: $e',
      );
    }
  }

  // ─── Restaurar (solo tras validar) ─────────────────────────────────────

  /// Reemplaza TODOS los datos actuales por los del [backup] ya validado.
  /// No debe llamarse directamente con datos sin pasar por
  /// [validateAndParse] primero.
  Future<void> restoreParsedBackup(ParsedBackup backup) async {
    if (_isBusy) {
      throw const BackupValidationException(
        'Ya hay una operación de copia de seguridad en curso.',
      );
    }
    _isBusy = true;
    try {
      await _accountService.replaceAllForRestore(
        backup.accounts,
        backup.activeAccountId,
      );
      await _transactionService.replaceAllForRestore(backup.transactions);
      await _budgetService.replaceAllForRestore(backup.budgets);
      await _goalService.replaceAllForRestore(
        backup.financialGoals,
        backup.goalContributions,
      );
      await _categoryService.replaceAllForRestore(backup.customCategories);
      await _recurringExpenseService.replaceAllForRestore(
        backup.recurringExpenses,
      );
    } finally {
      _isBusy = false;
    }
  }
}
