import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahorro_app/models/account.dart';
import 'package:ahorro_app/models/financial_goal.dart';
import 'package:ahorro_app/models/transaction.dart';
import 'package:ahorro_app/services/account_service.dart';
import 'package:ahorro_app/services/goal_service.dart';
import 'package:ahorro_app/services/stats_service.dart';
import 'package:ahorro_app/services/transaction_service.dart';

/// Aportes a metas ↔ transacciones del historial, dato por dato.
///
/// Un aporte se guarda como gasto "Aporte a …" (Ahorros e Inversión) y como
/// aporte de la meta. La transacción es la fuente de verdad: editarla o
/// eliminarla desde el historial debe dejar la meta, su progreso, el balance
/// y lo persistido exactamente igual que lo que muestra el historial.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final accounts = AccountService();
  final transactions = TransactionService();
  final goals = GoalService();

  // Deja correr el guardado asíncrono que dispara la sincronización.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  /// Simula cerrar y volver a abrir la app: todo se vuelve a leer de disco.
  Future<void> restart() async {
    await settle();
    await accounts.loadAccounts();
    await transactions.loadTransactions();
    await goals.loadGoals();
  }

  Future<FinancialGoal> createGoal({
    String name = 'Moto',
    double target = 1000,
  }) async {
    final now = DateTime.now();
    await goals.addGoal(
      FinancialGoal(
        name: name,
        description: '',
        targetAmount: target,
        startDate: now,
        targetDate: DateTime(now.year + 1, now.month, now.day),
        type: GoalType.purchase,
        createdAt: now,
        accountId: accounts.activeAccountId,
      ),
    );
    // Ids por milisegundo: espera para que dos metas no compartan id.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return goals.goals.firstWhere((g) => g.name == name);
  }

  FinancialGoal goal(String id) => goals.getGoalById(id)!;

  Transaction txOf(GoalContribution c) =>
      transactions.allTransactions.firstWhere((t) => t.id == c.transactionId);

  List<GoalContribution> contributionsOf(String goalId) =>
      goals.getGoalContributions(goalId);

  Future<void> editAmount(Transaction t, double amount) async {
    await transactions.updateTransaction(t.copyWith(amount: amount));
    await settle();
  }

  Map<String, dynamic> persistedGoal(SharedPreferences prefs, String id) {
    final list = json.decode(prefs.getString('financial_goals')!) as List;
    return list.cast<Map<String, dynamic>>().firstWhere((g) => g['id'] == id);
  }

  List<Map<String, dynamic>> persistedContributions(SharedPreferences prefs) =>
      (json.decode(prefs.getString('goal_contributions') ?? '[]') as List)
          .cast<Map<String, dynamic>>();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Primero se vacían las metas en memoria: si no, al vaciar las
    // transacciones la sincronización volvería a guardar las metas de la
    // prueba anterior en el almacenamiento recién limpiado.
    await goals.loadGoals();
    await accounts.loadAccounts();
    await accounts.updateInitialBalance(accounts.activeAccountId, 1000);
    await transactions.loadTransactions();
    await transactions.clearAllTransactions();
    await goals.loadGoals();
  });

  group('A–E: un aporte', () {
    test('A. crear aporte: meta, historial y balance coinciden', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      await settle();

      final c = contributionsOf(g.id!).single;
      final t = txOf(c);
      expect(t.amount, 100);
      expect(t.type, TransactionType.expense);
      expect(t.expenseCategory, ExpenseCategory.savings);
      expect(t.description, 'Aporte a Moto');
      expect(goal(g.id!).currentAmount, 100);
      expect(goal(g.id!).progressPercentage, closeTo(0.10, 1e-9));
      expect(goal(g.id!).remainingAmount, 900);
      // El aporte sale del saldo disponible.
      expect(transactions.totalBalance, 900);
    });

    test('B. editar aumentando: 100 → 350', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      final c = contributionsOf(g.id!).single;

      await editAmount(txOf(c), 350);

      expect(contributionsOf(g.id!).single.amount, 350);
      expect(goal(g.id!).currentAmount, 350);
      expect(goal(g.id!).progressPercentage, closeTo(0.35, 1e-9));
      expect(transactions.totalBalance, 650);
    });

    test('C. editar disminuyendo: 350 → 50', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 350);
      final c = contributionsOf(g.id!).single;

      await editAmount(txOf(c), 50);

      expect(goal(g.id!).currentAmount, 50);
      expect(goal(g.id!).progressPercentage, closeTo(0.05, 1e-9));
      expect(transactions.totalBalance, 950);
    });

    test('D. editar con el mismo valor no duplica ni cambia nada', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 120);
      final c = contributionsOf(g.id!).single;

      await editAmount(txOf(c), 120);

      expect(contributionsOf(g.id!), hasLength(1));
      expect(goal(g.id!).currentAmount, 120);
      expect(
        transactions.allTransactions.where((t) => t.amount == 120),
        hasLength(1),
      );
    });

    test('E. eliminar el aporte desde el historial', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      final c = contributionsOf(g.id!).single;

      await transactions.deleteTransaction(c.transactionId!);
      await settle();

      expect(contributionsOf(g.id!), isEmpty);
      expect(goal(g.id!).currentAmount, 0);
      expect(goal(g.id!).progressPercentage, 0);
      expect(transactions.totalBalance, 1000);
    });

    test('editar la fecha del aporte también mueve el aporte', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      final c = contributionsOf(g.id!).single;
      final newDate = DateTime(2025, 3, 15, 10);

      await transactions.updateTransaction(txOf(c).copyWith(date: newDate));
      await settle();

      expect(contributionsOf(g.id!).single.date, newDate);
      expect(goal(g.id!).currentAmount, 100);
    });

    test('si el aporte deja de ser un gasto, deja de contar en la meta', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      final c = contributionsOf(g.id!).single;

      await transactions.updateTransaction(
        txOf(c).copyWith(
          type: TransactionType.income,
          incomeCategory: IncomeCategory.other,
        ),
      );
      await settle();

      expect(contributionsOf(g.id!), isEmpty);
      expect(goal(g.id!).currentAmount, 0);
    });
  });

  group('F–J: varios aportes', () {
    test(
      'F/G. 100 + 200 = 300; editar el segundo a 350 → 450 (45 %)',
      () async {
        final g = await createGoal();
        await goals.addContribution(g.id!, 100);
        await goals.addContribution(g.id!, 200);
        expect(goal(g.id!).currentAmount, 300);
        expect(goal(g.id!).progressPercentage, closeTo(0.30, 1e-9));

        final second = contributionsOf(
          g.id!,
        ).firstWhere((c) => c.amount == 200);
        await editAmount(txOf(second), 350);

        final amounts = contributionsOf(g.id!).map((c) => c.amount).toList()
          ..sort();
        expect(amounts, [100, 350]);
        expect(goal(g.id!).currentAmount, 450);
        expect(goal(g.id!).progressPercentage, closeTo(0.45, 1e-9));
        expect(transactions.totalBalance, 550);
      },
    );

    test('H. eliminar uno de varios', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      await goals.addContribution(g.id!, 200);
      await goals.addContribution(g.id!, 50);

      final middle = contributionsOf(g.id!).firstWhere((c) => c.amount == 200);
      await transactions.deleteTransaction(middle.transactionId!);
      await settle();

      expect(contributionsOf(g.id!).map((c) => c.amount).toSet(), {100, 50});
      expect(goal(g.id!).currentAmount, 150);
      expect(transactions.totalBalance, 850);
    });

    test(
      'I. eliminar todos (selección múltiple del historial) deja la meta en 0',
      () async {
        final g = await createGoal();
        await goals.addContribution(g.id!, 100);
        await goals.addContribution(g.id!, 200);

        await transactions.deleteTransactionsByIds(
          contributionsOf(g.id!).map((c) => c.transactionId!).toList(),
        );
        await settle();

        expect(contributionsOf(g.id!), isEmpty);
        expect(goal(g.id!).currentAmount, 0);
        expect(transactions.totalBalance, 1000);
      },
    );

    test('J. crear un aporte después de editar otro', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      await editAmount(txOf(contributionsOf(g.id!).single), 250);
      await goals.addContribution(g.id!, 40);

      expect(contributionsOf(g.id!), hasLength(2));
      expect(goal(g.id!).currentAmount, 290);
      // Cada aporte tiene su propia transacción.
      final ids = contributionsOf(g.id!).map((c) => c.transactionId).toSet();
      expect(ids, hasLength(2));
    });

    test('aportes a dos metas no se mezclan', () async {
      final moto = await createGoal(name: 'Moto');
      final viaje = await createGoal(name: 'Viaje', target: 500);
      await goals.addContribution(moto.id!, 100);
      await goals.addContribution(viaje.id!, 300);

      await editAmount(txOf(contributionsOf(viaje.id!).single), 320);

      expect(goal(moto.id!).currentAmount, 100);
      expect(goal(viaje.id!).currentAmount, 320);
    });
  });

  group('K. persistencia (cerrar y abrir la app)', () {
    test('crear → editar → eliminar sobrevive al reinicio', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      await goals.addContribution(g.id!, 200);
      await restart();
      expect(goal(g.id!).currentAmount, 300);

      final second = contributionsOf(g.id!).firstWhere((c) => c.amount == 200);
      await editAmount(txOf(second), 350);
      await restart();
      expect(goal(g.id!).currentAmount, 450);
      expect(transactions.totalBalance, 550);

      final prefs = await SharedPreferences.getInstance();
      final stored = persistedContributions(prefs);
      expect(stored, hasLength(2));
      expect(stored.map((c) => c['amount']).toSet(), {100.0, 350.0});
      expect(stored.every((c) => c['transactionId'] != null), isTrue);
      expect(persistedGoal(prefs, g.id!)['currentAmount'], 450.0);

      await transactions.deleteTransaction(
        contributionsOf(g.id!).firstWhere((c) => c.amount == 100).transactionId!,
      );
      await restart();
      expect(goal(g.id!).currentAmount, 350);
      expect(contributionsOf(g.id!), hasLength(1));
      expect(persistedContributions(prefs), hasLength(1));
    });

    test('una edición hecha con las metas sin cargar se aplica al abrir', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      await settle();

      // Se edita la transacción directamente en disco (como si la meta no
      // hubiera estado cargada en ese momento) y se reabre la app.
      final prefs = await SharedPreferences.getInstance();
      final raw = (json.decode(prefs.getString('transactions')!) as List)
          .cast<Map<String, dynamic>>();
      raw.single['amount'] = 275.0;
      await prefs.setString('transactions', json.encode(raw));

      await restart();
      expect(goal(g.id!).currentAmount, 275);
      expect(contributionsOf(g.id!).single.amount, 275);
    });
  });

  group('Meta alcanzada / excedida', () {
    test('aporte = objetivo → completada; editarlo a menos la reabre', () async {
      final g = await createGoal(target: 1000);
      await goals.addContribution(g.id!, 1000);
      expect(goal(g.id!).status, GoalStatus.completed);
      expect(goal(g.id!).progressPercentage, 1.0);
      expect(goal(g.id!).remainingAmount, 0);

      await editAmount(txOf(contributionsOf(g.id!).single), 400);

      expect(goal(g.id!).status, GoalStatus.active);
      expect(goal(g.id!).completedAt, isNull);
      expect(goal(g.id!).currentAmount, 400);
    });

    test('aporte > objetivo: progreso tope 100 % y nada que falte', () async {
      final g = await createGoal(target: 1000);
      await goals.addContribution(g.id!, 1500);
      expect(goal(g.id!).currentAmount, 1500);
      expect(goal(g.id!).progressPercentage, 1.0);
      expect(goal(g.id!).remainingAmount, 0);
      expect(goal(g.id!).status, GoalStatus.completed);
      expect(goal(g.id!).suggestedContributionAmount, 0);
    });

    test('acumulado > objetivo con varios aportes', () async {
      final g = await createGoal(target: 300);
      await goals.addContribution(g.id!, 200);
      expect(goal(g.id!).status, GoalStatus.active);
      await goals.addContribution(g.id!, 200);
      expect(goal(g.id!).status, GoalStatus.completed);
      expect(goal(g.id!).currentAmount, 400);
    });

    test('muchos aportes pequeños suman exacto (sin errores de redondeo)', () async {
      final g = await createGoal(target: 1);
      for (var i = 0; i < 10; i++) {
        await goals.addContribution(g.id!, 0.1);
      }
      expect(goal(g.id!).currentAmount, 1.0);
      expect(goal(g.id!).status, GoalStatus.completed);
    });

    test('subir el objetivo de una meta completada la reabre', () async {
      final g = await createGoal(target: 100);
      await goals.addContribution(g.id!, 100);
      expect(goal(g.id!).status, GoalStatus.completed);

      await goals.updateGoal(goal(g.id!).copyWith(targetAmount: 500));
      expect(goal(g.id!).status, GoalStatus.active);
      expect(goal(g.id!).progressPercentage, closeTo(0.2, 1e-9));
    });

    test('editar una meta pausada la deja pausada', () async {
      final g = await createGoal();
      await goals.pauseGoal(g.id!);

      await goals.updateGoal(goal(g.id!).copyWith(name: 'Moto nueva'));

      expect(goal(g.id!).status, GoalStatus.paused);
      expect(goal(g.id!).name, 'Moto nueva');
    });
  });

  group('Aporte pequeño / grande / retiro', () {
    test('aporte de 0,01 y de 20.000.032,45', () async {
      final g = await createGoal(target: 30000000);
      await goals.addContribution(g.id!, 0.01);
      await goals.addContribution(g.id!, 20000032.45);
      expect(goal(g.id!).currentAmount, 20000032.46);
      expect(goal(g.id!).progressPercentage.isFinite, isTrue);
    });

    test('monto 0, negativo o NaN se rechaza sin crear nada', () async {
      final g = await createGoal();
      for (final bad in [0.0, -5.0, double.nan, double.infinity]) {
        await expectLater(goals.addContribution(g.id!, bad), throwsException);
      }
      expect(contributionsOf(g.id!), isEmpty);
      expect(transactions.allTransactions, isEmpty);
    });

    test('un retiro también queda enlazado a su ingreso', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 300);
      await goals.withdrawFromGoal(g.id!, 100);
      expect(goal(g.id!).currentAmount, 200);

      final withdrawal = contributionsOf(g.id!).firstWhere((c) => c.amount < 0);
      final income = txOf(withdrawal);
      expect(income.type, TransactionType.income);
      expect(income.amount, 100);

      await editAmount(income, 50);
      expect(goal(g.id!).currentAmount, 250);
      expect(transactions.totalBalance, 1000 - 300 + 50);
    });
  });

  group('Estadísticas y eliminar meta', () {
    test('el aporte cuenta como gasto de Ahorros e Inversión del mes', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      await editAmount(txOf(contributionsOf(g.id!).single), 350);

      final stats = StatsService().getCategoryStats();
      final savings = stats.firstWhere(
        (s) => s.category == ExpenseCategory.savings,
      );
      expect(savings.amount, 350);
      expect(StatsService().getCurrentVsPreviousStats().currentExpenses, 350);
    });

    test('eliminar la meta conserva sus gastos en el historial', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      await goals.deleteGoal(g.id!);
      await settle();

      expect(goals.getGoalById(g.id!), isNull);
      expect(goals.allContributions, isEmpty);
      expect(transactions.allTransactions, hasLength(1));
      expect(transactions.totalBalance, 900);
    });

    test('el resumen de metas solo suma la cuenta activa', () async {
      final g = await createGoal();
      await goals.addContribution(g.id!, 100);
      final other = await accounts.addAccount(
        name: 'Ahorros',
        type: AccountType.savings,
      );
      await accounts.setActiveAccount(other.id);
      try {
        final summary = goals.getGoalSummary();
        expect(summary.totalGoals, 0);
        expect(summary.totalCurrentAmount, 0);
        expect(goals.getContributionStats().thisMonthTotal, 0);
      } finally {
        await accounts.setActiveAccount(accounts.defaultAccount.id);
      }
      expect(goals.getGoalSummary().totalCurrentAmount, 100);
    });
  });

  group('Migración de aportes antiguos (sin enlace)', () {
    Future<void> seedLegacy({
      required double contributionAmount,
      required double transactionAmount,
      required DateTime transactionDate,
      String description = 'Aporte a Moto',
    }) async {
      final created = DateTime(2026, 9, 1, 10, 0, 0);
      final accountId = accounts.activeAccountId;
      SharedPreferences.setMockInitialValues({
        'accounts': json.encode(accounts.accounts.map((a) => a.toJson()).toList()),
        'active_account_id': accountId,
        'financial_goals': json.encode([
          FinancialGoal(
            id: 'g1',
            name: 'Moto',
            description: '',
            targetAmount: 1000,
            currentAmount: contributionAmount,
            startDate: created,
            targetDate: DateTime(2027, 9, 1),
            type: GoalType.purchase,
            createdAt: created,
            accountId: accountId,
          ).toJson(),
        ]),
        'goal_contributions': json.encode([
          GoalContribution(
            id: 'c1',
            goalId: 'g1',
            amount: contributionAmount,
            date: created,
            accountId: accountId,
          ).toJson(),
        ]),
        'transactions': json.encode([
          Transaction(
            id: '${created.millisecondsSinceEpoch + 3}',
            amount: transactionAmount,
            type: TransactionType.expense,
            description: description,
            date: transactionDate,
            expenseCategory: ExpenseCategory.savings,
            accountId: accountId,
          ).toJson(),
        ]),
      });
      await accounts.loadAccounts();
      await transactions.loadTransactions();
      await goals.loadGoals();
    }

    test(
      'un aporte antiguo cuya transacción ya se editó se corrige al abrir',
      () async {
        // El caso reportado: historial dice 350 y la meta seguía en 200.
        await seedLegacy(
          contributionAmount: 200,
          transactionAmount: 350,
          transactionDate: DateTime(2026, 9, 1, 10, 0, 0, 3),
        );

        final c = goals.getGoalContributions('g1').single;
        expect(c.transactionId, isNotNull);
        expect(c.amount, 350);
        expect(goals.getGoalById('g1')!.currentAmount, 350);

        // Y desde ahora queda sincronizado.
        await editAmount(transactions.allTransactions.single, 500);
        expect(goals.getGoalById('g1')!.currentAmount, 500);
      },
    );

    test('con la fecha cambiada se reconoce por la descripción', () async {
      await seedLegacy(
        contributionAmount: 200,
        transactionAmount: 200,
        transactionDate: DateTime(2026, 8, 20),
      );
      expect(goals.getGoalContributions('g1').single.transactionId, isNotNull);
    });

    test('si no hay una transacción que coincida, el aporte se conserva', () async {
      await seedLegacy(
        contributionAmount: 200,
        transactionAmount: 200,
        transactionDate: DateTime(2026, 8, 20),
        description: 'Otra cosa',
      );
      final c = goals.getGoalContributions('g1').single;
      expect(c.transactionId, isNull);
      expect(goals.getGoalById('g1')!.currentAmount, 200);
    });
  });
}
