import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/export_repository.dart';
import 'export_event.dart';
import 'export_state.dart';


class ExportBloc extends Bloc<ExportEvent, ExportState> {
  ExportBloc(this.repo) : super(const ExportState.initial()) {
    on<ExportMonthRequested>(_onExportMonth);
  }

  final ExportRepository repo;

  Future<void> _onExportMonth(ExportMonthRequested e, Emitter<ExportState> emit) async {
    emit(state.copyWith(status: ExportStatus.loading));
    try {
      final file = await repo.exportMonthCsv(monthId: e.monthId);
      emit(state.copyWith(status: ExportStatus.success, file: file, error: ''));
    } catch (err) {
      emit(state.copyWith(status: ExportStatus.failure, error: err.toString()));
    }
  }
}
