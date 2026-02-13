import 'package:equatable/equatable.dart';
import '../../../core/db/app_db.dart';
import 'tx_filters.dart';

enum TxStatus { initial, loading, loaded, failure }

class TransactionState extends Equatable {
  const TransactionState({
    required this.status,
    required this.monthId,
    required this.items,
    required this.totalExpenseMinor,
    required this.totalIncomeMinor,
    required this.filters,
    required this.error,
  });

  const TransactionState.initial()
      : status = TxStatus.initial,
        monthId = '',
        items = const [],
        totalExpenseMinor = 0,
        totalIncomeMinor = 0,
        filters = TxFilters.empty,
        error = '';

  final TxStatus status;
  final String monthId;
  final List<Transaction> items;

  final int totalExpenseMinor;
  final int totalIncomeMinor;

  int get netMinor => totalIncomeMinor - totalExpenseMinor;

  final TxFilters filters;
  final String error;

  TransactionState copyWith({
    TxStatus? status,
    String? monthId,
    List<Transaction>? items,
    int? totalExpenseMinor,
    int? totalIncomeMinor,
    TxFilters? filters,
    String? error,
  }) {
    return TransactionState(
      status: status ?? this.status,
      monthId: monthId ?? this.monthId,
      items: items ?? this.items,
      totalExpenseMinor: totalExpenseMinor ?? this.totalExpenseMinor,
      totalIncomeMinor: totalIncomeMinor ?? this.totalIncomeMinor,
      filters: filters ?? this.filters,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    monthId,
    items,
    totalExpenseMinor,
    totalIncomeMinor,
    filters,
    error,
  ];
}
