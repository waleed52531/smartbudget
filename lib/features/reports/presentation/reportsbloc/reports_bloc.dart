import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/reports_repository.dart';
import '../../../budget/data/budget_repository.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc({required this.reportsRepo, required this.budgetRepo})
    : super(const ReportsState.initial()) {
    on<LoadReports>(_onLoad);
    on<ClearReportsToast>((e, emit) => emit(state.copyWith(toast: null)));
  }

  final ReportsRepository reportsRepo;
  final BudgetRepository budgetRepo;
  int _loadGeneration = 0;

  Future<void> _onLoad(LoadReports e, Emitter<ReportsState> emit) async {
    final generation = ++_loadGeneration;
    emit(
      state.copyWith(
        status: ReportsStatus.loading,
        monthId: e.monthId,
        error: '',
        toast: null,
      ),
    );

    try {
      final results = await Future.wait([
        reportsRepo.monthTotals(e.monthId),
        reportsRepo.topCategories(e.monthId),
        reportsRepo.topSubcategories(e.monthId),
        budgetRepo.getMonth(e.monthId),
      ]);

      if (generation != _loadGeneration) return;
      emit(
        state.copyWith(
          status: ReportsStatus.loaded,
          monthId: e.monthId,
          totals: results[0] as dynamic,
          topCategories: results[1] as dynamic,
          topSubcategories: results[2] as dynamic,
          monthBudget: results[3] as dynamic,
          loadedAtMillis: DateTime.now().millisecondsSinceEpoch,
          error: '',
        ),
      );
    } catch (err) {
      if (generation != _loadGeneration) return;
      emit(
        state.copyWith(
          status: ReportsStatus.failure,
          error: err.toString(),
          toast: 'Failed to load reports',
        ),
      );
    }
  }
}
