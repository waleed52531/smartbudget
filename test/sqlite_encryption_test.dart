import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/db/app_db.dart';

import '../tool/sqlite_encryption_probe.dart';

void main() {
  test('native engine encrypts and rejects missing/incorrect keys', () {
    runDisposableEncryptionProbe();
  });

  test(
    'Drift schema 4 and financial totals survive encrypted reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'smartbudget-synthetic-drift-cipher-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/synthetic.sqlite');
      final key = disposableKey();
      AppDatabase open() => AppDatabase.withExecutor(
        NativeDatabase(
          file,
          setup: (raw) => configureDisposableCipher(raw, key),
        ),
      );
      var database = open();
      try {
        await database.seedDefaultsIfEmpty();
        await database.insertIncome(
          amountMinor: 12345,
          dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
        );
      } finally {
        await database.close();
      }
      database = open();
      try {
        expect(database.schemaVersion, 4);
        expect((await database.getMonthTotals('2026-01')).totalIncome, 12345);
        expect(
          await database.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        expect(
          (await database.customSelect('PRAGMA integrity_check').getSingle())
              .data,
          {'integrity_check': 'ok'},
        );
      } finally {
        await database.close();
      }
    },
  );
}
