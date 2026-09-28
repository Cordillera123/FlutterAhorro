import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ahorro_app/models/backup_data.dart';
import 'package:ahorro_app/services/backup_service.dart';

/// Backup válido mínimo con un registro de cada entidad, usado como base
/// para las pruebas. Los índices de enum elegidos son válidos en sus
/// respectivos modelos (verificado contra las definiciones actuales).
Map<String, dynamic> _validBackupJson() {
  final now = DateTime.now().toIso8601String();
  return {
    'formatVersion': 1,
    'exportedAt': now,
    'appVersion': '1.0.0',
    'data': {
      'accounts': [
        {
          'id': 'account_default',
          'name': 'Cuenta Principal',
          'type': 0,
          'emoji': '🏦',
          'color': 0xFF3B82F6,
          'isDefault': true,
          'createdAt': now,
          'updatedAt': null,
          'initialBalance': 0.0,
        },
      ],
      'activeAccountId': 'account_default',
      'transactions': [
        {
          'id': 'tx1',
          'amount': 100.0,
          'type': 'expense',
          'description': 'Café',
          'date': now,
          'expenseCategory': 'food',
          'incomeCategory': null,
          'customCategoryId': null,
          'customCategoryName': null,
          'customCategoryEmoji': null,
          'accountId': 'account_default',
        },
      ],
      'budgets': [
        {
          'id': 'b1',
          'name': 'Comida',
          'amount': 300.0,
          'period': 1,
          'category': 1,
          'customCategoryId': null,
          'customCategoryName': null,
          'customCategoryEmoji': null,
          'startDate': now,
          'endDate': now,
          'isActive': true,
          'alertsEnabled': true,
          'alertThreshold': 0.8,
          'createdAt': now,
          'updatedAt': null,
          'lastResetDate': null,
          'accountId': 'account_default',
        },
      ],
      'financialGoals': [
        {
          'id': 'g1',
          'name': 'Vacaciones',
          'description': 'Viaje',
          'targetAmount': 1000.0,
          'currentAmount': 0.0,
          'startDate': now,
          'targetDate': now,
          'type': 0,
          'priority': 1,
          'status': 0,
          'emoji': '🎯',
          'autoSaveAmount': 0.0,
          'autoSave': false,
          'autoSaveFrequency': 2,
          'createdAt': now,
          'updatedAt': null,
          'completedAt': null,
          'accountId': 'account_default',
        },
      ],
      'goalContributions': <Map<String, dynamic>>[],
      'customCategories': [
        {
          'id': 'custom_1',
          'name': 'Mascotas',
          'emoji': '🐶',
          'createdAt': now,
          'updatedAt': null,
          'accountId': 'account_default',
        },
      ],
      'recurringExpenses': [
        {
          'id': 'r1',
          'name': 'Netflix',
          'description': 'Suscripción',
          'amount': 15.0,
          'category': 'entertainment',
          'frequency': 'monthly',
          'customDays': null,
          'weekDays': null,
          'monthlyDay': 5,
          'startDate': now,
          'endDate': null,
          'isActive': true,
          'createdAt': now,
          'lastProcessed': null,
          'accountId': 'account_default',
        },
      ],
    },
  };
}

void main() {
  group('BackupService.validateAndParse', () {
    final service = BackupService();

    test('acepta un backup válido y parsea todas las entidades', () {
      final parsed = service.validateAndParse(json.encode(_validBackupJson()));

      expect(parsed.accounts.length, 1);
      expect(parsed.transactions.length, 1);
      expect(parsed.budgets.length, 1);
      expect(parsed.financialGoals.length, 1);
      expect(parsed.goalContributions.length, 0);
      expect(parsed.customCategories.length, 1);
      expect(parsed.recurringExpenses.length, 1);
      expect(parsed.activeAccountId, 'account_default');
      expect(parsed.totalRecords, 6);
    });

    test('rechaza un archivo que no es JSON', () {
      expect(
        () => service.validateAndParse('esto no es json'),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('rechaza un backup sin el campo data', () {
      final broken = {
        'formatVersion': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
      };
      expect(
        () => service.validateAndParse(json.encode(broken)),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('rechaza un formatVersion más nuevo que el soportado', () {
      final future = _validBackupJson();
      future['formatVersion'] = BackupData.currentFormatVersion + 1;
      expect(
        () => service.validateAndParse(json.encode(future)),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('rechaza un backup sin ninguna cuenta', () {
      final noAccounts = _validBackupJson();
      (noAccounts['data'] as Map<String, dynamic>)['accounts'] = <Map<String, dynamic>>[];
      expect(
        () => service.validateAndParse(json.encode(noAccounts)),
        throwsA(isA<BackupValidationException>()),
      );
    });

    test('rechaza una transacción corrupta sin tocar el resto del archivo', () {
      final corrupted = _validBackupJson();
      final data = corrupted['data'] as Map<String, dynamic>;
      final transactions = List<Map<String, dynamic>>.from(data['transactions'] as List);
      transactions[0].remove('id'); // campo requerido por Transaction.fromJson
      data['transactions'] = transactions;

      expect(
        () => service.validateAndParse(json.encode(corrupted)),
        throwsA(isA<BackupValidationException>()),
      );
    });
  });

  group('BackupData', () {
    test('round-trip toJson/fromJson preserva metadata y listas', () {
      final original = _validBackupJson();
      final envelope = BackupData.fromJson(original);
      final reencoded = BackupData.fromJson(
        json.decode(json.encode(envelope.toJson())) as Map<String, dynamic>,
      );

      expect(reencoded.formatVersion, envelope.formatVersion);
      expect(reencoded.appVersion, envelope.appVersion);
      expect(reencoded.accounts.length, envelope.accounts.length);
      expect(reencoded.transactions.length, envelope.transactions.length);
      expect(reencoded.activeAccountId, envelope.activeAccountId);
    });
  });
}
