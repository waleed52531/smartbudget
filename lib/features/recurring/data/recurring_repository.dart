import 'dart:math';
import 'package:drift/drift.dart';

import '../../../core/db/app_db.dart';

class RecurringRepository {
  RecurringRepository(this.db);
  final AppDatabase db;

  String _id() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';

  DateTime _monthStart(String monthId) {
    final y = int.parse(monthId.substring(0, 4));
    final m = int.parse(monthId.substring(5, 7));
    return DateTime(y, m, 1);
  }

  int _dateMillisForMonth(String monthId, int dayOfMonth) {
    final start = _monthStart(monthId);
    final daysInMonth = DateTime(start.year, start.month + 1, 0).day;
    final day = dayOfMonth.clamp(1, daysInMonth);
    final dt = DateTime(start.year, start.month, day, 12, 0);
    return dt.millisecondsSinceEpoch;
  }

  Future<List<RecurringTemplate>> listTemplates() async {
    return db.select(db.recurringTemplates).get();
  }

  Future<void> upsertTemplate({
    String? id,
    required String title,
    required int amountMinor,
    required String type, // 'expense'/'income'
    String? subcategoryId, // ✅ FIX
    String? note,
    required int dayOfMonth,
    bool isActive = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final templateId = id ?? _id();

    final existing = await (db.select(db.recurringTemplates)
      ..where((t) => t.id.equals(templateId)))
        .getSingleOrNull();

    if (existing == null) {
      await db.into(db.recurringTemplates).insert(
        RecurringTemplatesCompanion.insert(
          id: templateId,
          title: title,
          amountMinor: amountMinor,
          type: type,
          subcategoryId: subcategoryId == null
              ? const Value.absent()
              : Value(subcategoryId), // ✅ FIX
          note: note == null ? const Value.absent() : Value(note),
          dayOfMonth: Value(dayOfMonth),
          isActive: Value(isActive),
          createdAtMillis: now,
        ),
      );
    } else {
      await (db.update(db.recurringTemplates)
        ..where((t) => t.id.equals(templateId)))
          .write(
        RecurringTemplatesCompanion(
          title: Value(title),
          amountMinor: Value(amountMinor),
          type: Value(type),
          subcategoryId: Value(subcategoryId), // ✅ FIX
          note: Value(note),
          dayOfMonth: Value(dayOfMonth),
          isActive: Value(isActive),
        ),
      );
    }
  }

  Future<void> deleteTemplate(String id) async {
    await (db.delete(db.recurringTemplates)
      ..where((t) => t.id.equals(id)))
        .go();

    await (db.delete(db.recurringApplied)
      ..where((a) => a.templateId.equals(id)))
        .go();
  }

  Future<void> toggleActive(String id, bool active) async {
    await (db.update(db.recurringTemplates)
      ..where((t) => t.id.equals(id)))
        .write(
      RecurringTemplatesCompanion(isActive: Value(active)),
    );
  }

  Future<int> pendingCount(String monthId) async {
    final active = await (db.select(db.recurringTemplates)
      ..where((t) => t.isActive.equals(true)))
        .get();
    if (active.isEmpty) return 0;

    final applied = await (db.select(db.recurringApplied)
      ..where((a) => a.monthId.equals(monthId)))
        .get();
    final appliedIds = applied.map((e) => e.templateId).toSet();

    return active.where((t) => !appliedIds.contains(t.id)).length;
  }

  Future<void> applyToMonth(String monthId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      final templates = await (db.select(db.recurringTemplates)
        ..where((t) => t.isActive.equals(true)))
          .get();

      if (templates.isEmpty) return;

      final applied = await (db.select(db.recurringApplied)
        ..where((a) => a.monthId.equals(monthId)))
          .get();
      final appliedIds = applied.map((e) => e.templateId).toSet();

      for (final t in templates) {
        if (appliedIds.contains(t.id)) continue;

        // ✅ Insert transaction matching YOUR Transactions table
        await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            type: t.type,
            amountMinor: t.amountMinor,
            dateMillis: _dateMillisForMonth(monthId, t.dayOfMonth),
            monthId: monthId,
            subcategoryId: t.subcategoryId == null
                ? const Value.absent()
                : Value(t.subcategoryId!), // ✅ FIX
            note: Value(t.note ?? '[Recurring] ${t.title}'),
            updatedAt: Value(now),
          ),
        );

        // mark applied (prevents duplicates)
        await db.into(db.recurringApplied).insert(
          RecurringAppliedCompanion.insert(
            templateId: t.id,
            monthId: monthId,
            appliedAtMillis: now,
          ),
        );
      }
    });
  }
}
