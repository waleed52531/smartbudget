import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import '../db/app_db.dart';
import '../user_storage/user_storage_lock.dart';
import 'migration_journal.dart';

const legacyColumns = <String, List<String>>{
  'category_nodes': [
    'id',
    'name',
    'type',
    'parent_id',
    'archived',
    'sort_order',
    'icon',
    'color',
  ],
  'budget_months': [
    'id',
    'currency',
    'total_budget_minor',
    'saving_target_minor',
    'created_at',
  ],
  'budget_limits': ['id', 'budget_month_id', 'node_id', 'limit_minor'],
  'transactions': [
    'id',
    'type',
    'amount_minor',
    'date_millis',
    'month_id',
    'subcategory_id',
    'note',
    'created_at',
    'updated_at',
  ],
  'recurring_templates': [
    'id',
    'title',
    'amount_minor',
    'type',
    'subcategory_id',
    'note',
    'day_of_month',
    'is_active',
    'created_at_millis',
  ],
  'recurring_applied': ['id', 'template_id', 'month_id', 'applied_at_millis'],
};

/// A standalone Online Backup snapshot, or a complete, stable DB/WAL bundle.
/// Digests must come from the reviewed backup manifest, not guessed from a path.
class LegacySource {
  const LegacySource(this.file, {required this.mainSha256, this.walSha256});
  final File file;
  final String mainSha256;
  final String? walSha256;
  String get sourceId =>
      sha256.convert(utf8.encode('$mainSha256:${walSha256 ?? ''}')).toString();
  Future<void> verifyBytes() async {
    for (final hash in [mainSha256, if (walSha256 != null) walSha256!]) {
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
        throw const LegacyMigrationFailure(MigrationFailureKind.source);
      }
    }
    rejectStorageLink(file.path);
    if (!await file.exists() ||
        (await sha256.bind(file.openRead()).first).toString() != mainSha256) {
      throw const LegacyMigrationFailure(MigrationFailureKind.source);
    }
    final wal = File('${file.path}-wal');
    for (final suffix in ['-wal', '-shm', '-journal']) {
      rejectStorageLink('${file.path}$suffix');
    }
    final header = await file.open();
    late List<int> bytes;
    try {
      bytes = await header.read(100);
    } finally {
      await header.close();
    }
    if (bytes.length != 100 ||
        utf8.decode(bytes.take(16).toList(), allowMalformed: true) !=
            'SQLite format 3\u0000' ||
        File('${file.path}-journal').existsSync()) {
      throw const LegacyMigrationFailure(MigrationFailureKind.source);
    }
    if (walSha256 == null) {
      // A copied WAL-mode main file cannot prove that committed pages are present.
      if (wal.existsSync() || bytes[18] == 2 || bytes[19] == 2) {
        throw const LegacyMigrationFailure(MigrationFailureKind.source);
      }
    } else if (!wal.existsSync() ||
        !File('${file.path}-shm').existsSync() ||
        (await sha256.bind(wal.openRead()).first).toString() != walSha256) {
      throw const LegacyMigrationFailure(MigrationFailureKind.source);
    }
  }

  Future<LegacyData> snapshot(void Function() check) async {
    check();
    await verifyBytes();
    check();
    sql.Database? memory = sql.sqlite3.openInMemory();
    sql.Database? source;
    AppDatabase? migrated;
    try {
      source = sql.sqlite3.open(file.path, mode: sql.OpenMode.readOnly);
      source.execute('PRAGMA query_only=ON');
      source.execute('PRAGMA trusted_schema=OFF');
      source.execute('PRAGMA temp_store=MEMORY');
      source.execute('BEGIN');
      source.select('SELECT count(*) FROM sqlite_master');
      await for (final _ in source.backup(memory, nPage: 64)) {
        check();
      }
      source.execute('ROLLBACK');
      source.close();
      source = null;
      await verifyBytes();
      check();
      memory.execute('PRAGMA trusted_schema=OFF');
      memory.execute('PRAGMA temp_store=MEMORY');
      final version = memory.userVersion;
      if (version != 2 && version != 3) {
        throw const LegacyMigrationFailure(MigrationFailureKind.source);
      }
      if (memory.select('PRAGMA integrity_check').single.values.single !=
          'ok') {
        throw const LegacyMigrationFailure(MigrationFailureKind.source);
      }
      final objects = memory.select(
        "SELECT type,name FROM sqlite_master WHERE name NOT GLOB 'sqlite_*'",
      );
      if (objects.any(
            (r) =>
                !(r['type'] == 'table' &&
                    legacyColumns.containsKey(r['name'])) &&
                !(r['type'] == 'index' && r['name'] == 'category_names'),
          ) ||
          objects.where((r) => r['type'] == 'table').length !=
              legacyColumns.length) {
        throw const LegacyMigrationFailure(MigrationFailureKind.conflicts);
      }
      for (final table in legacyColumns.entries) {
        final names = memory
            .select('PRAGMA table_info(${table.key})')
            .map((r) => r['name'])
            .toSet();
        if (names.length != table.value.length ||
            !names.containsAll(table.value)) {
          throw const LegacyMigrationFailure(MigrationFailureKind.conflicts);
        }
      }
      final before = LegacyData.read(memory, version);
      migrated = AppDatabase.withExecutor(NativeDatabase.opened(memory));
      memory = null;
      await migrated
          .customSelect('SELECT 1')
          .get(); // Existing approved v2/v3 -> v4 migrations.
      await migrated.validateIntegrity();
      if ((await migrated.customSelect('PRAGMA foreign_key_check').get())
          .isNotEmpty) {
        throw const LegacyMigrationFailure(MigrationFailureKind.verification);
      }
      final after = await LegacyData.fromDrift(migrated, version);
      if (before.digest != after.digest) {
        throw const LegacyMigrationFailure(MigrationFailureKind.verification);
      }
      check();
      return after;
    } on DataIntegrityException {
      rethrow;
    } on LegacyMigrationFailure {
      rethrow;
    } catch (_) {
      throw const LegacyMigrationFailure(MigrationFailureKind.conflicts);
    } finally {
      source?.close();
      memory?.close();
      await migrated?.close();
    }
  }
}

/// Full typed row fingerprint, including IDs, notes and recurring sequence state.
/// Records stay in memory; journals persist only the fingerprint, never totals.
class LegacyData {
  LegacyData(this.rows, this.sequence, this.sourceVersion);
  final Map<String, List<Map<String, Object?>>> rows;
  final int sequence, sourceVersion;
  static LegacyData read(sql.Database db, int version) => LegacyData(
    {
      for (final t in legacyColumns.entries)
        t.key: db
            .select('SELECT ${t.value.join(',')} FROM ${t.key} ORDER BY id')
            .map((r) => Map<String, Object?>.from(r))
            .toList(),
    },
    db
                .select(
                  "SELECT seq FROM sqlite_sequence WHERE name='recurring_applied'",
                )
                .firstOrNull?['seq']
            as int? ??
        0,
    version,
  )..validateTypes();
  static Future<LegacyData> fromDrift(AppDatabase db, int version) async {
    final rows = <String, List<Map<String, Object?>>>{};
    for (final t in legacyColumns.entries) {
      rows[t.key] =
          (await db
                  .customSelect(
                    'SELECT ${t.value.join(',')} FROM ${t.key} ORDER BY id',
                  )
                  .get())
              .map((r) => r.data)
              .toList();
    }
    final sequence = await db
        .customSelect(
          "SELECT seq FROM sqlite_sequence WHERE name='recurring_applied'",
        )
        .getSingleOrNull();
    return LegacyData(rows, sequence?.read<int>('seq') ?? 0, version)
      ..validateTypes();
  }

  void validateTypes() {
    const integers = {
      'archived',
      'sort_order',
      'color',
      'total_budget_minor',
      'saving_target_minor',
      'created_at',
      'limit_minor',
      'amount_minor',
      'date_millis',
      'updated_at',
      'day_of_month',
      'is_active',
      'created_at_millis',
      'applied_at_millis',
    };
    for (final table in rows.entries) {
      for (final row in table.value) {
        for (final cell in row.entries) {
          final value = cell.value;
          if (value != null &&
              ((integers.contains(cell.key) ||
                      (table.key == 'recurring_applied' && cell.key == 'id'))
                  ? value is! int
                  : value is! String)) {
            throw const LegacyMigrationFailure(MigrationFailureKind.conflicts);
          }
        }
      }
    }
  }

  String get digest => sha256
      .convert(utf8.encode(jsonEncode({'rows': rows, 'sequence': sequence})))
      .toString();
  Map<String, int> get counts => rows.map((k, v) => MapEntry(k, v.length));
  Map<String, String> get totals {
    final result = <String, BigInt>{};
    void add(String name, Object? amount) => result.update(
      name,
      (v) => v + BigInt.from(amount as int),
      ifAbsent: () => BigInt.from(amount as int),
    );
    for (final row in rows['transactions']!) {
      add('${row['month_id']}:${row['type']}', row['amount_minor']);
    }
    for (final row in rows['budget_months']!) {
      add('budget', row['total_budget_minor']);
      add('savingTarget', row['saving_target_minor']);
    }
    for (final row in rows['budget_limits']!) {
      add('limits', row['limit_minor']);
    }
    for (final row in rows['recurring_templates']!) {
      add('recurring:${row['type']}', row['amount_minor']);
    }
    return result.map((k, v) => MapEntry(k, v.toString()));
  }
}
