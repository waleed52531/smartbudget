import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import '../db/app_db.dart';
import '../db/sqlite_engine.dart';
import 'database_key_vault.dart';
import 'guarded_executor.dart';
import 'storage_access.dart';
import 'user_storage_lock.dart';
import '../legacy_migration/migration_journal.dart';

class OpenUserDatabase {
  OpenUserDatabase(this.database, this._lock);
  final AppDatabase database;
  final UserStorageLock _lock;
  Future<void>? _closing;
  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    try {
      await database.close();
    } finally {
      await _lock.release();
    }
  }
}

class EncryptedDatabaseFactory {
  EncryptedDatabaseFactory(this.vault);
  final DatabaseKeyVault vault;

  void configureCipher(sql.Database raw, DatabaseKey key) {
    try {
      requireEncryptionCapableSqlite(raw);
      raw.execute("PRAGMA cipher = 'chacha20'");
      if (raw.select('PRAGMA cipher').single.values.single != 'chacha20') {
        throw const StorageFailure(StorageFailureKind.keyUnavailable);
      }
      final hex = key.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      raw.execute("PRAGMA hexkey = '$hex'");
      raw.execute('PRAGMA temp_store = MEMORY');
      raw.execute('PRAGMA foreign_keys = ON');
    } catch (_) {
      // SQLite exceptions can echo key-bearing PRAGMA statements.
      throw const StorageFailure(StorageFailureKind.keyUnavailable);
    }
  }

  void verifyDatabase(sql.Database raw, StorageGrant grant, DatabaseKey key) {
    if (raw.userVersion != 4) {
      throw const StorageFailure(StorageFailureKind.ownership);
    }
    final owners = raw.select('SELECT * FROM database_ownership');
    if (owners.length != 1 ||
        owners.single['id'] != 1 ||
        owners.single['project_id'] != grant.projectId ||
        owners.single['uid'] != grant.uid ||
        owners.single['database_id'] != key.databaseId) {
      throw const StorageFailure(StorageFailureKind.ownership);
    }
    if (raw.select('PRAGMA integrity_check').single.values.single != 'ok' ||
        raw.select('PRAGMA foreign_key_check').isNotEmpty) {
      throw const StorageFailure(StorageFailureKind.damaged);
    }
  }

  void _noLink(String path) {
    if (FileSystemEntity.typeSync(path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw const StorageFailure(StorageFailureKind.damaged);
    }
  }

  /// Identity comes exclusively from the session-scoped manager, never UI input.
  Future<OpenUserDatabase> open(
    StorageGrant grant,
    void Function() check,
  ) async {
    UserStorageLock? lock;
    AppDatabase? database;
    sql.Database? raw;
    DatabaseKey? key;
    try {
      check();
      lock = await UserStorageLock.acquire(vault, grant, check);
      final directory = lock.directory;
      MigrationJournal.requireNormalOpening(directory);
      final file = File('${directory.path}/financial.sqlite');
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        _noLink('${file.path}$suffix');
      }
      final exists = await file.exists();
      final hasKey = await vault.contains(grant.projectId, grant.uid);
      check();
      if (exists != hasKey ||
          (!exists &&
              directory.listSync().any((f) => !f.path.endsWith('/.lock')))) {
        throw const StorageFailure(StorageFailureKind.keyUnavailable);
      }
      key = exists
          ? await vault.load(grant.projectId, grant.uid)
          : await vault.create(grant.projectId, grant.uid);
      check();
      if (exists) {
        // A wrong key/owner never reaches a read-write connection or migration.
        final probe = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
        try {
          configureCipher(probe, key);
          verifyDatabase(probe, grant, key);
        } finally {
          probe.close();
        }
      } else {
        // Keystore/Keychain record was durably created before the first SQL write.
        await file.create(exclusive: true);
      }
      check();
      raw = sql.sqlite3.open(file.path, mode: sql.OpenMode.readWrite);
      configureCipher(raw, key);
      if (exists) verifyDatabase(raw, grant, key);
      raw.execute('PRAGMA journal_mode = DELETE');
      database = AppDatabase.withExecutor(
        NativeDatabase.opened(raw).interceptWith(GuardedExecutor(check)),
      );
      raw = null; // Drift owns and closes this connection from here.
      await database.customSelect('SELECT 1').get();
      if (!exists) {
        await database
            .into(database.databaseOwnership)
            .insert(
              DatabaseOwnershipCompanion.insert(
                id: const Value(1),
                projectId: grant.projectId,
                uid: grant.uid,
                databaseId: key.databaseId,
              ),
            );
      }
      await database.validateIntegrity();
      check();
      final opened = OpenUserDatabase(database, lock);
      database = null;
      lock = null;
      return opened;
    } on StorageFailure {
      rethrow;
    } catch (_) {
      throw const StorageFailure(StorageFailureKind.damaged);
    } finally {
      key?.erase();
      try {
        raw?.close();
        if (database != null) await database.close();
      } finally {
        await lock?.release();
      }
    }
  }
}
