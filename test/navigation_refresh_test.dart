import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/app_shell.dart';
import 'package:smartbudget/core/db/app_db.dart';
import 'package:smartbudget/core/state/month_cubit.dart';
import 'package:smartbudget/features/backup/data/backup_repository.dart';
import 'package:smartbudget/features/budget/data/budget_repository.dart';
import 'package:smartbudget/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:smartbudget/features/recurring/data/recurring_repository.dart';
import 'package:smartbudget/features/reports/presentation/reportsbloc/reports_bloc.dart';
import 'package:smartbudget/features/transactions/data/transaction_repository.dart';
import 'package:smartbudget/core/financial_app.dart';

void main() {
  testWidgets(
    'month and tab navigation never writes budgets or recurring transactions',
    (tester) async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await db.seedDefaultsIfEmpty();
      await RecurringRepository(db).upsertTemplate(
        title: 'Synthetic recurring',
        amountMinor: 100,
        type: 'income',
        dayOfMonth: 1,
      );
      final before = (await BackupRepository(db).exportPayload())['tables'];
      await tester.pumpWidget(MonthlyBudgetApp(db: db));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppShell));
      context.read<MonthCubit>().setMonthId('2026-02');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      context.read<MonthCubit>().setMonthId('2027-03');
      await tester.pumpAndSettle();
      expect((await BackupRepository(db).exportPayload())['tables'], before);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'committed writes refresh dashboard and reports without tab switching',
    (tester) async {
      final db = AppDatabase.withExecutor(NativeDatabase.memory());
      addTearDown(db.close);
      await db.seedDefaultsIfEmpty();
      await tester.pumpWidget(MonthlyBudgetApp(db: db));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(AppShell));
      context.read<MonthCubit>().setMonthId('2026-02');
      await tester.pumpAndSettle();
      final tx = TransactionRepository(db);
      await tx.addIncome(
        monthId: '2026-02',
        amountMinor: 10000,
        dateMillis: DateTime(2026, 2, 2).millisecondsSinceEpoch,
      );
      await tester.pumpAndSettle();
      expect(context.read<DashboardBloc>().state.totals!.totalIncome, 10000);
      expect(context.read<ReportsBloc>().state.totals!.totalIncome, 10000);
      await BudgetRepository(db).updateMonthBudget(
        monthId: '2026-02',
        totalBudgetMinor: 3000,
        savingTargetMinor: 500,
      );
      await tester.pumpAndSettle();
      expect(context.read<DashboardBloc>().state.remainingMinor, 3000);
      expect(
        context.read<ReportsBloc>().state.monthBudget!.savingTargetMinor,
        500,
      );
      await tx.deleteById((await tx.listByMonth('2026-02')).single.id);
      await tester.pumpAndSettle();
      expect(context.read<DashboardBloc>().state.totals!.totalIncome, 0);
      expect(context.read<ReportsBloc>().state.totals!.totalIncome, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
