
import 'package:equatable/equatable.dart';

import '../../../../core/db/app_db.dart';

enum BudgetStatus {loading, loaded, failure }

class BudgetState extends Equatable {
  const BudgetState({
    required this.status,
    required this.monthId,
    required this.month,
    required this.categories,
    required this.categoryLimits,
    required this.error,
    required this.toastMessage,
  });

  const BudgetState.initial()
      : status = BudgetStatus.loading,
        monthId = '',
        month = null,
        categories = const [],
        categoryLimits = const {},
        error = '',
        toastMessage = null;


  final BudgetStatus status;
  final String monthId;
  final BudgetMonth? month;
  final List<CategoryNode> categories;
  final Map<String, int?> categoryLimits;
  final String error;
  final String? toastMessage;


  BudgetState copyWith({
    BudgetStatus? status,
    String? monthId,
    BudgetMonth? month,
    List<CategoryNode>? categories,
    Map<String, int?>? categoryLimits,
    String? error,
    String? toastMessage,
  }) {
    return BudgetState(
      status: status ?? this.status,
      monthId: monthId ?? this.monthId,
      month: month ?? this.month,
      categories: categories ?? this.categories,
      categoryLimits: categoryLimits ?? this.categoryLimits,
      error: error ?? this.error,
      toastMessage: toastMessage,
    );
  }

  @override
  List<Object?> get props => [status, monthId, month, categories, categoryLimits, error, toastMessage];
}
