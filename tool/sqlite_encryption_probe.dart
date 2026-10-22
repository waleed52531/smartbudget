import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import 'package:smartbudget/core/db/sqlite_engine.dart';

/// Disposable keys and data only. Never accepts a financial database path.
void configureDisposableCipher(Database database, String hexKey) {
  requireEncryptionCapableSqlite(database);
  try {
    database.execute("PRAGMA cipher = 'chacha20'");
    database.execute("PRAGMA hexkey = '$hexKey'");
  } catch (_) {
    // Do not allow an exception containing a key-setting SQL string to escape.
    throw StateError('Unable to configure the disposable encryption probe.');
  }
}

String disposableKey() {
  final random = Random.secure();
  return List.generate(
    32,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// Uses ordinary conditions, rather than assertions, for release-mode checks.
void runDisposableEncryptionProbe() {
  verifySqliteEncryptionEngine();
  final directory = Directory.systemTemp.createTempSync(
    'smartbudget-synthetic-cipher-',
  );
  try {
    final file = File('${directory.path}/probe.sqlite');
    final key = disposableKey();
    final writer = sqlite3.open(file.path);
    try {
      configureDisposableCipher(writer, key);
      writer.execute(
        'CREATE TABLE probe (id INTEGER PRIMARY KEY, amount_minor INTEGER NOT NULL)',
      );
      writer.execute('INSERT INTO probe VALUES (1, 12345)');
    } finally {
      writer.close();
    }
    final bytes = file.readAsBytesSync();
    if (ascii.decode(bytes.take(16).toList(), allowInvalid: true) ==
        'SQLite format 3\u0000') {
      throw StateError('Synthetic database was written as plaintext.');
    }
    final reopened = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      configureDisposableCipher(reopened, key);
      if (reopened
              .select('SELECT amount_minor FROM probe')
              .single
              .values
              .single !=
          12345) {
        throw StateError(
          'Encrypted reopen did not preserve the synthetic value.',
        );
      }
      if (reopened.select('PRAGMA integrity_check').single.values.single !=
          'ok') {
        throw StateError(
          'Synthetic encrypted database failed integrity checks.',
        );
      }
    } finally {
      reopened.close();
    }
    for (final attemptedKey in [null, disposableKey()]) {
      final invalid = sqlite3.open(file.path, mode: OpenMode.readOnly);
      var rejected = false;
      try {
        if (attemptedKey != null) {
          configureDisposableCipher(invalid, attemptedKey);
        }
        invalid.select('SELECT * FROM probe');
      } on SqliteException {
        rejected = true;
      } finally {
        invalid.close();
      }
      if (!rejected) {
        throw StateError(
          'Encrypted database accepted a missing or incorrect key.',
        );
      }
    }
    final after = file.readAsBytesSync();
    if (bytes.length != after.length ||
        List.generate(
          bytes.length,
          (i) => bytes[i] == after[i],
        ).contains(false)) {
      throw StateError(
        'Read-only key rejection changed the synthetic database.',
      );
    }
  } finally {
    // Only this probe's newly-created synthetic directory is removed.
    directory.deleteSync(recursive: true);
  }
}

void main() {
  runDisposableEncryptionProbe();
  stdout.writeln(
    'PASS: encrypted creation, reopen, integrity, missing/wrong-key rejection; '
    'SQLite ${sqlite3.version}',
  );
}
