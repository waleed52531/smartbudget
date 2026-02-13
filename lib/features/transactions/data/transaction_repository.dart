import 'package:drift/drift.dart';
import '../../../core/db/app_db.dart';

class TransactionRepository {
  TransactionRepository(this.db);
  final AppDatabase db;

  DateTime _monthStart(String monthId) {
    final y = int.parse(monthId.substring(0, 4));
    final m = int.parse(monthId.substring(5, 7));
    return DateTime(y, m, 1);
  }

  int _clampDateMillisToMonth(int dateMillis, String monthId) {
    final start = _monthStart(monthId);
    final end = DateTime(start.year, start.month + 1, 0);

    final dt = DateTime.fromMillisecondsSinceEpoch(dateMillis).toLocal();
    final daysInMonth = end.day;
    final day = dt.day.clamp(1, daysInMonth);

    // Force the SAME monthId, clamp only the day; keep time
    final clamped = DateTime(
      start.year,
      start.month,
      day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );

    return clamped.millisecondsSinceEpoch;
  }

  Future<List<Transaction>> listByMonth(String monthId) {
    return (db.select(db.transactions)
      ..where((t) => t.monthId.equals(monthId))
      ..orderBy([(t) => OrderingTerm.desc(t.dateMillis)]))
        .get();
  }

  Future<void> addExpense({
    required String monthId,
    required int amountMinor,
    required int dateMillis,
    required String subcategoryId,
    String? note,
  }) async {
    final safeDate = _clampDateMillisToMonth(dateMillis, monthId);

    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        type: 'expense',
        amountMinor: amountMinor,
        dateMillis: safeDate,
        monthId: monthId,
        subcategoryId: Value(subcategoryId),
        note: note == null ? const Value.absent() : Value(note),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> addIncome({
    required String monthId,
    required int amountMinor,
    required int dateMillis,
    String? note,
  }) async {
    final safeDate = _clampDateMillisToMonth(dateMillis, monthId);

    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        type: 'income',
        amountMinor: amountMinor,
        dateMillis: safeDate,
        monthId: monthId,
        subcategoryId: const Value(null),
        note: note == null ? const Value.absent() : Value(note),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> updateTransaction({
    required String id,
    required String type,
    required int amountMinor,
    required int dateMillis,
    required String monthId,
    required String? subcategoryId,
    required String? note,
  }) async {
    final safeDate = _clampDateMillisToMonth(dateMillis, monthId);

    await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        type: Value(type),
        amountMinor: Value(amountMinor),
        dateMillis: Value(safeDate),
        monthId: Value(monthId),
        subcategoryId: Value(subcategoryId),
        note: Value(note),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
  }
}
