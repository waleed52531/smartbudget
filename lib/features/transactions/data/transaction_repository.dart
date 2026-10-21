import 'package:drift/drift.dart';
import '../../../core/db/app_db.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month_id.dart';

class TransactionRepository {
  TransactionRepository(this.db);
  final AppDatabase db;

  int _validatedDateMillis(int dateMillis, String monthId) {
    if (monthIdFromMillis(dateMillis) != monthId) {
      throw ArgumentError(
        'Transaction date must belong to the selected month.',
      );
    }
    return dateMillis;
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
    requirePositiveAmount(amountMinor);
    await db.validateSubcategory(subcategoryId);
    final safeDate = _validatedDateMillis(dateMillis, monthId);

    await db
        .into(db.transactions)
        .insert(
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
    requirePositiveAmount(amountMinor);
    final safeDate = _validatedDateMillis(dateMillis, monthId);

    await db
        .into(db.transactions)
        .insert(
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
    requirePositiveAmount(amountMinor);
    if (type != 'expense' && type != 'income') {
      throw ArgumentError('Invalid transaction type.');
    }
    if (type == 'expense') {
      if (subcategoryId == null) throw ArgumentError('Select a subcategory.');
      await db.validateSubcategory(subcategoryId);
    } else if (subcategoryId != null) {
      throw ArgumentError('Income cannot have an expense subcategory.');
    }
    final safeDate = _validatedDateMillis(dateMillis, monthId);

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
