import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/db/app_db.dart';
import 'package:sqlite3/sqlite3.dart';
import 'support/v2_fixture.dart';

void main() {
  late Directory dir;
  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    dir = await Directory.systemTemp.createTemp('smartbudget-migration-');
  });
  tearDown(() => dir.delete(recursive: true));

  test(
    'v2 upgrade preserves every row, monthly totals, and persistence',
    () async {
      final file = File('${dir.path}/fixture.sqlite');
      createV2Fixture(file);
      final backup = await file.copy('${dir.path}/fixture.pre-upgrade.sqlite');
      final before = snapshot(backup);
      var db = AppDatabase.withExecutor(NativeDatabase(file));
      final totals = await db.getMonthTotals('2026-01');
      expect(totals.totalIncome, 100000);
      expect(totals.totalSpent, 20000);
      expect(
        (await db.customSelect('PRAGMA foreign_keys').getSingle()).read<int>(
          'foreign_keys',
        ),
        1,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      await db.close();
      expect(snapshot(file), before);
      expect(snapshot(backup), before);
      final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
      expect(raw.userVersion, 4);
      raw.close();
      db = AppDatabase.withExecutor(NativeDatabase(file));
      expect((await db.getMonthTotals('2026-01')).totalSpent, 20000);
      expect((await db.select(db.recurringApplied).getSingle()).id, 7);
      await db.close();
    },
  );

  final invalid = <String, String>{
    'duplicate transaction IDs':
        "INSERT INTO transactions SELECT * FROM transactions WHERE id='expense'",
    'duplicate category IDs':
        "INSERT INTO category_nodes (id,name,type) VALUES ('cat','Different name','category')",
    'duplicate budget limit IDs':
        "INSERT INTO budget_limits VALUES ('limit','2026-01','archived',100)",
    'duplicate category names':
        "INSERT INTO category_nodes (id,name,type) VALUES ('cat2','Synthetic category','category')",
    'orphan expense':
        "UPDATE transactions SET subcategory_id='missing' WHERE type='expense'",
    'orphan category parent':
        "UPDATE category_nodes SET parent_id='missing' WHERE id='sub'",
    'wrong category type':
        "UPDATE transactions SET subcategory_id='cat' WHERE type='expense'",
    'orphan budget': "UPDATE budget_limits SET budget_month_id='missing'",
    'orphan recurring category':
        "UPDATE recurring_templates SET subcategory_id='missing'",
    'orphan recurring application':
        "UPDATE recurring_applied SET template_id='missing'",
    'negative transaction': 'UPDATE transactions SET amount_minor=-1',
    'zero transaction': 'UPDATE transactions SET amount_minor=0',
    'negative budget': 'UPDATE budget_months SET total_budget_minor=-1',
    'negative limit': 'UPDATE budget_limits SET limit_minor=-1',
    'invalid recurring day': 'UPDATE recurring_templates SET day_of_month=32',
  };
  for (final entry in invalid.entries) {
    test('${entry.key} blocks migration without changing v2 data', () async {
      final file = File('${dir.path}/invalid.sqlite');
      createV2Fixture(file, extraSql: entry.value);
      final backup = await file.copy('${dir.path}/invalid.pre-upgrade.sqlite');
      final db = AppDatabase.withExecutor(NativeDatabase(file));
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(isA<DataIntegrityException>()),
      );
      await db.close();
      expect(snapshot(file), snapshot(backup));
      final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
      expect(raw.userVersion, 2);
      expect(
        raw.select(
          "SELECT name FROM sqlite_master WHERE name LIKE 'tmp_for_copy_%'",
        ),
        isEmpty,
      );
      raw.close();
    });
  }

  test(
    'failure after table rebuild rolls back schema, data, and version',
    () async {
      final file = File('${dir.path}/late-failure.sqlite');
      createV2Fixture(
        file,
        extraSql: 'CREATE INDEX category_names ON budget_months(id)',
      );
      final backup = await file.copy(
        '${dir.path}/late-failure.pre-upgrade.sqlite',
      );
      final db = AppDatabase.withExecutor(NativeDatabase(file));
      await expectLater(
        db.customSelect('SELECT 1').get(),
        throwsA(isA<SqliteException>()),
      );
      await db.close();
      expect(snapshot(file), snapshot(backup));
      final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
      expect(raw.userVersion, 2);
      expect(
        raw
            .select('PRAGMA table_info(transactions)')
            .every((r) => r['pk'] == 0),
        isTrue,
      );
      raw.close();
    },
  );

  test('new database enforces keys, references, and amount checks', () async {
    final db = AppDatabase.withExecutor(NativeDatabase.memory());
    addTearDown(db.close);
    await db.seedDefaultsIfEmpty();
    await db.ensureBudgetMonthExists('2026-01');
    await db.insertIncome(
      amountMinor: 100,
      dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
    );
    final row = await db.select(db.transactions).getSingle();
    await expectLater(
      db.into(db.transactions).insert(row),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO category_nodes (id,name,type) VALUES ('cat_groceries','Different','category')",
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO category_nodes (id,name,type) VALUES ('other-id','Groceries','category')",
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO category_nodes (id,name,type,parent_id) VALUES ('orphan','Orphan','subcategory','missing')",
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement("UPDATE transactions SET amount_minor=0"),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO budget_limits VALUES ('bad','2026-01','missing',100)",
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO budget_limits VALUES ('bad','missing','cat_groceries',100)",
      ),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      db.customStatement(
        "UPDATE transactions SET type='expense',subcategory_id='missing'",
      ),
      throwsA(isA<SqliteException>()),
    );
    for (final table in ['category_nodes', 'budget_limits', 'transactions']) {
      final columns = await db.customSelect('PRAGMA table_info($table)').get();
      expect(
        columns.singleWhere((r) => r.read<int>('pk') == 1).read<String>('name'),
        'id',
      );
    }
    await db.validateIntegrity();
  });
}
