import 'dart:math';
import 'package:drift/drift.dart';

import '../../../core/db/app_db.dart';

class ApplyRecurringSummary {
  const ApplyRecurringSummary({
    required this.appliedCount,
    required this.skippedInvalidCount,
    required this.skippedTitles,
  });

  final int appliedCount;
  final int skippedInvalidCount;
  final List<String> skippedTitles;

  bool get hasSkips => skippedInvalidCount > 0;
}

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

  bool _isValidTemplate(String type, String? subcategoryId) {
    if (type == 'expense') {
      return subcategoryId != null && subcategoryId.trim().isNotEmpty;
    }
    return true; // income can be null
  }

  Future<List<RecurringTemplate>> listTemplates() async {
    return db.select(db.recurringTemplates).get();
  }

  /// HARD RULE:
  /// - expense MUST have subcategoryId
  /// - income ignores subcategoryId
  Future<void> upsertTemplate({
    String? id,
    required String title,
    required int amountMinor,
    required String type, // 'expense' | 'income'
    String? subcategoryId,
    String? note,
    required int dayOfMonth,
    bool isActive = true,
  }) async {
    if (type != 'expense' && type != 'income') {
      throw ArgumentError('Recurring type must be "expense" or "income".');
    }

    final fixedTitle = title.trim();
    if (fixedTitle.isEmpty) {
      throw ArgumentError('Title is required.');
    }

    final fixedNote = (note == null || note.trim().isEmpty) ? null : note.trim();

    // block invalid expense templates
    if (!_isValidTemplate(type, subcategoryId)) {
      throw ArgumentError('Expense recurring must have a subcategory selected.');
    }

    // income must never store subcategoryId
    final fixedSubId = (type == 'income') ? null : subcategoryId;

    final now = DateTime.now().millisecondsSinceEpoch;
    final templateId = id ?? _id();

    final existing = await (db.select(db.recurringTemplates)
      ..where((t) => t.id.equals(templateId)))
        .getSingleOrNull();

    if (existing == null) {
      await db.into(db.recurringTemplates).insert(
        RecurringTemplatesCompanion.insert(
          id: templateId,
          title: fixedTitle,
          amountMinor: amountMinor,
          type: type,
          subcategoryId: Value(fixedSubId), // can be null
          note: Value(fixedNote), // can be null
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
          title: Value(fixedTitle),
          amountMinor: Value(amountMinor),
          type: Value(type),
          subcategoryId: Value(fixedSubId), // clears if income
          note: Value(fixedNote),
          dayOfMonth: Value(dayOfMonth),
          isActive: Value(isActive),
        ),
      );
    }
  }

  Future<void> deleteTemplate(String id) async {
    await (db.delete(db.recurringTemplates)..where((t) => t.id.equals(id))).go();
    await (db.delete(db.recurringApplied)..where((a) => a.templateId.equals(id))).go();
  }

  Future<void> toggleActive(String id, bool active) async {
    await (db.update(db.recurringTemplates)..where((t) => t.id.equals(id))).write(
      RecurringTemplatesCompanion(isActive: Value(active)),
    );
  }

  /// ✅ FIX: ignore invalid templates so "pending" doesn’t stay forever
  Future<int> pendingCount(String monthId) async {
    final active = await (db.select(db.recurringTemplates)
      ..where((t) => t.isActive.equals(true)))
        .get();
    if (active.isEmpty) return 0;

    final applied = await (db.select(db.recurringApplied)
      ..where((a) => a.monthId.equals(monthId)))
        .get();
    final appliedIds = applied.map((e) => e.templateId).toSet();

    // ✅ ignore invalid templates so pending count is honest
    final validActive = active.where((t) => _isValidTemplate(t.type, t.subcategoryId));

    return validActive.where((t) => !appliedIds.contains(t.id)).length;
  }


  /// Returns summary so UI can show "applied X, skipped Y invalid"
  Future<ApplyRecurringSummary> applyToMonth(String monthId) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    var appliedCount = 0;
    final skippedTitles = <String>[];

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

        // ✅ guard: skip broken expense templates (prevents CHECK constraint crash)
        if (!_isValidTemplate(t.type, t.subcategoryId)) {
          skippedTitles.add(t.title);
          continue;
        }

        final whenMillis = _dateMillisForMonth(monthId, t.dayOfMonth);

        await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            monthId: monthId,
            amountMinor: t.amountMinor,
            type: t.type,
            dateMillis: whenMillis,

            // ✅ MUST satisfy your Transactions CHECK constraint
            subcategoryId: t.type == 'expense'
                ? Value(t.subcategoryId!) // safe due to guard
                : const Value(null),

            note: Value(t.note ?? '[Recurring] ${t.title}'),

            // optional but recommended: keep update timestamps consistent
            updatedAt: Value(now),
            // createdAt: Value(now), // optional; can omit because clientDefault exists
          ),
        );

        await db.into(db.recurringApplied).insert(
          RecurringAppliedCompanion.insert(
            templateId: t.id,
            monthId: monthId,
            appliedAtMillis: now,
          ),
        );

        appliedCount++;
      }

    });

    return ApplyRecurringSummary(
      appliedCount: appliedCount,
      skippedInvalidCount: skippedTitles.length,
      skippedTitles: skippedTitles,
    );
  }
}
