import 'package:equatable/equatable.dart';

import '../../../../core/db/app_db.dart';
import '../../../../core/db/report_models.dart';

enum ReportsStatus { idle, loading, loaded, failure }

class ReportsState extends Equatable {
  const ReportsState({
    required this.status,
    required this.monthId,
    required this.totals,
    required this.topCategories,
    required this.topSubcategories,
    required this.monthBudget,
    required this.error,
    required this.toast,
    required this.loadedAtMillis,
  });

  const ReportsState.initial()
      : status = ReportsStatus.idle,
        monthId = '',
        totals = null,
        topCategories = const [],
        topSubcategories = const [],
        monthBudget = null,
        error = '',
        toast = null,
        loadedAtMillis = null;

  final ReportsStatus status;
  final String monthId;

  final MonthTotals? totals;
  final List<CategoryCardRow> topCategories;
  final List<SubcategoryRow> topSubcategories;

  final BudgetMonth? monthBudget;

  final String error;
  final String? toast;
  final int? loadedAtMillis;

  ReportsState copyWith({
    ReportsStatus? status,
    String? monthId,
    MonthTotals? totals,
    List<CategoryCardRow>? topCategories,
    List<SubcategoryRow>? topSubcategories,
    BudgetMonth? monthBudget,
    String? error,
    String? toast,
    int? loadedAtMillis,
  }) {
    return ReportsState(
      status: status ?? this.status,
      monthId: monthId ?? this.monthId,
      totals: totals ?? this.totals,
      topCategories: topCategories ?? this.topCategories,
      topSubcategories: topSubcategories ?? this.topSubcategories,
      monthBudget: monthBudget ?? this.monthBudget,
      error: error ?? this.error,
      toast: toast,
      loadedAtMillis: loadedAtMillis ?? this.loadedAtMillis,
    );
  }

  @override
  List<Object?> get props => [
    status,
    monthId,
    totals,
    topCategories,
    topSubcategories,
    monthBudget,
    error,
    toast,
    loadedAtMillis,
  ];
}
