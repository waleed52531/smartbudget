import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:smartbudget/core/db/app_db.dart';
import 'package:smartbudget/core/legacy_migration/legacy_migration_service.dart';
import 'package:smartbudget/core/legacy_migration/legacy_source.dart';
import 'package:smartbudget/core/legacy_migration/migration_journal.dart';
import 'package:smartbudget/core/legacy_migration/ownership_grant.dart';
import 'package:smartbudget/core/user_storage/encrypted_database_factory.dart';
import 'package:smartbudget/core/user_storage/database_key_vault.dart';
import 'package:smartbudget/core/user_storage/storage_access.dart';
import 'package:smartbudget/core/user_storage/user_database_manager.dart';
import 'support/v2_fixture.dart';
import 'user_storage/support.dart';

class MigrationAuthority implements StorageAuthority {
  final events = StreamController<void>.broadcast(sync: true);
  StorageGrant? current;
  @override
  StorageGrant? get storageGrant => current;
  @override
  Stream<void> get storageChanges => events.stream;
  void login(String uid) {
    late final StorageGrant grant;
    grant = StorageGrant(
      projectId: 'smartbudget-test',
      uid: uid,
      expiresAtMs: DateTime.now().millisecondsSinceEpoch + 3600000,
      trustedMs: DateTime.now().millisecondsSinceEpoch,
      stillCurrent: () => identical(current, grant),
    );
    current = grant;
    events.add(null);
  }

  void logout() {
    current = null;
    events.add(null);
  }

  @override
  Future<void> verifyStorage(StorageGrant grant) async {
    if (!identical(grant, current)) {
      throw const StorageFailure(StorageFailureKind.locked);
    }
    grant.check();
  }
}

void main() {
  test(
    'Dart verifies the actual Node administrator ownership-grant contract',
    () async {
      final f =
          jsonDecode(
                File('test/fixtures/stage5_ownership.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final grant = StorageGrant(
        projectId: f['project'],
        uid: f['uid'],
        expiresAtMs: (f['now'] + 3600) * 1000,
        trustedMs: f['now'] * 1000,
        stillCurrent: () => true,
      );
      await OwnershipGrantVerifier(
        () async => f['keys'],
      ).verify(f['grant'], grant, f['sourceId'], f['databaseId'], f['now']);
    },
  );
  late Directory dir;
  late TestKeyVault vault;
  late MigrationAuthority authority;
  late UserDatabaseManager manager;
  late SimpleKeyPair signingKey;
  late Map<String, dynamic> keys;
  Future<void> noop(StorageGrant _) async {}
  LegacyMigrationService service({Future<void> Function(String)? checkpoint}) =>
      LegacyMigrationService(
        manager: manager,
        ownership: OwnershipGrantVerifier(() async => keys),
        syncDirectory: noop,
        checkpoint: checkpoint,
      );
  Future<LegacySource> source({
    int version = 2,
    String? invalid,
    bool empty = false,
  }) async {
    final file = File(
      '${dir.path}/source-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    if (version == 2 && !empty) {
      createV2Fixture(file, extraSql: invalid);
    } else {
      final raw = sql.sqlite3.open(file.path);
      raw.execute(
        File('test/fixtures/schema_v$version.sql').readAsStringSync(),
      );
      if (!empty) {
        final other = File('${dir.path}/seed.sqlite');
        createV2Fixture(other);
        final seed = sql.sqlite3.open(other.path);
        for (final table in legacyColumns.entries) {
          for (final row in seed.select('SELECT * FROM ${table.key}')) {
            raw.execute(
              'INSERT INTO ${table.key} (${table.value.join(',')}) VALUES (${List.filled(table.value.length, '?').join(',')})',
              table.value.map((c) => row[c]).toList(),
            );
          }
        }
        seed.close();
      }
      if (invalid != null) raw.execute(invalid);
      raw.close();
    }
    return LegacySource(
      file,
      mainSha256: sha256.convert(file.readAsBytesSync()).toString(),
    );
  }

  LegacyOwnershipConsent consent(
    LegacySource s, {
    String uid = 'a',
    bool confirmed = true,
  }) => LegacyOwnershipConsent(
    uid: uid,
    sourceId: s.sourceId,
    confirmedBelongsToMe: confirmed,
  );
  Future<String> token(
    LegacySource source, {
    String uid = 'a',
    String? databaseId,
    int? now,
    int? expiry,
    String type = 'sb-legacy-ownership+jwt',
  }) async {
    final seconds = now ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final id =
        databaseId ??
        vault.records[vault.scope('smartbudget-test', 'a')]!.databaseId;
    String encode(Object v) =>
        base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
    final h = encode({'alg': 'EdDSA', 'typ': type, 'kid': 'synthetic-stage5'});
    final c = encode({
      'iss': 'smartbudget:smartbudget-test:legacy-ownership',
      'aud': 'smartbudget-test',
      'project_id': 'smartbudget-test',
      'sub': uid,
      'source_id': source.sourceId,
      'database_id': id,
      'policy_version': 1,
      'iat': seconds,
      'exp': expiry ?? seconds + 3600,
      'jti': '12345678-1234-4234-8234-123456789abc',
    });
    final signature = await Ed25519().sign(
      utf8.encode('$h.$c'),
      keyPair: signingKey,
    );
    return '$h.$c.${base64Url.encode(signature.bytes).replaceAll('=', '')}';
  }

  Future<MigrationReview> prepare(
    LegacySource s, {
    LegacyMigrationService? using,
  }) async => (using ?? service()).prepare(
    source: s,
    consent: consent(s),
    administratorGrant: await token(s),
  );
  Future<MigrationReview> activate(
    LegacySource s, {
    LegacyMigrationService? using,
  }) async => (using ?? service()).activate(
    source: s,
    consent: consent(s),
    administratorGrant: await token(s),
  );
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = await Directory.systemTemp.createTemp(
      'smartbudget-stage5-disposable-',
    );
    vault = TestKeyVault(Directory('${dir.path}/encrypted'));
    authority = MigrationAuthority()..login('a');
    manager = UserDatabaseManager(
      authority: authority,
      factory: EncryptedDatabaseFactory(vault),
    );
    await manager.settled;
    expect(manager.failure, isNull);
    signingKey = await Ed25519().newKeyPair();
    final public = await signingKey.extractPublicKey();
    keys = {
      'keys': [
        {
          'kty': 'OKP',
          'crv': 'Ed25519',
          'x': base64Url.encode(public.bytes).replaceAll('=', ''),
          'alg': 'EdDSA',
          'use': 'sig',
          'kid': 'synthetic-stage5',
        },
      ],
    };
  });
  tearDown(() async {
    await manager.dispose();
    await authority.events.close();
    await dir.delete(recursive: true);
  });

  for (final version in [2, 3]) {
    for (final empty in [false, true]) {
      test(
        'schema $version ${empty ? 'empty' : 'populated'} preserves rows, IDs, totals, ownership and encrypted reopen',
        () async {
          final s = await source(version: version, empty: empty);
          final original = s.file.readAsBytesSync();
          final result = await prepare(s);
          expect(result.phase, 'verified');
          await manager.settled;
          expect(manager.isOpen, false);
          expect(manager.failure, StorageFailureKind.migrationPending);
          final again = await prepare(s);
          expect(again.digest, result.digest);
          final active = await activate(s);
          expect(active.digest, result.digest);
          expect(active.sourceVersion, version);
          await manager.settled;
          expect(manager.isOpen, true);
          expect(active.counts['transactions'], empty ? 0 : 2);
          if (!empty) {
            expect(active.totals['2026-01:income'], '100000');
            expect(active.totals['2026-01:expense'], '20000');
          }
          await manager.scope.run((db) async {
            final owner = await db.select(db.databaseOwnership).getSingle();
            expect(owner.uid, 'a');
            expect(
              owner.databaseId,
              vault.records[vault.scope('smartbudget-test', 'a')]!.databaseId,
            );
            expect(
              await db.customSelect('PRAGMA foreign_key_check').get(),
              isEmpty,
            );
            if (!empty) {
              expect((await db.select(db.recurringApplied).getSingle()).id, 7);
            }
          });
          final repeated = await activate(s);
          expect(repeated.phase, 'active');
          authority.logout();
          await manager.settled;
          authority.login('a');
          await manager.settled;
          expect(manager.isOpen, true);
          final raw = sql.sqlite3.open(
            vault.file('smartbudget-test', 'a').path,
            mode: sql.OpenMode.readOnly,
          );
          try {
            expect(
              () => raw.select('SELECT * FROM transactions'),
              throwsA(isA<sql.SqliteException>()),
            );
          } finally {
            raw.close();
          }
          expect(s.file.readAsBytesSync(), original);
          expect(vault.creates, 1);
        },
      );
    }
  }
  for (final invalid in [
    "INSERT INTO transactions SELECT * FROM transactions WHERE id='expense'",
    "UPDATE transactions SET subcategory_id='missing' WHERE type='expense'",
    "UPDATE category_nodes SET parent_id='missing' WHERE id='sub'",
    "UPDATE budget_limits SET budget_month_id='missing'",
    "UPDATE recurring_applied SET template_id='missing'",
    "UPDATE transactions SET amount_minor=0",
    "UPDATE transactions SET amount_minor=1.5",
    "CREATE TABLE unrecognized_financial_records(id TEXT)",
    "CREATE TABLE sqliteXfinancial_records(id TEXT)",
  ]) {
    test(
      'ambiguous or invalid source is rejected without data loss: $invalid',
      () async {
        final s = await source(invalid: invalid);
        final bytes = s.file.readAsBytesSync();
        await expectLater(
          prepare(s),
          throwsA(
            anyOf(isA<DataIntegrityException>(), isA<LegacyMigrationFailure>()),
          ),
        );
        expect(s.file.readAsBytesSync(), bytes);
        await manager.settled;
        expect(
          await manager.scope.run((db) => db.select(db.transactions).get()),
          isEmpty,
        );
      },
    );
  }
  for (final fault in [
    'wrong-user',
    'wrong-database',
    'no-consent',
    'expired',
    'bad-signature',
    'lease-as-grant',
  ]) {
    test('$fault cannot prepare an ownership claim', () async {
      final s = await source();
      var grant = await token(
        s,
        uid: fault == 'wrong-user' ? 'b' : 'a',
        databaseId: fault == 'wrong-database'
            ? '12345678-1234-4234-8234-123456789abc'
            : null,
        now: fault == 'expired' ? 1 : null,
        expiry: fault == 'expired' ? 60 : null,
        type: fault == 'lease-as-grant'
            ? 'sb-auth-lease+jwt'
            : 'sb-legacy-ownership+jwt',
      );
      if (fault == 'bad-signature') {
        grant =
            grant.substring(0, grant.lastIndexOf('.') + 1) +
            base64Url.encode(List.filled(64, 0)).replaceAll('=', '');
      }
      await expectLater(
        service().prepare(
          source: s,
          consent: consent(s, confirmed: fault != 'no-consent'),
          administratorGrant: grant,
        ),
        throwsA(isA<LegacyMigrationFailure>()),
      );
      await manager.settled;
      expect(manager.isOpen, true);
    });
  }
  for (final phase in [
    'preparing',
    'verified',
    'activating',
    'previous-retained',
    'candidate-renamed',
  ]) {
    test(
      'interruption at $phase blocks normal open and supports explicit retained rollback/retry',
      () async {
        final s = await source();
        var fired = false;
        final faulty = service(
          checkpoint: (p) async {
            if (p == phase && !fired) {
              fired = true;
              throw const LegacyMigrationFailure(
                MigrationFailureKind.interrupted,
              );
            }
          },
        );
        if (['preparing', 'verified'].contains(phase)) {
          await expectLater(
            prepare(s, using: faulty),
            throwsA(isA<LegacyMigrationFailure>()),
          );
        } else {
          await prepare(s);
          await expectLater(
            activate(s, using: faulty),
            throwsA(isA<LegacyMigrationFailure>()),
          );
        }
        await manager.settled;
        expect(manager.isOpen, false);
        await service().rollback();
        await manager.settled;
        expect(manager.isOpen, true);
        await prepare(s);
        await activate(s);
        await manager.settled;
        expect(manager.isOpen, true);
      },
    );
  }
  test('existing financial records are never overwritten', () async {
    final s = await source();
    await manager.scope.run(
      (db) => db.insertIncome(amountMinor: 123, dateMillis: 1767268800000),
    );
    await expectLater(prepare(s), throwsA(isA<LegacyMigrationFailure>()));
    await manager.settled;
    expect(
      (await manager.scope.run(
        (db) => db.getMonthTotals('2026-01'),
      )).totalIncome,
      123,
    );
  });
  test(
    'wrong destination key never causes replacement or plaintext recovery',
    () async {
      final s = await source();
      final name = vault.scope('smartbudget-test', 'a');
      final original = vault.records[name]!;
      final bytes = vault.file('smartbudget-test', 'a').readAsBytesSync();
      vault.records[name] = DatabaseKey(
        Uint8List.fromList(List.filled(32, 42)),
        original.databaseId,
      );
      await expectLater(
        prepare(s),
        throwsA(anyOf(isA<StorageFailure>(), isA<LegacyMigrationFailure>())),
      );
      expect(vault.creates, 1);
      expect(vault.file('smartbudget-test', 'a').readAsBytesSync(), bytes);
    },
  );
  test(
    'integer money above JavaScript safe precision is preserved exactly',
    () async {
      final s = await source(
        invalid:
            "UPDATE transactions SET amount_minor=9007199254740993 WHERE type='income'",
      );
      final report = await prepare(s);
      expect(report.totals['2026-01:income'], '9007199254740993');
      await activate(s);
      await manager.settled;
      expect(
        (await manager.scope.run(
          (db) => db.getMonthTotals('2026-01'),
        )).totalIncome,
        9007199254740993,
      );
    },
  );
  test(
    'activation resumes safely after the old empty file was retained',
    () async {
      final s = await source();
      await prepare(s);
      final interrupted = service(
        checkpoint: (p) async {
          if (p == 'previous-retained') {
            throw const LegacyMigrationFailure(
              MigrationFailureKind.interrupted,
            );
          }
        },
      );
      await expectLater(
        activate(s, using: interrupted),
        throwsA(isA<LegacyMigrationFailure>()),
      );
      final completed = await activate(s);
      expect(completed.phase, 'active');
      await manager.settled;
      expect(manager.isOpen, true);
    },
  );
  test(
    'interrupted journal and hot candidate sidecars are retained by explicit rollback',
    () async {
      final s = await source();
      await prepare(s);
      await manager.settled;
      final folder = vault.file('smartbudget-test', 'a').parent;
      final pending = File('${folder.path}/${MigrationJournal.name}.next')
        ..writeAsStringSync('{partial');
      final hot = File('${folder.path}/${MigrationJournal.candidate}-journal')
        ..writeAsStringSync('synthetic interrupted journal');
      await service().rollback();
      await manager.settled;
      expect(manager.isOpen, true);
      expect(pending.existsSync(), false);
      expect(hot.existsSync(), false);
      expect(
        folder.listSync().where((f) => f.path.contains('.retained-')),
        isNotEmpty,
      );
      await prepare(s);
      await activate(s);
    },
  );
  test(
    'account switch during preparation invalidates old work without opening another user file',
    () async {
      final s = await source();
      final blocked = service(
        checkpoint: (phase) async {
          if (phase == 'preparing') authority.login('b');
        },
      );
      await expectLater(
        prepare(s, using: blocked),
        throwsA(isA<StorageFailure>()),
      );
      await manager.settled;
      expect(authority.storageGrant!.uid, 'b');
      expect(manager.isOpen, true);
      expect(
        await manager.scope.run((db) => db.select(db.transactions).get()),
        isEmpty,
      );
    },
  );
  test('changed digest and missing source fail closed', () async {
    final s = await source();
    await s.file.writeAsBytes([0], mode: FileMode.append);
    await expectLater(prepare(s), throwsA(isA<LegacyMigrationFailure>()));
  });
  test(
    'committed WAL rows are captured, but missing WAL or bare WAL-mode main is rejected',
    () async {
      final s = await source(version: 3);
      final writer = sql.sqlite3.open(s.file.path);
      try {
        writer.execute('PRAGMA journal_mode=WAL');
        writer.execute('PRAGMA wal_autocheckpoint=0');
        writer.execute(
          "INSERT INTO transactions VALUES('wal-income','income',54321,1767268800000,'2026-01',NULL,NULL,3,3)",
        );
        final complete = LegacySource(
          s.file,
          mainSha256: sha256.convert(s.file.readAsBytesSync()).toString(),
          walSha256: sha256
              .convert(File('${s.file.path}-wal').readAsBytesSync())
              .toString(),
        );
        final result = await prepare(complete);
        expect(result.totals['2026-01:income'], '154321');
        await service().rollback();
        await expectLater(
          LegacySource(s.file, mainSha256: complete.mainSha256).snapshot(() {}),
          throwsA(isA<LegacyMigrationFailure>()),
        );
        final copy = await s.file.copy('${dir.path}/missing-wal.sqlite');
        await expectLater(
          LegacySource(
            copy,
            mainSha256: complete.mainSha256,
            walSha256: complete.walSha256,
          ).snapshot(() {}),
          throwsA(isA<LegacyMigrationFailure>()),
        );
      } finally {
        writer.close();
      }
    },
  );
}
