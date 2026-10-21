part of 'dashboard_bloc.dart';

enum DashboardStatus { initial, loading, loaded, failure }

class DashboardState extends Equatable {
  const DashboardState({
    required this.status,
    required this.monthId,
    required this.month,
    required this.totals,
    required this.categoryCards,
    required this.remainingMinor,
    required this.netIncomeMinor,
    required this.error,
  });

  const DashboardState.initial()
    : status = DashboardStatus.initial,
      monthId = '',
      month = null,
      totals = null,
      categoryCards = const [],
      remainingMinor = 0,
      netIncomeMinor = 0,
      error = '';

  final DashboardStatus status;
  final String monthId;
  final BudgetMonth? month;
  final MonthTotals? totals;
  final List<CategoryCardRow> categoryCards;
  final int remainingMinor;
  final int netIncomeMinor;
  final String error;

  DashboardState copyWith({
    DashboardStatus? status,
    String? monthId,
    BudgetMonth? month,
    MonthTotals? totals,
    List<CategoryCardRow>? categoryCards,
    int? remainingMinor,
    int? netIncomeMinor,
    String? error,
  }) {
    return DashboardState(
      status: status ?? this.status,
      monthId: monthId ?? this.monthId,
      month: month ?? this.month,
      totals: totals ?? this.totals,
      categoryCards: categoryCards ?? this.categoryCards,
      remainingMinor: remainingMinor ?? this.remainingMinor,
      netIncomeMinor: netIncomeMinor ?? this.netIncomeMinor,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    monthId,
    month,
    totals,
    categoryCards,
    remainingMinor,
    netIncomeMinor,
    error,
  ];
}
