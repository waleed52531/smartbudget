import '../../../core/db/app_db.dart';
import '../../../core/db/report_models.dart';

class ReportsRepository {
  ReportsRepository(this.db);
  final AppDatabase db;

  Future<MonthTotals> monthTotals(String monthId) => db.getMonthTotals(monthId);

  Future<List<CategoryCardRow>> topCategories(String monthId) =>
      db.getTopCategories(monthId, limit: 6);

  Future<List<SubcategoryRow>> topSubcategories(String monthId) =>
      db.getTopSubcategories(monthId, limit: 10);
}
