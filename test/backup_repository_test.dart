import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/db/app_db.dart';
import 'package:smartbudget/features/backup/data/backup_repository.dart';

void main() {
  late AppDatabase db;
  late BackupRepository repo;
  late Directory dir;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    repo = BackupRepository(db);
    dir = await Directory.systemTemp.createTemp('smartbudget-backup-');
    await db.seedDefaultsIfEmpty();
    await db.ensureBudgetMonthExists('2026-01');
    await db.insertExpense(
      amountMinor: 12345,
      dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
      subcategoryId: 'sub_groceries_milk',
    );
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  Future<void> restore(Map<String, dynamic> payload, RestoreMode mode) async {
    final file = File('${dir.path}/synthetic.json');
    await file.writeAsString(jsonEncode(payload));
    await repo.restoreFromJsonFile(file: file, mode: mode);
  }

  Future<dynamic> tables() async => (await repo.exportPayload())['tables'];

  for (final mode in RestoreMode.values) {
    for (final version in [2, 3, 4]) {
      test('schema $version backup restores idempotently with $mode', () async {
        final payload = await repo.exportPayload();
        payload['schemaVersion'] = version;
        final before = await tables();
        await restore(payload, mode);
        await restore(payload, mode);
        expect(await tables(), before);
        expect((await db.getMonthTotals('2026-01')).totalSpent, 12345);
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      });
    }
  }
  final bad = <String, void Function(Map<String, dynamic>)>{
    'missing table': (p) => (p['tables'] as Map).remove('transactions'),
    'unsupported schema': (p) => p['schemaVersion'] = 99,
    'unsupported format': (p) => p['version'] = 99,
    'duplicate ID': (p) {
      final tx = p['tables']['transactions'] as List;
      tx.add(Map<String, dynamic>.from(tx.first));
    },
    'orphan reference': (p) =>
        p['tables']['transactions'][0]['subcategoryId'] = 'missing',
    'wrong category type': (p) =>
        p['tables']['transactions'][0]['subcategoryId'] = 'cat_groceries',
    'negative amount': (p) =>
        p['tables']['transactions'][0]['amountMinor'] = -1,
    'incomplete row': (p) =>
        (p['tables']['transactions'][0] as Map).remove('note'),
  };
  for (final entry in bad.entries) {
    for (final mode in RestoreMode.values) {
      test(
        '${entry.key} rejected without changing destination in $mode',
        () async {
          final before = await tables();
          final payload = await repo.exportPayload();
          entry.value(payload);
          await expectLater(restore(payload, mode), throwsA(anything));
          expect(await tables(), before);
        },
      );
    }
  }
  test(
    'merge conflict rolls back earlier inserts and preserves local records',
    () async {
      final before = await tables();
      final payload = await repo.exportPayload();
      payload['tables']['categoryNodes'].add({
        'id': 'extra',
        'name': 'Synthetic extra',
        'type': 'category',
        'parentId': null,
        'archived': false,
        'sortOrder': 0,
        'icon': null,
        'color': null,
      });
      payload['tables']['transactions'][0]['amountMinor'] = 999;
      await expectLater(
        restore(payload, RestoreMode.merge),
        throwsA(isA<DataIntegrityException>()),
      );
      expect(await tables(), before);
    },
  );
  test('overwrite retains children instead of replacement cascades', () async {
    await db.customStatement(
      "INSERT INTO recurring_templates VALUES ('tpl','Synthetic',500,'expense','sub_groceries_milk',NULL,1,1,1)",
    );
    await db.customStatement(
      "INSERT INTO recurring_applied VALUES (4,'tpl','2026-01',1)",
    );
    final payload = await repo.exportPayload();
    await restore(payload, RestoreMode.overwrite);
    expect(await db.select(db.recurringApplied).get(), hasLength(1));
    expect(await db.select(db.budgetMonths).get(), hasLength(1));
    expect(await db.select(db.transactions).get(), hasLength(1));
  });
}
