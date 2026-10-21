import '../../../core/db/app_db.dart';
import '../../budget/data/budget_repository.dart';
import '../../../core/db/report_models.dart';

class DashboardRepository {
  DashboardRepository(this.db);
  final AppDatabase db;

  Future<BudgetMonth> getMonth(String monthId) =>
      BudgetRepository(db).getMonth(monthId);

  Future<MonthTotals> getMonthTotals(String monthId) =>
      db.getMonthTotals(monthId);

  Future<List<CategoryCardRow>> getCategoryCards(String monthId) =>
      db.getCategoryCardsOptionA(monthId);

  Future<List<SubcategoryRow>> getSubcategoryBreakdown(
    String monthId,
    String categoryId,
  ) => db.getSubcategoryBreakdown(monthId, categoryId);
}
