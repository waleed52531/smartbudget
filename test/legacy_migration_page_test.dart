import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/legacy_migration/legacy_migration_service.dart';
import 'package:smartbudget/core/legacy_migration/ownership_grant.dart';
import 'package:smartbudget/core/user_storage/user_database_manager.dart';
import 'package:smartbudget/features/auth/presentation/session_app.dart';
import 'package:smartbudget/features/legacy_migration/presentation/legacy_migration_page.dart';
import 'auth/support.dart';

void main() {
  testWidgets(
    'ownership confirmation gates preparation; logout hides migration review',
    (tester) async {
      final h = Harness(initial: alice);
      final manager = _NoStorage();
      final service = LegacyMigrationService(
        manager: manager,
        ownership: OwnershipGrantVerifier(() async => {}),
      );
      await tester.pumpWidget(
        AuthSessionApp(
          createSession: h.create,
          createLegacyMigration: () => service,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Legacy migration'));
      await tester.pumpAndSettle();
      final prepare = find.widgetWithText(
        FilledButton,
        'Prepare encrypted copy',
      );
      expect(tester.widget<FilledButton>(prepare).onPressed, isNull);
      final context = tester.element(find.byType(CheckboxListTile));
      final cubit = context.read<LegacyMigrationCubit>();
      unawaited(
        cubit.execute(
          () async => const MigrationReview(
            'synthetic',
            'synthetic',
            2,
            {'transactions': 7},
            {'income': '999'},
            'synthetic',
            'review',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('transactions: 7 records'), findsOneWidget);
      unawaited(h.auth.signOut());
      await tester.pumpAndSettle();
      expect(find.text('transactions: 7 records'), findsNothing);
      expect(
        find.text('Migration locked. Return and verify your session.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

// Any storage call before explicit consent/approval is a test failure. Real
// encrypted migration and lifecycle behavior are covered by the database tests.
class _NoStorage implements UserDatabaseManager {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected storage access from UI test');
}
