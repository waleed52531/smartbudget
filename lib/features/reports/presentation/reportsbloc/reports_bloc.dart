import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/reports_repository.dart';
import '../../../budget/data/budget_repository.dart';
import 'reports_event.dart';
import 'reports_state.dart';

class ReportsBloc extends Bloc<ReportsEvent, ReportsState> {
  ReportsBloc({
    required this.reportsRepo,
    required this.budgetRepo,
  }) : super(const ReportsState.initial()) {
    on<LoadReports>(_onLoad);
    on<ClearReportsToast>((e, emit) => emit(state.copyWith(toast: null)));
  }

  final ReportsRepository reportsRepo;
  final BudgetRepository budgetRepo;

  Future<void> _onLoad(LoadReports e, Emitter<ReportsState> emit) async {
    // cache: if already loaded for this month and not forced, do nothing
    if (!e.force &&
        state.status == ReportsStatus.loaded &&
        state.monthId == e.monthId &&
        state.totals != null) {
      return;
    }

    emit(state.copyWith(
      status: ReportsStatus.loading,
      monthId: e.monthId,
      error: '',
      toast: null,
    ));

    try {
      final results = await Future.wait([
        reportsRepo.monthTotals(e.monthId),
        reportsRepo.topCategories(e.monthId),
        reportsRepo.topSubcategories(e.monthId),
        budgetRepo.getOrCreateMonth(e.monthId),
      ]);

      emit(state.copyWith(
        status: ReportsStatus.loaded,
        monthId: e.monthId,
        totals: results[0] as dynamic,
        topCategories: results[1] as dynamic,
        topSubcategories: results[2] as dynamic,
        monthBudget: results[3] as dynamic,
        loadedAtMillis: DateTime.now().millisecondsSinceEpoch,
        error: '',
      ));
    } catch (err) {
      emit(state.copyWith(
        status: ReportsStatus.failure,
        error: err.toString(),
        toast: 'Failed to load reports',
      ));
    }
  }
}
