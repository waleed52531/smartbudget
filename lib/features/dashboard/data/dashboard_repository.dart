import '../../../core/db/app_db.dart';
import '../../../core/db/report_models.dart';

class DashboardRepository {
  DashboardRepository(this.db);
  final AppDatabase db;

  Future<BudgetMonth> getOrCreateMonth(String monthId) {
    return db.ensureBudgetMonthExists(monthId).then((_) async {
      return (db.select(db.budgetMonths)..where((m) => m.id.equals(monthId))).getSingle();
    });
  }

  Future<MonthTotals> getMonthTotals(String monthId) => db.getMonthTotals(monthId);

  Future<List<CategoryCardRow>> getCategoryCards(String monthId) =>
      db.getCategoryCardsOptionA(monthId);

  Future<List<SubcategoryRow>> getSubcategoryBreakdown(String monthId, String categoryId) =>
      db.getSubcategoryBreakdown(monthId, categoryId);
}
