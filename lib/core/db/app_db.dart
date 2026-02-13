import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:smartbudget/core/db/report_models.dart';
import 'package:uuid/uuid.dart';

import '../utils/month_id.dart';

part 'app_db.g.dart';

final _uuid = Uuid();

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'monthly_budget.sqlite'));
    return NativeDatabase(file);
  });
}

/// Tables
class CategoryNodes extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();

  TextColumn get name => text().withLength(min: 1, max: 50)();

  /// 'category' | 'subcategory'
  TextColumn get type => text().customConstraint(
    "NOT NULL CHECK(type IN ('category','subcategory'))",
  )();

  /// Null for category, required for subcategory
  TextColumn get parentId => text().nullable()();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get icon => text().nullable()();

  IntColumn get color => integer().nullable()();

  @override
  List<String> get customConstraints => [
    "CHECK ("
        "(type = 'category' AND parent_id IS NULL) OR "
        "(type = 'subcategory' AND parent_id IS NOT NULL)"
        ")",
  ];

  @override
  List<Set<Column>> get uniqueKeys => [
    // unique category names (parentId null)
    {name, parentId},

    // This also makes subcategory names unique per parent category:
    // (parentId + name) must be unique.
  ];
}

class BudgetMonths extends Table {
  /// e.g., '2026-01'
  TextColumn get id => text()();

  /// Keep simple for now; you can replace with onboarding preference later
  TextColumn get currency => text().withDefault(const Constant('PKR'))();

  IntColumn get totalBudgetMinor => integer().withDefault(const Constant(0))();

  IntColumn get savingTargetMinor => integer().withDefault(const Constant(0))();

  IntColumn get createdAt =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();

  @override
  Set<Column> get primaryKey => {id};
}

class BudgetLimits extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();

  TextColumn get budgetMonthId =>
      text().references(BudgetMonths, #id, onDelete: KeyAction.cascade)();

  /// Option A: nodeId points to category rows only
  /// Option B (later): nodeId can point to category or subcategory
  TextColumn get nodeId =>
      text().references(CategoryNodes, #id, onDelete: KeyAction.cascade)();

  IntColumn get limitMinor => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {budgetMonthId, nodeId},
  ];
}

class Transactions extends Table {
  TextColumn get id => text().clientDefault(() => _uuid.v4())();

  /// 'income' | 'expense'
  TextColumn get type =>
      text().customConstraint("NOT NULL CHECK(type IN ('income','expense'))")();

  /// Money in minor units (paisa/cents)
  IntColumn get amountMinor => integer()();

  /// Epoch millis
  IntColumn get dateMillis => integer()();

  /// Stored at write-time (avoid timezone bugs and slow grouping)
  /// e.g., '2026-01'
  TextColumn get monthId => text()();

  /// For expenses: must be NOT NULL (enforced by table constraint below)
  /// For income: must be NULL
  TextColumn get subcategoryId =>
      text().nullable().references(CategoryNodes, #id)();

  TextColumn get note => text().nullable()();

  IntColumn get createdAt =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();

  IntColumn get updatedAt =>
      integer().clientDefault(() => DateTime.now().millisecondsSinceEpoch)();

  @override
  List<String> get customConstraints => [
    "CHECK ("
        "(type = 'expense' AND subcategory_id IS NOT NULL) OR "
        "(type = 'income' AND subcategory_id IS NULL)"
        ")",
  ];
}

@DataClassName('RecurringTemplate')
class RecurringTemplates extends Table {
  TextColumn get id => text()(); // string id (we'll generate in repo)
  TextColumn get title => text()(); // e.g. Rent
  IntColumn get amountMinor => integer()(); // PKR minor
  TextColumn get type =>
      text().customConstraint("NOT NULL CHECK(type IN ('income','expense'))")();

  /// Optional: for expenses you can store subcategoryId here (same as Transactions.subcategoryId)
  TextColumn get subcategoryId =>
      text().nullable().references(CategoryNodes, #id)();

  TextColumn get note => text().nullable()();

  /// 1..31 (clamp in repo when applying)
  IntColumn get dayOfMonth => integer().withDefault(const Constant(1))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get createdAtMillis => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RecurringAppliedRow')
class RecurringApplied extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get templateId =>
      text().references(RecurringTemplates, #id, onDelete: KeyAction.cascade)();

  TextColumn get monthId => text()(); // 'YYYY-MM'

  IntColumn get appliedAtMillis => integer()();

  @override
  List<String> get customConstraints => ['UNIQUE(template_id, month_id)'];
}

@DriftDatabase(
  tables: [
    CategoryNodes,
    BudgetMonths,
    BudgetLimits,
    Transactions,
    RecurringTemplates,
    RecurringApplied,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(recurringTemplates);
        await m.createTable(recurringApplied);
      }
    },
  );


  /// Seed default categories/subcategories ONLY if database is empty.
  Future<void> seedDefaultsIfEmpty() async {
    final existing = await (select(categoryNodes)..limit(1)).get();
    if (existing.isNotEmpty) return;

    await batch((b) {
      // Categories (fixed IDs make seeding deterministic)
      b.insertAll(categoryNodes, [
        CategoryNodesCompanion.insert(
          id: const Value('cat_groceries'),
          name: 'Groceries',
          type: 'category',
          parentId: const Value(null),
          sortOrder: const Value(1),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('cat_bills'),
          name: 'Bills',
          type: 'category',
          parentId: const Value(null),
          sortOrder: const Value(2),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('cat_shopping'),
          name: 'Shopping',
          type: 'category',
          parentId: const Value(null),
          sortOrder: const Value(3),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('cat_transport'),
          name: 'Transport',
          type: 'category',
          parentId: const Value(null),
          sortOrder: const Value(4),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('cat_other'),
          name: 'Other',
          type: 'category',
          parentId: const Value(null),
          sortOrder: const Value(5),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('cat_uncategorized'),
          name: 'Uncategorized',
          type: 'category',
          parentId: const Value(null),
          sortOrder: const Value(999),
        ),
      ]);

      // Subcategories
      b.insertAll(categoryNodes, [
        // Groceries
        CategoryNodesCompanion.insert(
          id: const Value('sub_groceries_rice'),
          name: 'Rice',
          type: 'subcategory',
          parentId: const Value('cat_groceries'),
          sortOrder: const Value(1),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_groceries_meat'),
          name: 'Meat',
          type: 'subcategory',
          parentId: const Value('cat_groceries'),
          sortOrder: const Value(2),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_groceries_eggs'),
          name: 'Eggs',
          type: 'subcategory',
          parentId: const Value('cat_groceries'),
          sortOrder: const Value(3),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_groceries_milk'),
          name: 'Milk',
          type: 'subcategory',
          parentId: const Value('cat_groceries'),
          sortOrder: const Value(4),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_groceries_vegetables'),
          name: 'Vegetables',
          type: 'subcategory',
          parentId: const Value('cat_groceries'),
          sortOrder: const Value(5),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_groceries_fruits'),
          name: 'Fruits',
          type: 'subcategory',
          parentId: const Value('cat_groceries'),
          sortOrder: const Value(6),
        ),

        // Bills
        CategoryNodesCompanion.insert(
          id: const Value('sub_bills_rent'),
          name: 'Rent',
          type: 'subcategory',
          parentId: const Value('cat_bills'),
          sortOrder: const Value(1),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_bills_electricity'),
          name: 'Electricity',
          type: 'subcategory',
          parentId: const Value('cat_bills'),
          sortOrder: const Value(2),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_bills_gas'),
          name: 'Gas',
          type: 'subcategory',
          parentId: const Value('cat_bills'),
          sortOrder: const Value(3),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_bills_internet'),
          name: 'Internet',
          type: 'subcategory',
          parentId: const Value('cat_bills'),
          sortOrder: const Value(4),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_bills_water'),
          name: 'Water',
          type: 'subcategory',
          parentId: const Value('cat_bills'),
          sortOrder: const Value(5),
        ),

        // Shopping
        CategoryNodesCompanion.insert(
          id: const Value('sub_shopping_clothes'),
          name: 'Clothes',
          type: 'subcategory',
          parentId: const Value('cat_shopping'),
          sortOrder: const Value(1),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_shopping_electronics'),
          name: 'Electronics',
          type: 'subcategory',
          parentId: const Value('cat_shopping'),
          sortOrder: const Value(2),
        ),

        // Transport
        CategoryNodesCompanion.insert(
          id: const Value('sub_transport_fuel'),
          name: 'Fuel',
          type: 'subcategory',
          parentId: const Value('cat_transport'),
          sortOrder: const Value(1),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_transport_ride'),
          name: 'Ride/Taxi',
          type: 'subcategory',
          parentId: const Value('cat_transport'),
          sortOrder: const Value(2),
        ),

        // Other
        CategoryNodesCompanion.insert(
          id: const Value('sub_other_medical'),
          name: 'Medical',
          type: 'subcategory',
          parentId: const Value('cat_other'),
          sortOrder: const Value(1),
        ),
        CategoryNodesCompanion.insert(
          id: const Value('sub_other_eating_out'),
          name: 'Eating Out',
          type: 'subcategory',
          parentId: const Value('cat_other'),
          sortOrder: const Value(2),
        ),

        // Uncategorized
        CategoryNodesCompanion.insert(
          id: const Value('sub_uncategorized_general'),
          name: 'General',
          type: 'subcategory',
          parentId: const Value('cat_uncategorized'),
          sortOrder: const Value(1),
        ),
      ]);
    });
  }

  // ---------- BudgetMonth helpers ----------
  Future<void> ensureBudgetMonthExists(String monthId) async {
    final existing = await (select(
      budgetMonths,
    )..where((m) => m.id.equals(monthId))).getSingleOrNull();
    if (existing != null) return;

    await into(budgetMonths).insert(
      BudgetMonthsCompanion.insert(
        id: monthId,
        // currency default is PKR from table default, but we can set explicitly if you want
        // currency: const Value('PKR'),
        totalBudgetMinor: const Value(0),
        savingTargetMinor: const Value(0),
      ),
    );
  }

  // ---------- Month totals ----------
  Future<MonthTotals> getMonthTotals(String monthId) async {
    final spentRow = await customSelect(
      '''
    SELECT COALESCE(SUM(amount_minor), 0) AS total_spent
    FROM transactions
    WHERE month_id = ? AND type = 'expense';
    ''',
      variables: [Variable.withString(monthId)],
    ).getSingle();

    final incomeRow = await customSelect(
      '''
    SELECT COALESCE(SUM(amount_minor), 0) AS total_income
    FROM transactions
    WHERE month_id = ? AND type = 'income';
    ''',
      variables: [Variable.withString(monthId)],
    ).getSingle();

    return MonthTotals(
      totalSpent: spentRow.read<int>('total_spent'),
      totalIncome: incomeRow.read<int>('total_income'),
    );
  }

  // ---------- Option A: Category cards (spent + category budget join) ----------
  Future<List<CategoryCardRow>> getCategoryCardsOptionA(String monthId) async {
    final rows = await customSelect(
      '''
    SELECT
      c.id AS category_id,
      c.name AS category_name,
      COALESCE(SUM(t.amount_minor), 0) AS spent,
      bl.limit_minor AS budget_limit
    FROM category_nodes c
    LEFT JOIN category_nodes s
      ON s.parent_id = c.id AND s.type='subcategory'
    LEFT JOIN transactions t
      ON t.subcategory_id = s.id
      AND t.month_id = ? AND t.type='expense'
    LEFT JOIN budget_limits bl
      ON bl.node_id = c.id AND bl.budget_month_id = ?
    WHERE c.type='category'
    GROUP BY c.id, c.name, bl.limit_minor
    HAVING (c.archived = 0) OR (COALESCE(SUM(t.amount_minor), 0) > 0)
    ORDER BY c.sort_order ASC, c.name ASC;
    ''',
      variables: [Variable.withString(monthId), Variable.withString(monthId)],
    ).get();

    return rows.map((r) {
      final spent = r.read<int>('spent');
      final limit = r.read<int?>('budget_limit');
      return CategoryCardRow(
        categoryId: r.read<String>('category_id'),
        categoryName: r.read<String>('category_name'),
        spent: spent,
        budgetLimit: limit,
        remaining: limit == null ? null : (limit - spent),
      );
    }).toList();
  }

  // ---------- Subcategory breakdown for one category ----------
  Future<List<SubcategoryRow>> getSubcategoryBreakdown(
    String monthId,
    String categoryId,
  ) async {
    final rows = await customSelect(
      '''
    SELECT
      s.id AS subcategory_id,
      s.name AS subcategory_name,
      COALESCE(SUM(t.amount_minor), 0) AS spent
    FROM category_nodes s
    LEFT JOIN transactions t
      ON t.subcategory_id = s.id
      AND t.month_id = ? AND t.type='expense'
    WHERE s.type='subcategory' AND s.parent_id = ?
    GROUP BY s.id, s.name
    HAVING (s.archived = 0) OR (COALESCE(SUM(t.amount_minor), 0) > 0)
    ORDER BY s.sort_order ASC, s.name ASC;
    ''',
      variables: [
        Variable.withString(monthId),
        Variable.withString(categoryId),
      ],
    ).get();

    return rows.map((r) {
      return SubcategoryRow(
        subcategoryId: r.read<String>('subcategory_id'),
        subcategoryName: r.read<String>('subcategory_name'),
        spent: r.read<int>('spent'),
      );
    }).toList();
  }

  // ---------- Subcategories helpers ----------
  Future<List<CategoryNode>> getSubcategories(String categoryId) {
    return (select(categoryNodes)
      ..where((n) =>
      n.type.equals('subcategory') &
      n.parentId.equals(categoryId) &
      n.archived.equals(false))
      ..orderBy([
            (n) => OrderingTerm.asc(n.sortOrder),
            (n) => OrderingTerm.asc(n.name),
      ]))
        .get();
  }

  Future<List<String>> getSubcategoryIdsByCategory(String categoryId) async {
    final rows = await (selectOnly(categoryNodes)
      ..addColumns([categoryNodes.id])
      ..where(categoryNodes.type.equals('subcategory') &
      categoryNodes.parentId.equals(categoryId) &
      categoryNodes.archived.equals(false))
      ..orderBy([OrderingTerm.asc(categoryNodes.sortOrder)]))
        .get();

    return rows.map((r) => r.read(categoryNodes.id)!).toList();
  }


  // ---------- Helper to insert a sample expense (for testing only) ----------
  Future<void> insertExpense({
    required int amountMinor,
    required int dateMillis,
    required String subcategoryId,
    String? note,
  }) async {
    final mId = monthIdFromMillis(dateMillis);

    await into(transactions).insert(
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

  Future<void> insertIncome({
    required int amountMinor,
    required int dateMillis,
    String? note,
  }) async {
    final mId = monthIdFromMillis(dateMillis);

    await into(transactions).insert(
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

  Future<List<CategoryCardRow>> getTopCategories(
    String monthId, {
    int limit = 6,
  }) async {
    final rows = await customSelect(
      '''
    SELECT
      c.id AS category_id,
      c.name AS category_name,
      COALESCE(SUM(t.amount_minor), 0) AS spent,
      bl.limit_minor AS budget_limit
    FROM category_nodes c
    LEFT JOIN category_nodes s
      ON s.parent_id = c.id AND s.type='subcategory'
    LEFT JOIN transactions t
      ON t.subcategory_id = s.id
      AND t.month_id = ? AND t.type='expense'
    LEFT JOIN budget_limits bl
      ON bl.node_id = c.id AND bl.budget_month_id = ?
    WHERE c.type='category'
    GROUP BY c.id, c.name, bl.limit_minor
    ORDER BY spent DESC
    LIMIT ?;
    ''',
      variables: [
        Variable.withString(monthId),
        Variable.withString(monthId),
        Variable.withInt(limit),
      ],
    ).get();

    return rows.map((r) {
      final spent = r.read<int>('spent');
      final limitV = r.read<int?>('budget_limit');
      return CategoryCardRow(
        categoryId: r.read<String>('category_id'),
        categoryName: r.read<String>('category_name'),
        spent: spent,
        budgetLimit: limitV,
        remaining: limitV == null ? null : (limitV - spent),
      );
    }).toList();
  }

  Future<List<SubcategoryRow>> getTopSubcategories(
    String monthId, {
    int limit = 10,
  }) async {
    final rows = await customSelect(
      '''
    SELECT
      s.id AS subcategory_id,
      s.name AS subcategory_name,
      COALESCE(SUM(t.amount_minor), 0) AS spent
    FROM category_nodes s
    LEFT JOIN transactions t
      ON t.subcategory_id = s.id
      AND t.month_id = ? AND t.type='expense'
    WHERE s.type='subcategory'
    GROUP BY s.id, s.name
    ORDER BY spent DESC
    LIMIT ?;
    ''',
      variables: [Variable.withString(monthId), Variable.withInt(limit)],
    ).get();

    return rows.map((r) {
      return SubcategoryRow(
        subcategoryId: r.read<String>('subcategory_id'),
        subcategoryName: r.read<String>('subcategory_name'),
        spent: r.read<int>('spent'),
      );
    }).toList();
  }
}
