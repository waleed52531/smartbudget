import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/db/app_db.dart';

class ExportRepository {
  ExportRepository(this.db);
  final AppDatabase db;

  /// Default export = whole month
  Future<File> exportMonthCsv({required String monthId}) async {
    return exportFilteredCsv(monthId: monthId);
  }

  /// Export month with optional filters
  Future<File> exportFilteredCsv({
    required String monthId,
    String? query,
    String? type, // 'expense' | 'income'
    String? subcategoryId,
    int? minMinor,
    int? maxMinor,
  }) async {
    // Fetch all transactions for month
    final all = await (db.select(db.transactions)..where((t) => t.monthId.equals(monthId))).get();

    // Apply filters in Dart (simple + stable)
    final q = (query ?? '').trim().toLowerCase();

    final tx = all.where((t) {
      if (type != null && type.isNotEmpty && t.type != type) return false;

      // Only expenses have subcategoryId (income has null by DB constraint)
      if (subcategoryId != null && subcategoryId.isNotEmpty) {
        if (t.subcategoryId == null || t.subcategoryId != subcategoryId) return false;
      }

      if (minMinor != null && t.amountMinor < minMinor) return false;
      if (maxMinor != null && t.amountMinor > maxMinor) return false;

      if (q.isNotEmpty) {
        final note = (t.note ?? '').toLowerCase();
        final amountText = t.amountMinor.toString();
        final typeText = t.type.toLowerCase();

        if (!note.contains(q) && !amountText.contains(q) && !typeText.contains(q)) {
          return false;
        }
      }

      return true;
    }).toList();

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
    final safeMonth = monthId.replaceAll(':', '-');

    final fileName = (query == null && type == null && subcategoryId == null && minMinor == null && maxMinor == null)
        ? 'monthly_budget_$safeMonth.csv'
        : 'monthly_budget_${safeMonth}_filtered.csv';

    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvText, flush: true);
    return file;
  }
}
