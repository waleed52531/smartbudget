import 'package:drift/drift.dart';
import '../../../core/db/app_db.dart';

/// How to copy previous month values into the target month.
enum CopyMode {
  /// Copy only missing values:
  /// - Month totals: only if target totals are 0
  /// - Limits: only if a limit row doesn't already exist
  mergeMissingOnly,

  /// Replace everything in target month:
  /// - Month totals overwritten
  /// - All limits deleted then re-inserted from previous month
  overwriteAll,
}

class BudgetRepository {
  BudgetRepository(this.db);
  final AppDatabase db;

  Future<BudgetMonth> getOrCreateMonth(String monthId) async {
    final existing = await (db.select(db.budgetMonths)
      ..where((m) => m.id.equals(monthId)))
        .getSingleOrNull();

    if (existing != null) return existing;

    await db.into(db.budgetMonths).insert(
      BudgetMonthsCompanion.insert(
        id: monthId,
        totalBudgetMinor: const Value(0),
        savingTargetMinor: const Value(0),
      ),
    );

    return (db.select(db.budgetMonths)..where((m) => m.id.equals(monthId)))
        .getSingle();
  }

  Future<void> updateMonthBudget({
    required String monthId,
    required int totalBudgetMinor,
    required int savingTargetMinor,
  }) async {
    await (db.update(db.budgetMonths)..where((m) => m.id.equals(monthId))).write(
      BudgetMonthsCompanion(
        totalBudgetMinor: Value(totalBudgetMinor),
        savingTargetMinor: Value(savingTargetMinor),
      ),
    );
  }

  Future<int?> getCategoryLimit(String monthId, String categoryId) async {
    final row = await (db.select(db.budgetLimits)
      ..where((b) =>
      b.budgetMonthId.equals(monthId) & b.nodeId.equals(categoryId)))
        .getSingleOrNull();
    return row?.limitMinor;
  }

  /// Upsert category limit.
  Future<void> upsertCategoryLimit({
    required String monthId,
    required String categoryId,
    required int limitMinor,
  }) async {
    final existing = await (db.select(db.budgetLimits)
      ..where((b) =>
      b.budgetMonthId.equals(monthId) & b.nodeId.equals(categoryId)))
        .getSingleOrNull();

    if (existing == null) {
      await db.into(db.budgetLimits).insert(
        BudgetLimitsCompanion.insert(
          budgetMonthId: monthId,
          nodeId: categoryId,
          limitMinor: limitMinor,
        ),
      );
    } else {
      await (db.update(db.budgetLimits)..where((b) => b.id.equals(existing.id)))
          .write(
        BudgetLimitsCompanion(limitMinor: Value(limitMinor)),
      );
    }
  }

  /// Clear limit (remove row)
  Future<void> clearCategoryLimit(String monthId, String categoryId) async {
    await (db.delete(db.budgetLimits)
      ..where((b) =>
      b.budgetMonthId.equals(monthId) & b.nodeId.equals(categoryId)))
        .go();
  }

  /// ✅ Step 14: Copy previous month budget (totals + limits) into [monthId].
  Future<void> copyFromPreviousMonth({
    required String monthId,
    required CopyMode mode,
  }) async {
    final prevId = _previousMonthId(monthId);

    await db.transaction(() async {
      // previous month must exist
      final prevMonth = await (db.select(db.budgetMonths)
        ..where((m) => m.id.equals(prevId)))
          .getSingleOrNull();

      if (prevMonth == null) {
        throw Exception('No budget found for previous month ($prevId)');
      }

      final prevLimits = await (db.select(db.budgetLimits)
        ..where((l) => l.budgetMonthId.equals(prevId)))
          .get();

      final targetMonth = await (db.select(db.budgetMonths)
        ..where((m) => m.id.equals(monthId)))
          .getSingleOrNull();

      // Ensure target month exists
      if (targetMonth == null) {
        await db.into(db.budgetMonths).insert(
          BudgetMonthsCompanion.insert(
            id: monthId,
            totalBudgetMinor: Value(prevMonth.totalBudgetMinor),
            savingTargetMinor: Value(prevMonth.savingTargetMinor),
          ),
        );
      }

      if (mode == CopyMode.overwriteAll) {
        // overwrite month totals
        await (db.update(db.budgetMonths)..where((m) => m.id.equals(monthId)))
            .write(
          BudgetMonthsCompanion(
            totalBudgetMinor: Value(prevMonth.totalBudgetMinor),
            savingTargetMinor: Value(prevMonth.savingTargetMinor),
          ),
        );

        // wipe target limits then copy
        await (db.delete(db.budgetLimits)
          ..where((l) => l.budgetMonthId.equals(monthId)))
            .go();

        for (final l in prevLimits) {
          await db.into(db.budgetLimits).insert(
            BudgetLimitsCompanion.insert(
              budgetMonthId: monthId,
              nodeId: l.nodeId,
              limitMinor: l.limitMinor,
            ),
          );
        }
        return;
      }

      // mergeMissingOnly:
      final current = await (db.select(db.budgetMonths)
        ..where((m) => m.id.equals(monthId)))
          .getSingle();

      final fillTotal = current.totalBudgetMinor == 0;
      final fillSaving = current.savingTargetMinor == 0;

      if (fillTotal || fillSaving) {
        await (db.update(db.budgetMonths)..where((m) => m.id.equals(monthId)))
            .write(
          BudgetMonthsCompanion(
            totalBudgetMinor: Value(
              fillTotal ? prevMonth.totalBudgetMinor : current.totalBudgetMinor,
            ),
            savingTargetMinor: Value(
              fillSaving
                  ? prevMonth.savingTargetMinor
                  : current.savingTargetMinor,
            ),
          ),
        );
      }

      // copy only missing limits
      final existingTargetLimits = await (db.select(db.budgetLimits)
        ..where((l) => l.budgetMonthId.equals(monthId)))
          .get();

      final existingNodeIds = existingTargetLimits.map((e) => e.nodeId).toSet();

      for (final l in prevLimits) {
        if (existingNodeIds.contains(l.nodeId)) continue;

        await db.into(db.budgetLimits).insert(
          BudgetLimitsCompanion.insert(
            budgetMonthId: monthId,
            nodeId: l.nodeId,
            limitMinor: l.limitMinor,
          ),
        );
      }
    });
  }

  Future<Map<String, int>> getLimitsForMonth(String monthId) async {
    final rows = await (db.select(db.budgetLimits)
      ..where((b) => b.budgetMonthId.equals(monthId)))
        .get();

    return {for (final r in rows) r.nodeId: r.limitMinor};
  }


  String _previousMonthId(String monthId) {
    final y = int.parse(monthId.substring(0, 4));
    final m = int.parse(monthId.substring(5, 7));
    final prev = DateTime(y, m - 1, 1); // wraps year automatically

    final yy = prev.year.toString().padLeft(4, '0');
    final mm = prev.month.toString().padLeft(2, '0');
    return '$yy-$mm';
  }
}
