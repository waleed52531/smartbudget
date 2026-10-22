import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:smartbudget/core/db/app_db.dart';
import 'package:smartbudget/core/user_storage/database_key_vault.dart';
import 'package:smartbudget/core/user_storage/encrypted_database_factory.dart';
import 'package:smartbudget/core/user_storage/storage_access.dart';
import 'package:smartbudget/core/user_storage/user_database_manager.dart';
import 'package:smartbudget/features/backup/data/backup_repository.dart';
import 'support.dart';

const project = TestAuthority.project;
void main() {
  late Directory directory;
  late TestKeyVault vault;
  late TestAuthority authority;
  late UserDatabaseManager manager;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    directory = await Directory.systemTemp.createTemp(
      'smartbudget-synthetic-users-',
    );
    vault = TestKeyVault(directory);
    authority = TestAuthority();
    manager = UserDatabaseManager(
      authority: authority,
      factory: EncryptedDatabaseFactory(vault),
    );
  });
  tearDown(() async {
    await manager.dispose();
    await authority.events.close();
    await directory.delete(recursive: true);
  });
  Future<void> authorize(String uid) async {
    authority.authorize(uid);
    await manager.settled;
  }

  Future<int> total() => manager.scope.run(
    (db) async => (await db.getMonthTotals('2026-01')).totalIncome,
  );
  Future<void> income(int amount) => manager.scope.run(
    (db) => db.insertIncome(
      amountMinor: amount,
      dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
    ),
  );
  final locked = throwsA(
    isA<StorageFailure>().having(
      (e) => e.kind,
      'kind',
      StorageFailureKind.locked,
    ),
  );

  test('signed-out and revoked users never open financial storage', () async {
    await manager.settled;
    await expectLater(total(), locked);
    expect(vault.creates, 0);
    expect(directory.listSync(), isEmpty);
    authority.failVerify = true;
    await authorize('a');
    expect(manager.isOpen, false);
    expect(vault.creates, 0);
  });
  test(
    'two users have independent keys, records, owner metadata and encrypted reopen',
    () async {
      await authorize('a');
      expect(manager.failure, isNull);
      await income(12345);
      final keyA = vault.records[storageScope(project, 'a')]!.bytes.toList();
      final staleScope = manager.scope;
      AppDatabase? retained;
      await manager.scope.run((db) async {
        retained = db;
      });
      await authorize('b');
      expect(await total(), 0);
      await income(98765);
      await expectLater(
        staleScope.run(
          (db) => db.insertIncome(
            amountMinor: 999,
            dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
          ),
        ),
        locked,
      );
      expect(vault.records[storageScope(project, 'b')]!.bytes, isNot(keyA));
      await expectLater(
        () => retained!.customSelect('SELECT 1').get(),
        throwsA(isA<StorageFailure>()),
      );
      await authorize('a');
      expect(await total(), 12345);
      await manager.scope.run((db) async {
        final owner = await db.select(db.databaseOwnership).getSingle();
        expect(owner.uid, 'a');
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await db.customSelect('PRAGMA integrity_check').getSingle()).data,
          {'integrity_check': 'ok'},
        );
      });
      authority.revoke();
      await manager.settled;
      for (final uid in ['a', 'b']) {
        final file = vault.file(project, uid);
        expect(
          utf8.decode(
            file.readAsBytesSync().take(16).toList(),
            allowMalformed: true,
          ),
          isNot(startsWith('SQLite format 3')),
        );
        final plain = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
        try {
          expect(
            () => plain.select('SELECT * FROM transactions'),
            throwsA(isA<sql.SqliteException>()),
          );
        } finally {
          plain.close();
        }
      }
      await manager.dispose();
      manager = UserDatabaseManager(
        authority: authority,
        factory: EncryptedDatabaseFactory(vault),
      );
      await authorize('a');
      expect(await total(), 12345);
      expect(vault.creates, 2);
    },
  );

  for (final fault in [
    'missing-key',
    'wrong-key',
    'corrupt-envelope',
    'wrong-owner',
    'unowned',
    'missing-database',
  ]) {
    test(
      '$fault blocks opening without overwrite, rekey, or ownership reassignment',
      () async {
        await authorize('a');
        await income(321);
        authority.revoke();
        await manager.settled;
        final name = storageScope(project, 'a');
        final originalKey = vault.records[name]!;
        final file = vault.file(project, 'a');
        if (fault == 'wrong-owner' || fault == 'unowned') {
          // Test-only tampering of a disposable database with its valid test key.
          final raw = sql.sqlite3.open(file.path);
          raw.execute("PRAGMA cipher = 'chacha20'");
          final hex = originalKey.bytes
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          raw.execute("PRAGMA hexkey = '$hex'");
          raw.execute('DROP TRIGGER ownership_no_update');
          raw.execute('DROP TRIGGER ownership_no_delete');
          raw.execute(
            fault == 'wrong-owner'
                ? "UPDATE database_ownership SET uid='b'"
                : 'DELETE FROM database_ownership',
          );
          raw.close();
        }
        if (fault == 'missing-key') vault.records.remove(name);
        if (fault == 'wrong-key') {
          vault.records[name] = DatabaseKey(
            Uint8List.fromList(List.filled(32, 42)),
            originalKey.databaseId,
          );
        }
        if (fault == 'corrupt-envelope') vault.corrupt.add(name);
        if (fault == 'missing-database') file.deleteSync();
        final bytes = file.existsSync() ? file.readAsBytesSync() : null;
        await authorize('a');
        expect(manager.isOpen, false);
        expect(manager.failure, isNotNull);
        await expectLater(total(), throwsA(isA<StorageFailure>()));
        expect(vault.creates, 1);
        if (bytes == null) {
          expect(file.existsSync(), false);
        } else {
          expect(file.readAsBytesSync(), bytes);
        }
      },
    );
  }

  test(
    'pending transaction rolls back on logout; close finishes before B opens',
    () async {
      await authorize('a');
      await income(100);
      final entered = Completer<void>(), release = Completer<void>();
      final pending = manager.scope.run((db) async {
        await db.insertIncome(
          amountMinor: 999,
          dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
        );
        entered.complete();
        await release.future;
      });
      final failure = expectLater(pending, throwsA(isA<StorageFailure>()));
      await entered.future;
      authority.revoke();
      authority.authorize('b');
      expect(manager.isOpen, false);
      expect(vault.creates, 1);
      release.complete();
      await failure;
      await manager.settled;
      expect(await total(), 0);
      await authorize('a');
      expect(await total(), 100);
    },
  );
  test(
    'stale key-load completion cannot reopen A after a switch to B',
    () async {
      await authorize('a');
      await income(111);
      authority.revoke();
      await manager.settled;
      vault.delayedLoad = Completer<void>();
      vault.loadWaiting = false;
      authority.authorize('a');
      while (!vault.loadWaiting) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      authority.authorize('b');
      vault.delayedLoad!.complete();
      await manager.settled;
      expect(await total(), 0);
      expect(authority.storageGrant!.uid, 'b');
    },
  );
  test('expired grant rejects retained reads and pending commit', () async {
    authority.authorize('a', milliseconds: 150);
    await manager.settled;
    final entered = Completer<void>(), release = Completer<void>();
    final pending = manager.scope.run((db) async {
      await db.insertIncome(
        amountMinor: 888,
        dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
      );
      entered.complete();
      await release.future;
    });
    final failure = expectLater(pending, throwsA(isA<StorageFailure>()));
    await entered.future;
    await Future<void>.delayed(const Duration(milliseconds: 160));
    release.complete();
    await failure;
    await authorize('a');
    expect(await total(), 0);
  });
  test('backup overwrite excludes and preserves immutable ownership', () async {
    await authorize('a');
    await income(4321);
    await manager.scope.run((db) async {
      final owner = await db.select(db.databaseOwnership).getSingle();
      await expectLater(
        db.customStatement("UPDATE database_ownership SET uid='b'"),
        throwsA(isA<sql.SqliteException>()),
      );
      await expectLater(
        db.customStatement('DELETE FROM database_ownership'),
        throwsA(isA<sql.SqliteException>()),
      );
      await expectLater(
        db.customStatement(
          "INSERT INTO database_ownership VALUES (2,'p','u','d')",
        ),
        throwsA(isA<sql.SqliteException>()),
      );
      final repo = BackupRepository(db);
      final payload = await repo.exportPayload();
      expect((payload['tables'] as Map).length, 6);
      expect(
        (payload['tables'] as Map).containsKey('databaseOwnership'),
        false,
      );
      final backup = File('${directory.path}/synthetic-backup.json')
        ..writeAsStringSync(jsonEncode(payload));
      await repo.restoreFromJsonFile(file: backup, mode: RestoreMode.overwrite);
      expect(await db.select(db.databaseOwnership).getSingle(), owner);
    });
    expect(await total(), 4321);
  });

  test('same scope cannot be opened concurrently by another manager', () async {
    await authorize('a');
    final another = UserDatabaseManager(
      authority: authority,
      factory: EncryptedDatabaseFactory(vault),
    );
    try {
      await another.settled;
      expect(another.isOpen, false);
      expect(another.failure, StorageFailureKind.busy);
      expect(manager.isOpen, true);
      expect(vault.creates, 1);
    } finally {
      await another.dispose();
    }
  });
  test('corrupt database is preserved on rejection', () async {
    await authorize('a');
    authority.revoke();
    await manager.settled;
    final file = vault.file(project, 'a');
    final corrupt = Uint8List.fromList(List.filled(file.lengthSync(), 0x5a));
    file.writeAsBytesSync(corrupt, flush: true);
    await authorize('a');
    expect(manager.isOpen, false);
    expect(file.readAsBytesSync(), corrupt);
    expect(vault.creates, 1);
  });
  test(
    'scope derivation separates project and UID and rejects path injection controls',
    () {
      expect(storageScope(project, '../a'), isNot(storageScope(project, 'a')));
      expect(
        storageScope('other-project', 'a'),
        isNot(storageScope(project, 'a')),
      );
      expect(storageScope(project, 'a'), matches(RegExp('^[a-f0-9]{64}\$')));
      expect(
        () => storageScope(project, 'a\u0000b'),
        throwsA(isA<StorageFailure>()),
      );
    },
  );
}
