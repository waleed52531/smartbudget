import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../categories/data/category_repository.dart';
import '../../data/budget_repository.dart';
import 'budget_event.dart';
import 'budget_state.dart';

class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  BudgetBloc({
    required this.budgetRepo,
    required this.categoryRepo,
  }) : super(const BudgetState.initial()) {
    on<LoadBudgetMonth>(_onLoad);
    on<SaveMonthBudgetRequested>(_onSaveMonth);
    on<SetCategoryLimitRequested>(_onSetCategoryLimit);
    on<ClearCategoryLimitRequested>(_onClearCategoryLimit);
    on<CopyFromPreviousMonthRequested>(_onCopyPrev);
    on<ClearBudgetToast>(_onClearToast);
  }

  final BudgetRepository budgetRepo;
  final CategoryRepository categoryRepo;

  Future<void> _onLoad(LoadBudgetMonth e, Emitter<BudgetState> emit) async {
    emit(state.copyWith(status: BudgetStatus.loading, monthId: e.monthId, toastMessage: null));
    try {
      final month = await budgetRepo.getOrCreateMonth(e.monthId);
      final categories = await categoryRepo.getCategories();

      // v1: fetch limits one by one (works but slow for many categories)
      final Map<String, int?> limits = {};
      for (final c in categories) {
        limits[c.id] = await budgetRepo.getCategoryLimit(e.monthId, c.id);
      }

      emit(state.copyWith(
        status: BudgetStatus.loaded,
        month: month,
        categories: categories,
        categoryLimits: limits,
        error: '',
      ));
    } catch (err) {
      emit(state.copyWith(status: BudgetStatus.failure, error: err.toString()));
    }
  }

  Future<void> _onSaveMonth(SaveMonthBudgetRequested e, Emitter<BudgetState> emit) async {
    try {
      await budgetRepo.updateMonthBudget(
        monthId: e.monthId,
        totalBudgetMinor: e.totalBudgetMinor,
        savingTargetMinor: e.savingTargetMinor,
      );
      add(LoadBudgetMonth(e.monthId));
      emit(state.copyWith(toastMessage: 'Month budget saved'));
    } catch (err) {
      emit(state.copyWith(status: BudgetStatus.failure, error: err.toString(), toastMessage: 'Save failed: $err'));
    }
  }

  Future<void> _onSetCategoryLimit(SetCategoryLimitRequested e, Emitter<BudgetState> emit) async {
    try {
      await budgetRepo.upsertCategoryLimit(
        monthId: e.monthId,
        categoryId: e.categoryId,
        limitMinor: e.limitMinor,
      );
      add(LoadBudgetMonth(e.monthId));
      emit(state.copyWith(toastMessage: 'Limit updated'));
    } catch (err) {
      emit(state.copyWith(status: BudgetStatus.failure, error: err.toString(), toastMessage: 'Update failed: $err'));
    }
  }

  Future<void> _onClearCategoryLimit(ClearCategoryLimitRequested e, Emitter<BudgetState> emit) async {
    try {
      await budgetRepo.clearCategoryLimit(e.monthId, e.categoryId);
      add(LoadBudgetMonth(e.monthId));
      emit(state.copyWith(toastMessage: 'Limit cleared'));
    } catch (err) {
      emit(state.copyWith(status: BudgetStatus.failure, error: err.toString(), toastMessage: 'Clear failed: $err'));
    }
  }

  /// ✅ Step 14 handler
  Future<void> _onCopyPrev(CopyFromPreviousMonthRequested e, Emitter<BudgetState> emit) async {
    emit(state.copyWith(status: BudgetStatus.loading, toastMessage: null));
    try {
      await budgetRepo.copyFromPreviousMonth(monthId: e.monthId, mode: e.mode);
      add(LoadBudgetMonth(e.monthId));
      emit(state.copyWith(toastMessage: 'Copied budget from previous month'));
    } catch (err) {
      emit(state.copyWith(status: BudgetStatus.failure, error: err.toString(), toastMessage: 'Copy failed: $err'));
    }
  }

  void _onClearToast(ClearBudgetToast e, Emitter<BudgetState> emit) {
    emit(state.copyWith(toastMessage: null));
  }
}
