import 'package:drift/drift.dart';
import '../../../core/db/app_db.dart';
import '../../../core/utils/month_id.dart';

class TransactionRepository {
  TransactionRepository(this.db);
  final AppDatabase db;

  Future<List<Transaction>> listByMonth(String monthId) {
    return (db.select(db.transactions)
      ..where((t) => t.monthId.equals(monthId))
      ..orderBy([(t) => OrderingTerm.desc(t.dateMillis)]))
        .get();
  }

  Future<void> addExpense({
    required int amountMinor,
    required int dateMillis,
    required String subcategoryId,
    String? note,
  }) async {
    final mId = monthIdFromMillis(dateMillis);
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        type: 'expense',
        amountMinor: amountMinor,
        dateMillis: dateMillis,
        monthId: mId,
        subcategoryId: Value(subcategoryId),
        note: Value(note),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> addIncome({
    required int amountMinor,
    required int dateMillis,
    String? note,
  }) async {
    final mId = monthIdFromMillis(dateMillis);
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        type: 'income',
        amountMinor: amountMinor,
        dateMillis: dateMillis,
        monthId: mId,
        subcategoryId: const Value(null),
        note: Value(note),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await (db.delete(db.transactions)..where((t) => t.id.equals(id))).go();
  }
}
