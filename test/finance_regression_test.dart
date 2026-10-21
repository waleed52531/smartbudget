import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/db/app_db.dart';
import 'package:smartbudget/core/utils/money.dart';
import 'package:smartbudget/features/budget/data/budget_repository.dart';
import 'package:smartbudget/features/dashboard/data/dashboard_repository.dart';
import 'package:smartbudget/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:smartbudget/features/recurring/data/recurring_repository.dart';
import 'package:smartbudget/features/reports/data/reports_repository.dart';
import 'package:smartbudget/features/reports/presentation/reportsbloc/reports_bloc.dart';
import 'package:smartbudget/features/reports/presentation/reportsbloc/reports_event.dart';
import 'package:smartbudget/features/reports/presentation/reportsbloc/reports_state.dart';
import 'package:smartbudget/features/transactions/data/transaction_repository.dart';
import 'package:smartbudget/features/transactions/bloc/tranasaction_bloc.dart';
import 'package:smartbudget/features/transactions/bloc/tranasaction_event.dart';
import 'package:smartbudget/features/transactions/bloc/tranasaction_state.dart';
import 'package:smartbudget/features/transactions/bloc/tx_filters.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository tx;
  late BudgetRepository budget;
  late RecurringRepository recurring;
  final when = DateTime(2026, 2, 2).millisecondsSinceEpoch;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    tx = TransactionRepository(db);
    budget = BudgetRepository(db);
    recurring = RecurringRepository(db);
    await db.seedDefaultsIfEmpty();
  });
  tearDown(() => db.close());

  test(
    'money parsing is exact and formatting preserves signed minor units',
    () {
      expect(rupeesToMinor('30,000.01'), 3000001);
      expect(rupeesToMinor('0.29'), 29);
      expect(rupeesToMinor('0'), 0);
      expect(rupeesToMinor('92233720368547758.07'), maxMinorAmount);
      expect(minorToRupees(maxMinorAmount), '92233720368547758.07');
      expect(minorToRupees(-1), '-0.01');
      for (final bad in [
        '-1',
        'NaN',
        'Infinity',
        '1.001',
        '1e6',
        '',
        '92233720368547758.08',
      ]) {
        expect(() => rupeesToMinor(bad), throwsFormatException);
      }
    },
  );
  test(
    'repositories reject invalid values without persisting anything',
    () async {
      for (final amount in [0, -1]) {
        await expectLater(
          tx.addIncome(
            monthId: '2026-02',
            amountMinor: amount,
            dateMillis: when,
          ),
          throwsArgumentError,
        );
        await expectLater(
          recurring.upsertTemplate(
            title: 'Synthetic',
            amountMinor: amount,
            type: 'income',
            dayOfMonth: 1,
          ),
          throwsArgumentError,
        );
      }
      await expectLater(
        tx.addExpense(
          monthId: '2026-02',
          amountMinor: 100,
          dateMillis: when,
          subcategoryId: 'cat_groceries',
        ),
        throwsArgumentError,
      );
      await expectLater(
        tx.addIncome(monthId: '2026-01', amountMinor: 100, dateMillis: when),
        throwsArgumentError,
      );
      await expectLater(
        budget.updateMonthBudget(
          monthId: '2026-02',
          totalBudgetMinor: -1,
          savingTargetMinor: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        budget.upsertCategoryLimit(
          monthId: '2026-02',
          categoryId: 'cat_groceries',
          limitMinor: -1,
        ),
        throwsArgumentError,
      );
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.budgetMonths).get(), isEmpty);
    },
  );
  test('viewing missing budgets and reports never persists a month', () async {
    expect((await budget.getMonth('2026-02')).totalBudgetMinor, 0);
    expect(
      (await DashboardRepository(db).getMonth('2026-03')).totalBudgetMinor,
      0,
    );
    await ReportsRepository(db).monthTotals('2026-04');
    expect(await db.select(db.budgetMonths).get(), isEmpty);
  });
  test(
    'explicit recurring application is atomic, idempotent and clamps February',
    () async {
      await recurring.upsertTemplate(
        id: 'expense',
        title: 'Synthetic bill',
        amountMinor: 200,
        type: 'expense',
        subcategoryId: 'sub_groceries_milk',
        dayOfMonth: 31,
      );
      await recurring.upsertTemplate(
        id: 'income',
        title: 'Synthetic income',
        amountMinor: 1000,
        type: 'income',
        dayOfMonth: 1,
      );
      await recurring.upsertTemplate(
        id: 'inactive',
        title: 'Inactive',
        amountMinor: 500,
        type: 'income',
        dayOfMonth: 1,
        isActive: false,
      );
      expect(await recurring.pendingCount('2026-02'), 2);
      final results = await Future.wait([
        recurring.applyToMonth('2026-02'),
        recurring.applyToMonth('2026-02'),
      ]);
      expect(results.fold<int>(0, (n, r) => n + r.appliedCount), 2);
      expect((await recurring.applyToMonth('2026-02')).appliedCount, 0);
      expect(await recurring.pendingCount('2026-02'), 0);
      final rows = await tx.listByMonth('2026-02');
      expect(rows, hasLength(2));
      expect(
        DateTime.fromMillisecondsSinceEpoch(
          rows.firstWhere((r) => r.type == 'expense').dateMillis,
        ).day,
        28,
      );
      final totals = await db.getMonthTotals('2026-02');
      expect(totals.totalSpent, 200);
      expect(totals.totalIncome, 1000);
      await recurring.deleteTemplate('expense');
      expect(await db.select(db.transactions).get(), hasLength(2));
      expect(await db.select(db.recurringApplied).get(), hasLength(1));
    },
  );
  test(
    'dashboard uses income minus expenses, preserving budget remainder',
    () async {
      await budget.updateMonthBudget(
        monthId: '2026-02',
        totalBudgetMinor: 90000,
        savingTargetMinor: 10000,
      );
      await tx.addIncome(
        monthId: '2026-02',
        amountMinor: 100000,
        dateMillis: when,
      );
      await tx.addExpense(
        monthId: '2026-02',
        amountMinor: 20000,
        dateMillis: when,
        subcategoryId: 'sub_groceries_milk',
      );
      final bloc = DashboardBloc(DashboardRepository(db));
      addTearDown(bloc.close);
      final loaded = bloc.stream.firstWhere(
        (s) => s.status == DashboardStatus.loaded,
      );
      bloc.add(const LoadDashboard('2026-02'));
      final state = await loaded;
      expect(state.remainingMinor, 70000);
      expect(state.netIncomeMinor, 80000);
    },
  );
  test('reports reload the same month after a transaction change', () async {
    final bloc = ReportsBloc(
      reportsRepo: ReportsRepository(db),
      budgetRepo: budget,
    );
    addTearDown(bloc.close);
    Future<ReportsState> load() {
      final result = bloc.stream.firstWhere(
        (s) => s.status == ReportsStatus.loaded,
      );
      bloc.add(const LoadReports(monthId: '2026-02'));
      return result;
    }

    expect((await load()).totals!.totalIncome, 0);
    await tx.addIncome(monthId: '2026-02', amountMinor: 900, dateMillis: when);
    expect((await load()).totals!.totalIncome, 900);
  });
  test(
    'empty category filter matches nothing; archived history remains filterable',
    () async {
      await tx.addExpense(
        monthId: '2026-02',
        amountMinor: 300,
        dateMillis: when,
        subcategoryId: 'sub_groceries_milk',
        note: 'Synthetic milk',
      );
      await tx.addIncome(
        monthId: '2026-02',
        amountMinor: 1000,
        dateMillis: when,
      );
      await (db.update(db.categoryNodes)
            ..where((n) => n.id.equals('sub_groceries_milk')))
          .write(const CategoryNodesCompanion(archived: Value(true)));
      final ids = await db.getSubcategoryIdsByCategory('cat_groceries');
      expect(ids, contains('sub_groceries_milk'));
      final bloc = TransactionBloc(tx);
      addTearDown(bloc.close);
      Future<TransactionState> filter(TxFilters f) {
        final result = bloc.stream.firstWhere(
          (s) => s.status == TxStatus.loaded,
        );
        bloc.add(ApplyTxFiltersRequested(monthId: '2026-02', filters: f));
        return result;
      }

      expect(
        (await filter(
          const TxFilters(categoryId: 'empty', categorySubcategoryIds: []),
        )).items,
        isEmpty,
      );
      final state = await filter(
        TxFilters(
          categoryId: 'cat_groceries',
          categorySubcategoryIds: ids,
          search: 'MILK',
          minMinor: 300,
          maxMinor: 300,
        ),
      );
      expect(state.items, hasLength(1));
      expect(state.totalExpenseMinor, 300);
      expect(state.totalIncomeMinor, 0);
      expect(
        TxFilters(
          categoryId: 'cat',
          categorySubcategoryIds: ids,
        ).copyWith(clearCategory: true).categorySubcategoryIds,
        isNull,
      );
    },
  );
}
