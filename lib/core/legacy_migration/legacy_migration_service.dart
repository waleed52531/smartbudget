import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:uuid/uuid.dart';
import '../db/app_db.dart';
import '../user_storage/database_key_vault.dart';
import '../user_storage/user_database_manager.dart';
import '../user_storage/storage_access.dart';
import '../user_storage/user_storage_lock.dart';
import 'legacy_source.dart';
import 'migration_journal.dart';
import 'ownership_grant.dart';

class MigrationReview {
  const MigrationReview(
    this.sourceId,
    this.databaseId,
    this.sourceVersion,
    this.counts,
    this.totals,
    this.digest,
    this.phase,
  );
  final String sourceId, databaseId, digest, phase;
  final int sourceVersion;
  final Map<String, int> counts;
  final Map<String, String> totals;
}

/// No UID selector or production-data shortcut. Session identity and SQLite key
/// come from the same verified manager used by the rest of the app.
/// Preparing never activates; activation is a separate explicit call.
class LegacyMigrationService {
  LegacyMigrationService({
    required this.manager,
    required this.ownership,
    this.syncDirectory = nativeMigrationSync,
    this.checkpoint,
  });
  final UserDatabaseManager manager;
  final OwnershipGrantVerifier ownership;
  final MigrationSync syncDirectory;
  // Fault injection for disposable tests; not selectable by an import request.
  final Future<void> Function(String phase)? checkpoint;

  Future<T> _exclusive<T>(
    Future<T> Function(StorageGrant, void Function(), Directory, DatabaseKey)
    action, {
    bool rollbackArtifacts = false,
  }) => manager.maintenance((grant, check) async {
    final lock = await UserStorageLock.acquire(
      manager.factory.vault,
      grant,
      check,
    );
    DatabaseKey? key;
    try {
      check();
      key = await manager.factory.vault.load(grant.projectId, grant.uid);
      check();
      for (final name in [
        'financial.sqlite',
        MigrationJournal.candidate,
        MigrationJournal.previous,
      ]) {
        for (final suffix in ['', '-wal', '-shm', '-journal']) {
          rejectStorageLink('${lock.directory.path}/$name$suffix');
          if (suffix.isNotEmpty &&
              !(rollbackArtifacts && name == MigrationJournal.candidate) &&
              File('${lock.directory.path}/$name$suffix').existsSync()) {
            throw const LegacyMigrationFailure(
              MigrationFailureKind.interrupted,
            );
          }
        }
      }
      return await action(grant, check, lock.directory, key);
    } on StorageFailure {
      rethrow;
    } on DataIntegrityException {
      rethrow;
    } on LegacyMigrationFailure {
      rethrow;
    } catch (_) {
      throw const LegacyMigrationFailure(MigrationFailureKind.verification);
    } finally {
      key?.erase();
      await lock.release();
    }
  });

  File _file(Directory directory, String name) =>
      File('${directory.path}/$name');
  LegacyData _verifyFile(File file, StorageGrant grant, DatabaseKey key) {
    if (!file.existsSync()) {
      throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
    }
    final raw = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
    try {
      manager.factory.configureCipher(raw, key);
      manager.factory.verifyDatabase(raw, grant, key);
      return LegacyData.read(raw, 4);
    } finally {
      raw.close();
    }
  }

  void _empty(File file, StorageGrant grant, DatabaseKey key) {
    if (_verifyFile(file, grant, key).counts.values.any((n) => n != 0)) {
      throw const LegacyMigrationFailure(MigrationFailureKind.destination);
    }
  }

  void _bind(
    Map<String, dynamic> journal,
    StorageGrant grant,
    DatabaseKey key,
  ) {
    if (journal['scope'] != storageScope(grant.projectId, grant.uid) ||
        journal['databaseId'] != key.databaseId) {
      throw const LegacyMigrationFailure(MigrationFailureKind.ownership);
    }
  }

  void _consent(
    LegacyOwnershipConsent consent,
    StorageGrant grant,
    LegacySource source,
  ) {
    if (!consent.confirmedBelongsToMe ||
        consent.uid != grant.uid ||
        consent.sourceId != source.sourceId) {
      throw const LegacyMigrationFailure(MigrationFailureKind.ownership);
    }
  }

  Future<void> _authorized(
    String token,
    StorageGrant grant,
    void Function() check,
    LegacySource source,
    DatabaseKey key,
    LegacyOwnershipConsent consent,
  ) async {
    check();
    _consent(consent, grant, source);
    await manager.authority.verifyStorage(grant);
    check();
    await ownership.verify(
      token,
      grant,
      source.sourceId,
      key.databaseId,
      grant.trustedNowMs ~/ 1000,
    );
    check();
  }

  Future<void> _phase(
    Directory directory,
    Map<String, dynamic> journal,
    String phase,
    StorageGrant grant,
  ) async {
    journal['phase'] = phase;
    await MigrationJournal.write(directory, journal, grant, syncDirectory);
    await checkpoint?.call(phase);
  }

  MigrationReview _review(
    LegacySource source,
    DatabaseKey key,
    LegacyData data,
    String phase, {
    int? sourceVersion,
  }) => MigrationReview(
    source.sourceId,
    key.databaseId,
    sourceVersion ?? data.sourceVersion,
    data.counts,
    data.totals,
    data.digest,
    phase,
  );

  /// Review is aggregate-only and never imports rows. Explicit ownership consent
  /// is still required; an administrator grant is required before preparation.
  Future<MigrationReview> review(
    LegacySource source,
    LegacyOwnershipConsent consent,
  ) => _exclusive((grant, check, directory, key) async {
    _consent(consent, grant, source);
    check();
    _empty(_file(directory, 'financial.sqlite'), grant, key);
    final data = await source.snapshot(check);
    return _review(source, key, data, 'review');
  });

  Future<MigrationReview> prepare({
    required LegacySource source,
    required LegacyOwnershipConsent consent,
    required String administratorGrant,
  }) => _exclusive((grant, check, directory, key) async {
    await _authorized(administratorGrant, grant, check, source, key, consent);
    await source.verifyBytes();
    check();
    final existing = MigrationJournal.read(directory);
    if (existing != null) {
      _bind(existing, grant, key);
      if (existing['sourceId'] != source.sourceId) {
        throw const LegacyMigrationFailure(MigrationFailureKind.conflicts);
      }
      if (existing['phase'] == 'active' || existing['phase'] == 'verified') {
        final data = _verifyFile(
          _file(
            directory,
            existing['phase'] == 'active'
                ? 'financial.sqlite'
                : MigrationJournal.candidate,
          ),
          grant,
          key,
        );
        if (existing['phase'] == 'verified' &&
            data.digest != existing['digest']) {
          throw const LegacyMigrationFailure(MigrationFailureKind.verification);
        }
        return _review(
          source,
          key,
          data,
          existing['phase'],
          sourceVersion: existing['sourceVersion'] as int,
        );
      }
      if (existing['phase'] != 'rolledBack') {
        throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
      }
    }
    _empty(_file(directory, 'financial.sqlite'), grant, key);
    if (_file(directory, MigrationJournal.candidate).existsSync() ||
        _file(directory, MigrationJournal.previous).existsSync()) {
      throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
    }
    final data = await source.snapshot(check);
    final journal = <String, dynamic>{
      'version': 1,
      'scope': storageScope(grant.projectId, grant.uid),
      'databaseId': key.databaseId,
      'sourceId': source.sourceId,
      'sourceVersion': data.sourceVersion,
      'digest': data.digest,
      'phase': 'preparing',
    };
    await _phase(directory, journal, 'preparing', grant);
    check();
    final candidate = _file(directory, MigrationJournal.candidate);
    await candidate.create(exclusive: true);
    final raw = sql.sqlite3.open(candidate.path, mode: sql.OpenMode.readWrite);
    AppDatabase? db;
    try {
      manager.factory.configureCipher(raw, key);
      raw.execute('PRAGMA journal_mode=DELETE');
      raw.execute('PRAGMA synchronous=FULL');
      db = AppDatabase.withExecutor(NativeDatabase.opened(raw));
      await db.customSelect('SELECT 1').get();
      await db.transaction(() async {
        await db!.customStatement('PRAGMA defer_foreign_keys=ON');
        await db
            .into(db.databaseOwnership)
            .insert(
              DatabaseOwnershipCompanion.insert(
                id: const Value(1),
                projectId: grant.projectId,
                uid: grant.uid,
                databaseId: key.databaseId,
              ),
            );
        for (final table in legacyColumns.entries) {
          for (final row in data.rows[table.key]!) {
            check();
            await db.customStatement(
              'INSERT INTO ${table.key} (${table.value.join(',')}) VALUES (${List.filled(table.value.length, '?').join(',')})',
              table.value.map((c) => row[c]).toList(),
            );
          }
        }
        await db.customStatement(
          "DELETE FROM sqlite_sequence WHERE name='recurring_applied'",
        );
        await db.customStatement(
          "INSERT INTO sqlite_sequence(name,seq) VALUES('recurring_applied',?)",
          [data.sequence],
        );
        await db.validateIntegrity();
        check();
        await manager.authority.verifyStorage(grant);
        check();
      });
    } finally {
      if (db != null) {
        await db.close();
      } else {
        raw.close();
      }
    }
    await syncDirectory(grant);
    check();
    if (_verifyFile(candidate, grant, key).digest != data.digest) {
      throw const LegacyMigrationFailure(MigrationFailureKind.verification);
    }
    // An ordinary SQLite open and an independently wrong key must both fail.
    for (final wrong in [false, true]) {
      final probe = sql.sqlite3.open(
        candidate.path,
        mode: sql.OpenMode.readOnly,
      );
      try {
        if (wrong) {
          probe.execute("PRAGMA cipher='chacha20'");
          probe.execute("PRAGMA hexkey='${List.filled(64, '0').join()}'");
        }
        var rejected = false;
        try {
          probe.select('SELECT count(*) FROM sqlite_master');
        } catch (_) {
          rejected = true;
        }
        if (!rejected) {
          throw const LegacyMigrationFailure(MigrationFailureKind.verification);
        }
      } finally {
        probe.close();
      }
    }
    await _authorized(administratorGrant, grant, check, source, key, consent);
    await _phase(directory, journal, 'verified', grant);
    return _review(source, key, data, 'verified');
  });

  Future<MigrationReview> activate({
    required LegacySource source,
    required LegacyOwnershipConsent consent,
    required String administratorGrant,
  }) => _exclusive((grant, check, directory, key) async {
    await _authorized(administratorGrant, grant, check, source, key, consent);
    await source.verifyBytes();
    check();
    final journal = MigrationJournal.read(directory);
    if (journal == null) {
      throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
    }
    _bind(journal, grant, key);
    if (journal['sourceId'] != source.sourceId) {
      throw const LegacyMigrationFailure(MigrationFailureKind.conflicts);
    }
    final live = _file(directory, 'financial.sqlite'),
        candidate = _file(directory, MigrationJournal.candidate),
        previous = _file(directory, MigrationJournal.previous);
    if (journal['phase'] == 'active') {
      return _review(
        source,
        key,
        _verifyFile(live, grant, key),
        'active',
        sourceVersion: journal['sourceVersion'] as int,
      );
    }
    if (!{'verified', 'activating'}.contains(journal['phase'])) {
      throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
    }
    if (journal['phase'] == 'verified') {
      _empty(live, grant, key);
      if (previous.existsSync()) {
        throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
      }
      if (_verifyFile(candidate, grant, key).digest != journal['digest']) {
        throw const LegacyMigrationFailure(MigrationFailureKind.verification);
      }
      await _phase(directory, journal, 'activating', grant);
    }
    check();
    if (!previous.existsSync()) {
      _empty(live, grant, key);
      if (!candidate.existsSync()) {
        throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
      }
      await live.rename(previous.path);
      await syncDirectory(grant);
      await checkpoint?.call('previous-retained');
      check();
    }
    _empty(previous, grant, key);
    if (!live.existsSync()) {
      if (_verifyFile(candidate, grant, key).digest != journal['digest']) {
        throw const LegacyMigrationFailure(MigrationFailureKind.verification);
      }
      await candidate.rename(live.path);
      await syncDirectory(grant);
      await checkpoint?.call('candidate-renamed');
      check();
    } else if (candidate.existsSync()) {
      throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
    }
    final data = _verifyFile(live, grant, key);
    if (data.digest != journal['digest']) {
      throw const LegacyMigrationFailure(MigrationFailureKind.verification);
    }
    await _authorized(administratorGrant, grant, check, source, key, consent);
    await _phase(directory, journal, 'active', grant);
    return _review(
      source,
      key,
      data,
      'active',
      sourceVersion: journal['sourceVersion'] as int,
    );
  });

  /// Explicit pre-activation rollback retains every staging artifact. No source,
  /// key, or encrypted record is deleted. An active migration needs human review.
  Future<void> rollback() => _exclusive((grant, check, directory, key) async {
    final next = _file(directory, '${MigrationJournal.name}.next');
    if (next.existsSync()) {
      rejectStorageLink(next.path);
      await next.rename('${next.path}.retained-${const Uuid().v4()}');
      await syncDirectory(grant);
    }
    final journal = MigrationJournal.read(directory);
    if (journal != null) {
      _bind(journal, grant, key);
      if (journal['phase'] == 'active') {
        throw const LegacyMigrationFailure(MigrationFailureKind.conflicts);
      }
    }
    final live = _file(directory, 'financial.sqlite'),
        candidate = _file(directory, MigrationJournal.candidate),
        previous = _file(directory, MigrationJournal.previous);
    if (previous.existsSync()) {
      _empty(previous, grant, key);
      if (live.existsSync()) {
        if (journal == null ||
            candidate.existsSync() ||
            _verifyFile(live, grant, key).digest != journal['digest']) {
          throw const LegacyMigrationFailure(MigrationFailureKind.conflicts);
        }
        await live.rename('${live.path}.retained-${const Uuid().v4()}');
        await syncDirectory(grant);
        check();
      }
      await previous.rename(live.path);
      await syncDirectory(grant);
      check();
    }
    _empty(live, grant, key);
    if (candidate.existsSync()) {
      final retained = '${candidate.path}.retained-${const Uuid().v4()}';
      await candidate.rename(retained);
      for (final suffix in ['-journal', '-wal', '-shm']) {
        final sidecar = File('${candidate.path}$suffix');
        if (sidecar.existsSync()) {
          await sidecar.rename('$retained$suffix');
        }
      }
      await syncDirectory(grant);
    }
    if (journal != null) await _phase(directory, journal, 'rolledBack', grant);
  }, rollbackArtifacts: true);
}
