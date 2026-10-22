import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/user_storage/encrypted_database_factory.dart';
import 'package:smartbudget/core/user_storage/storage_access.dart';
import 'package:smartbudget/core/user_storage/user_database_manager.dart';
import 'package:smartbudget/features/auth/data/session_vault.dart';
import 'package:smartbudget/features/auth/domain/lease_verifier.dart';
import 'package:smartbudget/features/auth/domain/session_contracts.dart';
import 'package:smartbudget/features/auth/presentation/session_cubit.dart';
import '../auth/support.dart';
import 'support.dart';

void main() {
  late Directory dir;
  late TestKeyVault keys;
  late Harness h;
  late SessionCubit session;
  late UserDatabaseManager manager;
  SessionCubit create() => SessionCubit(
    auth: h.auth,
    authorization: h.gateway,
    vault: SessionVault(h.store),
    clock: h.clock,
    verifier: LeaseVerifier(projectId: fixture['projectId']),
    storageFactory: (authority) => manager = UserDatabaseManager(
      authority: authority,
      factory: EncryptedDatabaseFactory(keys),
    ),
  );
  setUp(() async {
    dir = await Directory.systemTemp.createTemp(
      'smartbudget-synthetic-session-storage-',
    );
    keys = TestKeyVault(dir);
    h = Harness(initial: alice);
    session = create();
    await waitFor(() => session.state.status == SessionStatus.authorized);
    await manager.settled;
    expect(manager.failure, isNull);
  });
  tearDown(() async {
    await session.close();
    await dir.delete(recursive: true);
  });
  test(
    'real signed lease drives encrypted storage, restoration, offline access and switching',
    () async {
      await manager.scope.run(
        (db) => db.insertIncome(
          amountMinor: 1200,
          dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
        ),
      );
      final oldManager = manager;
      await session.close();
      expect(oldManager.isOpen, false);
      h.gateway.failure = SessionFailureKind.unavailable;
      session = create();
      await waitFor(() => session.state.status == SessionStatus.authorized);
      await manager.settled;
      expect(session.state.offline, true);
      expect(
        await manager.scope.run(
          (db) async => (await db.getMonthTotals('2026-01')).totalIncome,
        ),
        1200,
      );
      await session.signOut();
      expect(manager.isOpen, false);
      h.gateway.failure = null;
      await session.signIn('second@example.test', 'synthetic-password');
      await waitFor(() => session.state.status == SessionStatus.authorized);
      await manager.settled;
      expect(
        await manager.scope.run(
          (db) async => (await db.getMonthTotals('2026-01')).totalIncome,
        ),
        0,
      );
      expect(keys.creates, 2);
    },
  );
  test(
    'closing during a delayed reopen rejects stale callbacks and closes idempotently',
    () async {
      session.background();
      await manager.settled;
      keys.delayedLoad = Completer<void>();
      keys.loadWaiting = false;
      final resuming = session.resume();
      await waitFor(() => keys.loadWaiting);
      final closing = session.close();
      expect(session.storageGrant, isNull);
      keys.delayedLoad!.complete();
      await closing;
      await resuming;
      await session.close();
      expect(manager.isOpen, false);
    },
  );
  for (final fault in [
    'expiry',
    'rollback',
    'reboot',
    'revocation',
    'background',
  ]) {
    test('$fault invalidates active storage using Stage 3 authority', () async {
      if (fault == 'expiry') h.clock.advance(86400000);
      if (fault == 'rollback') h.clock.wall -= 5000;
      if (fault == 'reboot') h.clock.boot = 'new-boot';
      if (fault == 'revocation') {
        h.gateway.failure = SessionFailureKind.denied;
        await session.refresh();
      }
      if (fault == 'background') session.background();
      await expectLater(
        manager.scope.run((db) => db.customSelect('SELECT 1').get()),
        throwsA(isA<StorageFailure>()),
      );
      await manager.settled;
      expect(manager.isOpen, false);
      expect(session.storageGrant, isNull);
    });
  }
  test(
    'secure logout waits for an in-flight transaction to roll back and close',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final operation = manager.scope.run((db) async {
        await db.insertIncome(
          amountMinor: 100,
          dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
        );
        entered.complete();
        await release.future;
      });
      final rejected = expectLater(operation, throwsA(isA<StorageFailure>()));
      await entered.future;
      bool logoutDone = false;
      final logout = session.signOut().then((_) => logoutDone = true);
      expect(session.storageGrant, isNull);
      expect(manager.isOpen, false);
      await Future<void>.delayed(Duration.zero);
      expect(logoutDone, false);
      release.complete();
      await rejected;
      await logout;
      expect(session.state.status, SessionStatus.signedOut);
      await session.signIn('synthetic@example.test', 'synthetic-password');
      await waitFor(() => session.state.status == SessionStatus.authorized);
      await manager.settled;
      expect(
        await manager.scope.run(
          (db) async => (await db.getMonthTotals('2026-01')).totalIncome,
        ),
        0,
      );
    },
  );
}
