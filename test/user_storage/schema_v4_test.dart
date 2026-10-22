import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:smartbudget/core/db/app_db.dart';
import '../support/v2_fixture.dart';

void main() {
  for (final version in [2, 3]) {
    for (final fail in [false, true]) {
      test(
        'copied v$version fixture ${fail ? 'rollback' : 'upgrade'} preserves records and never assigns ownership',
        () async {
          final dir = await Directory.systemTemp.createTemp(
            'smartbudget-synthetic-v4-migration-',
          );
          addTearDown(() => dir.delete(recursive: true));
          final v2 = File('${dir.path}/v2.sqlite');
          createV2Fixture(v2);
          final file = File('${dir.path}/working.sqlite');
          if (version == 2) {
            await v2.copy(file.path);
          } else {
            final records = snapshot(v2);
            final raw = sqlite3.open(file.path);
            try {
              raw.execute(
                File('test/fixtures/schema_v3.sql').readAsStringSync(),
              );
              for (final table in tableNames) {
                for (final row in records[table]!) {
                  raw.execute(
                    'INSERT INTO $table (${row.keys.join(',')}) VALUES (${List.filled(row.length, '?').join(',')})',
                    row.values.toList(),
                  );
                }
              }
            } finally {
              raw.close();
            }
          }
          if (fail) {
            final raw = sqlite3.open(file.path);
            // Simulates an unexpected schema conflict late in the upgrade.
            raw.execute(
              'CREATE TRIGGER ownership_no_update BEFORE UPDATE ON transactions BEGIN SELECT 1; END',
            );
            raw.close();
          }
          final backup = await file.copy('${dir.path}/pre-upgrade.sqlite');
          final bytesBefore = backup.readAsBytesSync();
          final before = snapshot(backup);
          final db = AppDatabase.withExecutor(NativeDatabase(file));
          try {
            if (fail) {
              await expectLater(
                db.customSelect('SELECT 1').get(),
                throwsA(isA<SqliteException>()),
              );
            } else {
              expect((await db.getMonthTotals('2026-01')).totalIncome, 100000);
              expect((await db.getMonthTotals('2026-01')).totalSpent, 20000);
              expect(await db.select(db.databaseOwnership).get(), isEmpty);
              expect(
                await db.customSelect('PRAGMA foreign_key_check').get(),
                isEmpty,
              );
              expect(
                (await db.customSelect('PRAGMA integrity_check').getSingle())
                    .data,
                {'integrity_check': 'ok'},
              );
            }
          } finally {
            await db.close();
          }
          expect(snapshot(file), before);
          expect(backup.readAsBytesSync(), bytesBefore);
          final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
          try {
            expect(raw.userVersion, fail ? version : 4);
          } finally {
            raw.close();
          }
          if (fail) {
            // Rollback is performed only by opening the untouched copied fixture.
            expect(snapshot(backup), before);
          }
        },
      );
    }
  }
}
