import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/export_repository.dart';
import 'export_event.dart';
import 'export_state.dart';

class ExportBloc extends Bloc<ExportEvent, ExportState> {
  ExportBloc({required this.repo}) : super(const ExportState.initial()) {
    on<ExportMonthRequested>(_onExportMonth);
    on<ExportFilteredRequested>(_onExportFiltered);
  }

  final ExportRepository repo;

  Future<void> _onExportMonth(ExportMonthRequested e, Emitter<ExportState> emit) async {
    emit(state.copyWith(status: ExportStatus.loading, file: null, error: ''));
    try {
      final file = await repo.exportMonthCsv(monthId: e.monthId);
      emit(state.copyWith(status: ExportStatus.success, file: file, error: ''));
    } catch (err) {
      emit(state.copyWith(status: ExportStatus.failure, file: null, error: err.toString()));
    }
  }

  Future<void> _onExportFiltered(ExportFilteredRequested e, Emitter<ExportState> emit) async {
    emit(state.copyWith(status: ExportStatus.loading, file: null, error: ''));
    try {
      final file = await repo.exportFilteredCsv(
        monthId: e.monthId,
        query: e.query,
        type: e.type,
        subcategoryId: e.subcategoryId,
        minMinor: e.minMinor,
        maxMinor: e.maxMinor,
      );
      emit(state.copyWith(status: ExportStatus.success, file: file, error: ''));
    } catch (err) {
      emit(state.copyWith(status: ExportStatus.failure, file: null, error: err.toString()));
    }
  }
}
