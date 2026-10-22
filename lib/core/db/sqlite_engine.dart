import 'package:sqlite3/sqlite3.dart';

/// Rejects a plaintext-only library in debug and release before financial SQL.
/// This checks the engine; applying per-user keys belongs to the storage stage.
void requireEncryptionCapableSqlite(Database database) {
  if (database.select('PRAGMA cipher').isEmpty) {
    throw StateError('The required encrypted SQLite engine is unavailable.');
  }
}

/// Checks packaging without creating or opening a financial database file.
void verifySqliteEncryptionEngine() {
  final database = sqlite3.openInMemory();
  try {
    requireEncryptionCapableSqlite(database);
  } finally {
    database.close();
  }
}
