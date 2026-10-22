import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

const tableNames = [
  'category_nodes',
  'budget_months',
  'budget_limits',
  'transactions',
  'recurring_templates',
  'recurring_applied',
];

void createV2Fixture(File file, {String? extraSql}) {
  final db = sqlite3.open(file.path);
  try {
    db.execute(File('test/fixtures/schema_v2.sql').readAsStringSync());
    db.execute('''
      INSERT INTO category_nodes (id,name,type,parent_id,archived) VALUES
        ('cat','Synthetic category','category',NULL,0),
        ('sub','Synthetic subcategory','subcategory','cat',0),
        ('archived','Synthetic archived category','category',NULL,1);
      INSERT INTO budget_months VALUES ('2026-01','PKR',90000,10000,1);
      INSERT INTO budget_limits VALUES ('limit','2026-01','cat',50000);
      INSERT INTO transactions VALUES
        ('income','income',100000,1767268800000,'2026-01',NULL,'Synthetic income',1,1),
        ('expense','expense',20000,1767268800000,'2026-01','sub','Synthetic expense',2,2);
      INSERT INTO recurring_templates VALUES ('template','Synthetic recurring',20000,'expense','sub',NULL,31,1,1);
      INSERT INTO recurring_applied VALUES (7,'template','2026-01',1);
    ''');
    if (extraSql != null) db.execute(extraSql);
  } finally {
    db.close();
  }
}

Map<String, List<Map<String, Object?>>> snapshot(File file) {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return {
      for (final name in tableNames)
        name: db
            .select('SELECT * FROM $name ORDER BY id')
            .map((r) => Map<String, Object?>.from(r))
            .toList(),
    };
  } finally {
    db.close();
  }
}
