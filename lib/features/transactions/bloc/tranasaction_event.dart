
import 'package:equatable/equatable.dart';

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
