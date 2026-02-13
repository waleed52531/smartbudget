import 'package:equatable/equatable.dart';
import 'tx_filters.dart';

sealed class TransactionEvent extends Equatable {
  const TransactionEvent();
  @override
  List<Object?> get props => [];
}

class LoadMonthTransactions extends TransactionEvent {
  const LoadMonthTransactions(this.monthId);
  final String monthId;

  @override
  List<Object?> get props => [monthId];
}

class AddExpenseRequested extends TransactionEvent {
  const AddExpenseRequested({
    required this.monthId,
    required this.amountMinor,
    required this.dateMillis,
    required this.subcategoryId,
    this.note,
  });

  final String monthId;
  final int amountMinor;
  final int dateMillis;
  final String subcategoryId;
  final String? note;

  @override
  List<Object?> get props => [monthId, amountMinor, dateMillis, subcategoryId, note];
}

class AddIncomeRequested extends TransactionEvent {
  const AddIncomeRequested({
    required this.monthId,
    required this.amountMinor,
    required this.dateMillis,
    this.note,
  });

  final String monthId;
  final int amountMinor;
  final int dateMillis;
  final String? note;

  @override
  List<Object?> get props => [monthId, amountMinor, dateMillis, note];
}

class DeleteTransactionRequested extends TransactionEvent {
  const DeleteTransactionRequested({required this.id, required this.monthId});
  final String id;
  final String monthId;

  @override
  List<Object?> get props => [id, monthId];
}

class UpdateTransactionRequested extends TransactionEvent {
  const UpdateTransactionRequested({
    required this.id,
    required this.monthId,
    required this.type, // 'income'|'expense'
    required this.amountMinor,
    required this.dateMillis,
    required this.subcategoryId, // nullable for income
    required this.note, // nullable
  });

  final String id;
  final String monthId;
  final String type;
  final int amountMinor;
  final int dateMillis;
  final String? subcategoryId;
  final String? note;

  @override
  List<Object?> get props => [id, monthId, type, amountMinor, dateMillis, subcategoryId, note];
}

/// ✅ FIX: named params (matches your UI calls)
class ApplyTxFiltersRequested extends TransactionEvent {
  const ApplyTxFiltersRequested({
    required this.monthId,
    required this.filters,
  });

  final String monthId;
  final TxFilters filters;

  @override
  List<Object?> get props => [monthId, filters];
}

/// ✅ FIX: also named and includes monthId
class ClearTxFiltersRequested extends TransactionEvent {
  const ClearTxFiltersRequested({required this.monthId});
  final String monthId;

  @override
  List<Object?> get props => [monthId];
}
