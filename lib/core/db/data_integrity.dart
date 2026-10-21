part of 'app_db.dart';

/// Only diagnostic labels/counts are exposed; financial records stay untouched.
class DataIntegrityException implements Exception {
  const DataIntegrityException(this.issues);
  final List<String> issues;

  @override
  String toString() =>
      'Data needs review; no records were changed. ${issues.join('; ')}';
}

Future<void> _validateStoredData(AppDatabase db) async {
  final checks = <String, String>{
    for (final table in [
      'category_nodes',
      'budget_months',
      'budget_limits',
      'transactions',
      'recurring_templates',
      'recurring_applied',
    ])
      'Duplicate IDs in $table':
          'SELECT COUNT(*) AS n FROM (SELECT id FROM $table GROUP BY id HAVING COUNT(*) > 1)',
    'Duplicate category names':
        "SELECT COUNT(*) AS n FROM (SELECT name FROM category_nodes WHERE type = 'category' GROUP BY name HAVING COUNT(*) > 1)",
    'Duplicate subcategory names':
        "SELECT COUNT(*) AS n FROM (SELECT name, parent_id FROM category_nodes WHERE type = 'subcategory' GROUP BY name, parent_id HAVING COUNT(*) > 1)",
    'Invalid category parents':
        "SELECT COUNT(*) AS n FROM category_nodes n LEFT JOIN category_nodes p ON p.id = n.parent_id WHERE (n.type = 'subcategory' AND (p.id IS NULL OR p.type <> 'category')) OR (n.type = 'category' AND n.parent_id IS NOT NULL)",
    'Invalid expense categories':
        "SELECT COUNT(*) AS n FROM transactions t LEFT JOIN category_nodes n ON n.id = t.subcategory_id WHERE (t.type = 'expense' AND (n.id IS NULL OR n.type <> 'subcategory')) OR (t.type = 'income' AND t.subcategory_id IS NOT NULL)",
    'Invalid recurring categories':
        "SELECT COUNT(*) AS n FROM recurring_templates t LEFT JOIN category_nodes n ON n.id = t.subcategory_id WHERE (t.type = 'expense' AND (n.id IS NULL OR n.type <> 'subcategory')) OR (t.type = 'income' AND t.subcategory_id IS NOT NULL)",
    'Invalid budget references':
        "SELECT COUNT(*) AS n FROM budget_limits l LEFT JOIN category_nodes n ON n.id = l.node_id LEFT JOIN budget_months m ON m.id = l.budget_month_id WHERE n.id IS NULL OR n.type <> 'category' OR m.id IS NULL",
    'Invalid recurring application references':
        'SELECT COUNT(*) AS n FROM recurring_applied a LEFT JOIN recurring_templates t ON t.id = a.template_id WHERE t.id IS NULL',
    'Invalid transaction amounts':
        'SELECT COUNT(*) AS n FROM transactions WHERE amount_minor <= 0',
    'Invalid recurring values':
        "SELECT COUNT(*) AS n FROM recurring_templates WHERE amount_minor <= 0 OR day_of_month NOT BETWEEN 1 AND 31 OR length(trim(title)) = 0",
    'Negative budgets':
        'SELECT COUNT(*) AS n FROM budget_months WHERE total_budget_minor < 0 OR saving_target_minor < 0',
    'Negative category limits':
        'SELECT COUNT(*) AS n FROM budget_limits WHERE limit_minor < 0',
  };
  final issues = <String>[];
  for (final check in checks.entries) {
    final count = (await db.customSelect(check.value).getSingle()).read<int>(
      'n',
    );
    if (count != 0) issues.add('${check.key}: $count');
  }
  if (issues.isNotEmpty) throw DataIntegrityException(issues);
}

/// Deterministic aggregate snapshot checked inside the migration transaction.
Future<String> _migrationTotals(AppDatabase db) async {
  final results = <String>[];
  for (final table in [
    'category_nodes',
    'budget_months',
    'budget_limits',
    'transactions',
    'recurring_templates',
    'recurring_applied',
  ]) {
    results.add(
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .data
          .toString(),
    );
  }
  for (final sql in [
    'SELECT month_id, type, COUNT(*) AS n, SUM(amount_minor) AS amount FROM transactions GROUP BY month_id, type ORDER BY month_id, type',
    'SELECT id, total_budget_minor, saving_target_minor FROM budget_months ORDER BY id',
    'SELECT budget_month_id, node_id, limit_minor FROM budget_limits ORDER BY budget_month_id, node_id',
    'SELECT id, amount_minor FROM recurring_templates ORDER BY id',
  ]) {
    results.add(
      (await db.customSelect(sql).get())
          .map((r) => r.data.toString())
          .join('\n'),
    );
  }
  return results.join('\n');
}
