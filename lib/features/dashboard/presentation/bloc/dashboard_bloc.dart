import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/db/app_db.dart';
import '../../../../core/db/report_models.dart';
import '../../data/dashboard_repository.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc(this.repo) : super(const DashboardState.initial()) {
    on<LoadDashboard>(_onLoad);
  }

  final DashboardRepository repo;
  int _loadGeneration = 0;

  Future<void> _onLoad(LoadDashboard e, Emitter<DashboardState> emit) async {
    final generation = ++_loadGeneration;
    emit(state.copyWith(status: DashboardStatus.loading, monthId: e.monthId));
    try {
      final month = await repo.getMonth(e.monthId);
      final totals = await repo.getMonthTotals(e.monthId);
      final cards = await repo.getCategoryCards(e.monthId);

      final remaining = month.totalBudgetMinor - totals.totalSpent;
      final netIncome = totals.totalIncome - totals.totalSpent;

      if (generation != _loadGeneration) return;
      emit(
        state.copyWith(
          status: DashboardStatus.loaded,
          month: month,
          totals: totals,
          categoryCards: cards,
          remainingMinor: remaining,
          netIncomeMinor: netIncome,
          error: '',
        ),
      );
    } catch (err) {
      if (generation != _loadGeneration) return;
      emit(
        state.copyWith(status: DashboardStatus.failure, error: err.toString()),
      );
    }
  }
}
