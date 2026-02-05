import 'package:drift/drift.dart';
import '../../../core/db/app_db.dart';

class CategoryRepository {
  CategoryRepository(this.db);
  final AppDatabase db;
  String _normalize(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');

  Future<List<CategoryNode>> getCategories() {
    return (db.select(db.categoryNodes)
      ..where((n) => n.type.equals('category') & n.archived.equals(false))
      ..orderBy([(n) => OrderingTerm.asc(n.sortOrder), (n) => OrderingTerm.asc(n.name)]))
        .get();
  }

  Future<List<CategoryNode>> getSubcategories(String categoryId) {
    return (db.select(db.categoryNodes)
      ..where((n) =>
      n.type.equals('subcategory') &
      n.parentId.equals(categoryId) &
      n.archived.equals(false))
      ..orderBy([(n) => OrderingTerm.asc(n.sortOrder), (n) => OrderingTerm.asc(n.name)]))
        .get();
  }

  Future<void> addCategory(String name) async {
    final n = _normalize(name);
    if (n.isEmpty) throw Exception('Category name cannot be empty');

    try {
      await db.into(db.categoryNodes).insert(
        CategoryNodesCompanion.insert(
          name: n,
          type: 'category',
          parentId: const Value(null),
          sortOrder: const Value(50),
        ),
      );
    } catch (_) {
      throw Exception('Category "$n" already exists');
    }
  }

  Future<void> addSubcategory({required String categoryId, required String name}) async {
    final n = _normalize(name);
    if (n.isEmpty) throw Exception('Subcategory name cannot be empty');

    try {
      await db.into(db.categoryNodes).insert(
        CategoryNodesCompanion.insert(
          name: n,
          type: 'subcategory',
          parentId: Value(categoryId),
          sortOrder: const Value(50),
        ),
      );
    } catch (_) {
      throw Exception('Subcategory "$n" already exists in this category');
    }
  }

  Future<void> renameNode(String id, String newName) async {
    final n = _normalize(newName);
    if (n.isEmpty) throw Exception('Name cannot be empty');

    try {
      await (db.update(db.categoryNodes)..where((nn) => nn.id.equals(id))).write(
        CategoryNodesCompanion(name: Value(n)),
      );
    } catch (_) {
      throw Exception('Name "$n" already exists');
    }
  }


  Future<void> archiveNode(String id) async {
    await (db.update(db.categoryNodes)..where((n) => n.id.equals(id))).write(
      const CategoryNodesCompanion(archived: Value(true)),
    );
  }


  /// Includes archived=false by default
  Future<List<CategoryNode>> getAllCategories({bool includeArchived = false}) {
    final q = db.select(db.categoryNodes)..where((n) => n.type.equals('category'));
    if (!includeArchived) q.where((n) => n.archived.equals(false));
    q.orderBy([(n) => OrderingTerm.asc(n.sortOrder), (n) => OrderingTerm.asc(n.name)]);
    return q.get();
  }

  Future<List<CategoryNode>> getAllSubcategories(String categoryId, {bool includeArchived = false}) {
    final q = db.select(db.categoryNodes)
      ..where((n) => n.type.equals('subcategory') & n.parentId.equals(categoryId));
    if (!includeArchived) q.where((n) => n.archived.equals(false));
    q.orderBy([(n) => OrderingTerm.asc(n.sortOrder), (n) => OrderingTerm.asc(n.name)]);
    return q.get();
  }

}
