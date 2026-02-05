import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smartbudget/features/transactions/bloc/tranasaction_event.dart';
import 'package:smartbudget/features/transactions/bloc/tranasaction_state.dart';

import '../../../../core/db/app_db.dart';
import '../data/transaction_repository.dart';


class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc(this.repo) : super(const TransactionState.initial()) {
    on<LoadMonthTransactions>(_onLoad);
    on<AddExpenseRequested>(_onAddExpense);
    on<AddIncomeRequested>(_onAddIncome);
    on<DeleteTransactionRequested>(_onDelete);
  }

  final TransactionRepository repo;

  Future<void> _onLoad(LoadMonthTransactions e, Emitter<TransactionState> emit) async {
    emit(state.copyWith(status: TxStatus.loading, monthId: e.monthId));
    try {
      final items = await repo.listByMonth(e.monthId);
      emit(state.copyWith(status: TxStatus.loaded, items: items, error: ''));
    } catch (err) {
      emit(state.copyWith(status: TxStatus.failure, error: err.toString()));
    }
  }

  Future<void> _onAddExpense(AddExpenseRequested e, Emitter<TransactionState> emit) async {
    try {
      await repo.addExpense(
        amountMinor: e.amountMinor,
        dateMillis: e.dateMillis,
        subcategoryId: e.subcategoryId,
        note: e.note,
      );
      add(LoadMonthTransactions(e.monthId));
    } catch (err) {
      emit(state.copyWith(status: TxStatus.failure, error: err.toString()));
    }
  }

  Future<void> _onAddIncome(AddIncomeRequested e, Emitter<TransactionState> emit) async {
    try {
      await repo.addIncome(
        amountMinor: e.amountMinor,
        dateMillis: e.dateMillis,
        note: e.note,
      );
      add(LoadMonthTransactions(e.monthId));
    } catch (err) {
      emit(state.copyWith(status: TxStatus.failure, error: err.toString()));
    }
  }

  Future<void> _onDelete(DeleteTransactionRequested e, Emitter<TransactionState> emit) async {
    try {
      await repo.deleteById(e.id);
      add(LoadMonthTransactions(e.monthId));
    } catch (err) {
      emit(state.copyWith(status: TxStatus.failure, error: err.toString()));
    }
  }
}
