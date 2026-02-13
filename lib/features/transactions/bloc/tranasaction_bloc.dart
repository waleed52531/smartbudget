import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/db/app_db.dart';
import '../data/transaction_repository.dart';
import 'tranasaction_event.dart';
import 'tranasaction_state.dart';
import 'tx_filters.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  TransactionBloc(this.repo) : super(const TransactionState.initial()) {
    on<LoadMonthTransactions>(_onLoad);
    on<AddExpenseRequested>(_onAddExpense);
    on<AddIncomeRequested>(_onAddIncome);
    on<DeleteTransactionRequested>(_onDelete);
    on<UpdateTransactionRequested>(_onUpdate);
    on<ApplyTxFiltersRequested>(_onApplyFilters);
    on<ClearTxFiltersRequested>(_onClearFilters);
  }

  final TransactionRepository repo;

  Future<void> _onLoad(LoadMonthTransactions e, Emitter<TransactionState> emit) async {
    emit(state.copyWith(status: TxStatus.loading, monthId: e.monthId, error: ''));
    try {
      final raw = await repo.listByMonth(e.monthId);
      final filtered = _applyFilters(raw, state.filters);
      final (exp, inc) = _totals(filtered);

      emit(state.copyWith(
        status: TxStatus.loaded,
        monthId: e.monthId,
        items: filtered,
        totalExpenseMinor: exp,
        totalIncomeMinor: inc,
        error: '',
      ));
    } catch (err) {
      emit(state.copyWith(status: TxStatus.failure, error: err.toString()));
    }
  }

  Future<void> _onAddExpense(AddExpenseRequested e, Emitter<TransactionState> emit) async {
    try {
      await repo.addExpense(
        monthId: e.monthId,
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
        monthId: e.monthId,
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

  Future<void> _onUpdate(UpdateTransactionRequested e, Emitter<TransactionState> emit) async {
    try {
      await repo.updateTransaction(
        id: e.id,
        type: e.type,
        amountMinor: e.amountMinor,
        dateMillis: e.dateMillis,
        monthId: e.monthId,
        subcategoryId: e.subcategoryId,
        note: e.note,
      );
      add(LoadMonthTransactions(e.monthId));
    } catch (err) {
      emit(state.copyWith(status: TxStatus.failure, error: err.toString()));
    }
  }

  void _onApplyFilters(ApplyTxFiltersRequested e, Emitter<TransactionState> emit) {
    emit(state.copyWith(filters: e.filters));
    add(LoadMonthTransactions(e.monthId)); // ✅ correct month, always
  }

  void _onClearFilters(ClearTxFiltersRequested e, Emitter<TransactionState> emit) {
    emit(state.copyWith(filters: TxFilters.empty));
    add(LoadMonthTransactions(e.monthId)); // ✅ correct month, always
  }
}

List<Transaction> _applyFilters(List<Transaction> input, TxFilters f) {
  Iterable<Transaction> out = input;

  if (f.type == TxTypeFilter.expense) {
    out = out.where((t) => t.type == 'expense');
  } else if (f.type == TxTypeFilter.income) {
    out = out.where((t) => t.type == 'income');
  }

  if (f.fromMillis != null) out = out.where((t) => t.dateMillis >= f.fromMillis!);
  if (f.toMillis != null) out = out.where((t) => t.dateMillis <= f.toMillis!);

  if (f.minMinor != null) out = out.where((t) => t.amountMinor >= f.minMinor!);
  if (f.maxMinor != null) out = out.where((t) => t.amountMinor <= f.maxMinor!);

  if (f.subcategoryId != null) {
    out = out.where((t) => t.subcategoryId == f.subcategoryId);
  } else if (f.categorySubcategoryIds != null && f.categorySubcategoryIds!.isNotEmpty) {
    final set = f.categorySubcategoryIds!.toSet();
    out = out.where((t) => t.subcategoryId != null && set.contains(t.subcategoryId));
  }

  final q = f.search.trim().toLowerCase();
  if (q.isNotEmpty) {
    out = out.where((t) => (t.note ?? '').toLowerCase().contains(q));
  }

  final list = out.toList();

  switch (f.sort) {
    case TxSort.newest:
      list.sort((a, b) => b.dateMillis.compareTo(a.dateMillis));
      break;
    case TxSort.oldest:
      list.sort((a, b) => a.dateMillis.compareTo(b.dateMillis));
      break;
    case TxSort.amountHigh:
      list.sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
      break;
    case TxSort.amountLow:
      list.sort((a, b) => a.amountMinor.compareTo(b.amountMinor));
      break;
  }

  return list;
}

(int expense, int income) _totals(List<Transaction> items) {
  var exp = 0;
  var inc = 0;
  for (final t in items) {
    if (t.type == 'expense') exp += t.amountMinor;
    if (t.type == 'income') inc += t.amountMinor;
  }
  return (exp, inc);
}
