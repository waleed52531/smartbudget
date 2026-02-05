import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_db.dart';

class ExportRepository {
  ExportRepository(this.db);
  final AppDatabase db;

  Future<File> exportMonthCsv({required String monthId}) async {
    // Fetch all transactions for month
    final tx = await (db.select(db.transactions)..where((t) => t.monthId.equals(monthId))).get();

    // Build a map for subcategory -> (subcategoryName, categoryName)
    final subIds = tx.where((t) => t.subcategoryId != null).map((t) => t.subcategoryId!).toSet();
    final subRows = subIds.isEmpty
        ? <CategoryNode>[]
        : await (db.select(db.categoryNodes)..where((n) => n.id.isIn(subIds))).get();

    final parentIds = subRows.map((s) => s.parentId).whereType<String>().toSet();
    final parentRows = parentIds.isEmpty
        ? <CategoryNode>[]
        : await (db.select(db.categoryNodes)..where((n) => n.id.isIn(parentIds))).get();

    final subById = {for (final s in subRows) s.id: s};
    final catById = {for (final c in parentRows) c.id: c};

    final rows = <List<dynamic>>[];
    rows.add(['date', 'type', 'amount_minor', 'month', 'category', 'subcategory', 'note']);

    for (final t in tx) {
      final dt = DateTime.fromMillisecondsSinceEpoch(t.dateMillis).toLocal();
      final sub = t.subcategoryId == null ? null : subById[t.subcategoryId!];
      final cat = (sub?.parentId == null) ? null : catById[sub!.parentId!];

      rows.add([
        dt.toIso8601String(),
        t.type,
        t.amountMinor,
        t.monthId,
        cat?.name ?? '',
        sub?.name ?? '',
        t.note ?? '',
      ]);
    }

    final csvText = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/monthly_budget_$monthId.csv');
    await file.writeAsString(csvText, flush: true);
    return file;
  }
}
