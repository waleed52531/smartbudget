import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/db/app_db.dart';
import 'package:smartbudget/core/financial_app.dart';

void main() {
  testWidgets('Smart Budget opens its dashboard and navigation', (
    tester,
  ) async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await db.seedDefaultsIfEmpty();
    await tester.pumpWidget(MonthlyBudgetApp(db: db));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Month Summary'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
