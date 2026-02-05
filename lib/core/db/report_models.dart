class MonthTotals {
  const MonthTotals({required this.totalSpent, required this.totalIncome});
  final int totalSpent;
  final int totalIncome;
}

class CategoryCardRow {
  const CategoryCardRow({
    required this.categoryId,
    required this.categoryName,
    required this.spent,
    required this.budgetLimit,
    required this.remaining,
  });

  final String categoryId;
  final String categoryName;
  final int spent;

  /// null if not set
  final int? budgetLimit;

  /// null if budgetLimit is null
  final int? remaining;
}

class SubcategoryRow {
  const SubcategoryRow({
    required this.subcategoryId,
    required this.subcategoryName,
    required this.spent,
  });

  final String subcategoryId;
  final String subcategoryName;
  final int spent;
}
