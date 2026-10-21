import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartbudget/core/db/app_db.dart';
import 'package:smartbudget/features/categories/data/category_repository.dart';
import 'package:smartbudget/features/transactions/bloc/tranasaction_bloc.dart';
import 'package:smartbudget/features/transactions/data/transaction_repository.dart';
import 'package:smartbudget/features/transactions/presentation/add_transaction_screen.dart';
import 'package:smartbudget/features/recurring/data/recurring_repository.dart';
import 'package:smartbudget/features/recurring/presentation/bloc/recurring_bloc.dart';
import 'package:smartbudget/features/recurring/presentation/recurring_form_screen.dart';

class DelayedTransactions extends TransactionRepository {
  DelayedTransactions(super.db, {required this.fail});
  final bool fail;
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<void> addIncome({
    required String monthId,
    required int amountMinor,
    required int dateMillis,
    String? note,
  }) async {
    calls++;
    await gate.future;
    if (fail) throw StateError('Synthetic save failure');
    await super.addIncome(
      monthId: monthId,
      amountMinor: amountMinor,
      dateMillis: dateMillis,
      note: note,
    );
  }
}

class DelayedRecurring extends RecurringRepository {
  DelayedRecurring(super.db, {required this.fail});
  final bool fail;
  final gate = Completer<void>();
  int calls = 0;
  @override
  Future<void> upsertTemplate({
    String? id,
    required String title,
    required int amountMinor,
    required String type,
    String? subcategoryId,
    String? note,
    required int dayOfMonth,
    bool isActive = true,
  }) async {
    calls++;
    await gate.future;
    if (fail) throw StateError('Synthetic save failure');
    await super.upsertTemplate(
      id: id,
      title: title,
      amountMinor: amountMinor,
      type: type,
      subcategoryId: subcategoryId,
      note: note,
      dayOfMonth: dayOfMonth,
      isActive: isActive,
    );
  }
}

void main() {
  Future<void> openTransactionForm(
    WidgetTester tester,
    AppDatabase db,
    AddTransactionScreen screen,
  ) async {
    await tester.pumpWidget(
      RepositoryProvider<CategoryRepository>.value(
        value: CategoryRepository(db),
        child: BlocProvider(
          create: (_) => TransactionBloc(TransactionRepository(db)),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => screen),
                  ),
                  child: const Text('Open form'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
  }

  testWidgets('explicit quick-add selection overrides saved preferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'last_category_id': 'cat_bills',
      'last_subcategory_id': 'sub_bills_rent',
    });
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await db.seedDefaultsIfEmpty();
    await openTransactionForm(
      tester,
      db,
      const AddTransactionScreen(
        monthId: '2026-02',
        prefillSubcategoryId: 'sub_groceries_milk',
      ),
    );
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Rent'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('editing archived history preserves its original category', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await db.seedDefaultsIfEmpty();
    await db.insertExpense(
      amountMinor: 100,
      dateMillis: DateTime(2026, 2, 2).millisecondsSinceEpoch,
      subcategoryId: 'sub_groceries_milk',
    );
    final category = CategoryRepository(db);
    await category.archiveNode('cat_groceries');
    await category.archiveNode('sub_groceries_milk');
    final existing = await db.select(db.transactions).getSingle();
    await openTransactionForm(
      tester,
      db,
      AddTransactionScreen(monthId: '2026-02', existing: existing),
    );
    expect(find.text('Groceries'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '2.50');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Update'));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Update'));
    await tester.pumpAndSettle();
    final updated = await db.select(db.transactions).getSingle();
    expect(updated.subcategoryId, 'sub_groceries_milk');
    expect(updated.amountMinor, 250);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final recurring in [false, true]) {
    for (final fail in [false, true]) {
      testWidgets(
        '${recurring ? 'recurring' : 'transaction'} form awaits ${fail ? 'failure' : 'success'} and prevents repeat saves',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final db = AppDatabase.withExecutor(NativeDatabase.memory());
          addTearDown(db.close);
          await db.seedDefaultsIfEmpty();
          final tx = DelayedTransactions(db, fail: fail);
          final rec = DelayedRecurring(db, fail: fail);
          await tester.pumpWidget(
            MultiRepositoryProvider(
              providers: [
                RepositoryProvider<CategoryRepository>.value(
                  value: CategoryRepository(db),
                ),
              ],
              child: MultiBlocProvider(
                providers: [
                  BlocProvider(create: (_) => TransactionBloc(tx)),
                  BlocProvider(create: (_) => RecurringBloc(repo: rec)),
                ],
                child: MaterialApp(
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => recurring
                                ? const RecurringFormScreen()
                                : const AddTransactionScreen(
                                    monthId: '2026-02',
                                  ),
                          ),
                        ),
                        child: const Text('Open form'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open form'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Income'));
          await tester.pumpAndSettle();
          if (recurring) {
            await tester.enterText(
              find.byType(TextField).at(0),
              'Synthetic recurring',
            );
            await tester.enterText(find.byType(TextField).at(1), '123.45');
          } else {
            await tester.enterText(find.byType(TextField).at(0), '123.45');
          }
          await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
          await tester.pump();
          expect(recurring ? rec.calls : tx.calls, 1);
          final button = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save'),
          );
          expect(button.onPressed, null);
          expect(
            find.text(recurring ? 'Add Recurring' : 'Add Transaction'),
            findsOneWidget,
          );
          (recurring ? rec.gate : tx.gate).complete();
          await tester.pumpAndSettle();
          if (fail) {
            expect(
              find.text(recurring ? 'Add Recurring' : 'Add Transaction'),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<ElevatedButton>(
                    find.widgetWithText(ElevatedButton, 'Save'),
                  )
                  .onPressed,
              isNotNull,
            );
            expect(await db.select(db.transactions).get(), isEmpty);
          } else {
            expect(find.text('Open form'), findsOneWidget);
            expect(
              recurring
                  ? await db.select(db.recurringTemplates).get()
                  : await db.select(db.transactions).get(),
              hasLength(1),
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
