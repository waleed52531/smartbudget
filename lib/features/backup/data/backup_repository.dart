import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_db.dart';

enum RestoreMode { merge, overwrite }

class BackupRepository {
  BackupRepository(this.db);
  final AppDatabase db;

  Future<File> exportBackupJson() async {
    final now = DateTime.now();

    // Export tables (add/remove based on your DB)
    final nodes = await db.select(db.categoryNodes).get();
    final months = await db.select(db.budgetMonths).get();
    final limits = await db.select(db.budgetLimits).get();
    final tx = await db.select(db.transactions).get();
    final recTpl = await db.select(db.recurringTemplates).get();
    final recApplied = await db.select(db.recurringApplied).get();

    final payload = <String, dynamic>{
      'format': 'monthly_budget_backup',
      'version': 1,
      'exportedAt': now.toIso8601String(),
      'schemaVersion': db.schemaVersion,
      'tables': {
        'categoryNodes': nodes.map((e) => e.toJson()).toList(),
        'budgetMonths': months.map((e) => e.toJson()).toList(),
        'budgetLimits': limits.map((e) => e.toJson()).toList(),
        'transactions': tx.map((e) => e.toJson()).toList(),
        'recurringTemplates': recTpl.map((e) => e.toJson()).toList(),
        'recurringApplied': recApplied.map((e) => e.toJson()).toList(),
      },
    };

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/budget_backup_${now.millisecondsSinceEpoch}.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    return file;
  }

  Future<void> restoreFromJsonFile({
    required File file,
    required RestoreMode mode,
  }) async {
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid backup file');
    }
    if (decoded['format'] != 'monthly_budget_backup') {
      throw Exception('Not a Monthly Budget backup');
    }

    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw Exception('Backup tables missing');
    }

    // Read lists
    final List<dynamic> nodes = (tables['categoryNodes'] as List<dynamic>? ?? []);
    final List<dynamic> months = (tables['budgetMonths'] as List<dynamic>? ?? []);
    final List<dynamic> limits = (tables['budgetLimits'] as List<dynamic>? ?? []);
    final List<dynamic> tx = (tables['transactions'] as List<dynamic>? ?? []);
    final List<dynamic> recTpl = (tables['recurringTemplates'] as List<dynamic>? ?? []);
    final List<dynamic> recApplied = (tables['recurringApplied'] as List<dynamic>? ?? []);

    await db.transaction(() async {
      if (mode == RestoreMode.overwrite) {
        // Delete children first (FK-safe order)
        await db.delete(db.recurringApplied).go();
        await db.delete(db.recurringTemplates).go();
        await db.delete(db.transactions).go();
        await db.delete(db.budgetLimits).go();
        await db.delete(db.budgetMonths).go();
        await db.delete(db.categoryNodes).go();
      }

      // Insert parent tables first
      // Insert parent tables first
      for (final m in nodes) {
        final row = CategoryNode.fromJson(m as Map<String, dynamic>);
        await db.into(db.categoryNodes).insert(row, mode: InsertMode.insertOrReplace);
      }

      for (final m in months) {
        final row = BudgetMonth.fromJson(m as Map<String, dynamic>);
        await db.into(db.budgetMonths).insert(row, mode: InsertMode.insertOrReplace);
      }

      for (final m in limits) {
        final row = BudgetLimit.fromJson(m as Map<String, dynamic>);
        await db.into(db.budgetLimits).insert(row, mode: InsertMode.insertOrReplace);
      }

      for (final m in tx) {
        final row = Transaction.fromJson(m as Map<String, dynamic>);
        await db.into(db.transactions).insert(row, mode: InsertMode.insertOrReplace);
      }

      for (final m in recTpl) {
        final row = RecurringTemplate.fromJson(m as Map<String, dynamic>);
        await db.into(db.recurringTemplates).insert(row, mode: InsertMode.insertOrReplace);
      }

      for (final m in recApplied) {
        final row = RecurringAppliedRow.fromJson(m as Map<String, dynamic>);
        await db.into(db.recurringApplied).insert(row, mode: InsertMode.insertOrReplace);
      }

    });
  }
}
