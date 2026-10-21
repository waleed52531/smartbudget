import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_db.dart';

enum RestoreMode { merge, overwrite }

class BackupRepository {
  BackupRepository(this.db);
  final AppDatabase db;

  Future<Map<String, dynamic>> exportPayload() => db.transaction(
    () async => {
      'format': 'monthly_budget_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'schemaVersion': db.schemaVersion,
      'tables': {
        'categoryNodes': (await db.select(db.categoryNodes).get())
            .map((e) => e.toJson())
            .toList(),
        'budgetMonths': (await db.select(db.budgetMonths).get())
            .map((e) => e.toJson())
            .toList(),
        'budgetLimits': (await db.select(db.budgetLimits).get())
            .map((e) => e.toJson())
            .toList(),
        'transactions': (await db.select(db.transactions).get())
            .map((e) => e.toJson())
            .toList(),
        'recurringTemplates': (await db.select(db.recurringTemplates).get())
            .map((e) => e.toJson())
            .toList(),
        'recurringApplied': (await db.select(db.recurringApplied).get())
            .map((e) => e.toJson())
            .toList(),
      },
    },
  );

  Future<File> exportBackupJson() async {
    final payload = await exportPayload();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/budget_backup_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return file;
  }

  Future<void> restoreFromJsonFile({
    required File file,
    required RestoreMode mode,
  }) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'monthly_budget_backup') {
      throw const FormatException('Not a Smart Budget backup.');
    }
    if (decoded['version'] != 1 || ![2, 3].contains(decoded['schemaVersion'])) {
      throw const FormatException(
        'Unsupported backup format or database version.',
      );
    }
    final tables = decoded['tables'];
    const names = {
      'categoryNodes',
      'budgetMonths',
      'budgetLimits',
      'transactions',
      'recurringTemplates',
      'recurringApplied',
    };
    if (tables is! Map<String, dynamic> ||
        tables.length != names.length ||
        !tables.keys.toSet().containsAll(names)) {
      throw const FormatException(
        'Backup must contain all six tables. Nothing restored.',
      );
    }

    final nodes = _decode(tables['categoryNodes'], CategoryNode.fromJson)
      ..sort((a, b) => a.type.compareTo(b.type));
    final months = _decode(tables['budgetMonths'], BudgetMonth.fromJson);
    final limits = _decode(tables['budgetLimits'], BudgetLimit.fromJson);
    final tx = _decode(tables['transactions'], Transaction.fromJson);
    final templates = _decode(
      tables['recurringTemplates'],
      RecurringTemplate.fromJson,
    );
    final applied = _decode(
      tables['recurringApplied'],
      RecurringAppliedRow.fromJson,
    );

    Future<void> writeRows(AppDatabase target, {bool merge = false}) async {
      await _insert(target, target.categoryNodes, nodes, merge: merge);
      await _insert(target, target.budgetMonths, months, merge: merge);
      await _insert(target, target.budgetLimits, limits, merge: merge);
      await _insert(target, target.transactions, tx, merge: merge);
      await _insert(target, target.recurringTemplates, templates, merge: merge);
      await _insert(target, target.recurringApplied, applied, merge: merge);
      await target.validateIntegrity();
    }

    // Validate the entire standalone backup before touching the destination.
    final staging = AppDatabase.withExecutor(NativeDatabase.memory());
    try {
      await staging.transaction(() => writeRows(staging));
    } finally {
      await staging.close();
    }

    await db.transaction(() async {
      if (mode == RestoreMode.overwrite) {
        await db.delete(db.recurringApplied).go();
        await db.delete(db.recurringTemplates).go();
        await db.delete(db.transactions).go();
        await db.delete(db.budgetLimits).go();
        await db.delete(db.budgetMonths).go();
        await db.delete(db.categoryNodes).go();
      }
      await writeRows(db, merge: mode == RestoreMode.merge);
    });
  }
}

List<D> _decode<D extends DataClass>(
  dynamic value,
  D Function(Map<String, dynamic>) decode,
) {
  if (value is! List) {
    throw const FormatException('Backup table must be a list.');
  }
  return value.map((raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup row.');
    }
    final row = decode(raw);
    final keys = row.toJson().keys.toSet();
    if (raw.length != keys.length || !raw.keys.toSet().containsAll(keys)) {
      throw const FormatException('Incomplete or unsupported backup row.');
    }
    return row;
  }).toList();
}

Future<void> _insert<T extends Table, D extends DataClass>(
  AppDatabase db,
  TableInfo<T, D> table,
  List<D> rows, {
  required bool merge,
}) async {
  final existing = merge
      ? {
          for (final row in await db.select(table).get())
            row.toJson()['id']: row,
        }
      : <dynamic, D>{};
  for (final row in rows) {
    final previous = existing[row.toJson()['id']];
    if (previous != null) {
      if (previous.toJsonString() != row.toJsonString()) {
        throw DataIntegrityException([
          'Conflicting records in ${table.actualTableName}; choose a resolution before restoring',
        ]);
      }
      continue;
    }
    await db.into(table).insert(row as Insertable<D>);
  }
}
