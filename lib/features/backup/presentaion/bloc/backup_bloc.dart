import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/backup_repository.dart';
import 'backup_event.dart';
import 'backup_state.dart';

class BackupBloc extends Bloc<BackupEvent, BackupState> {
  BackupBloc({required this.repo}) : super(const BackupState.initial()) {
    on<ExportBackupRequested>(_onExport);
    on<RestoreBackupRequested>(_onRestore);
    on<ClearBackupToast>((e, emit) => emit(state.copyWith(toast: null)));
  }

  final BackupRepository repo;

  Future<void> _onExport(ExportBackupRequested e, Emitter<BackupState> emit) async {
    emit(state.copyWith(status: BackupStatus.loading, error: '', toast: null));
    try {
      final file = await repo.exportBackupJson();
      emit(state.copyWith(status: BackupStatus.success, file: file, toast: 'Backup exported'));
    } catch (err) {
      emit(state.copyWith(status: BackupStatus.failure, error: err.toString(), toast: 'Export failed: $err'));
    }
  }

  Future<void> _onRestore(RestoreBackupRequested e, Emitter<BackupState> emit) async {
    emit(state.copyWith(status: BackupStatus.loading, error: '', toast: null));
    try {
      await repo.restoreFromJsonFile(file: e.file, mode: e.mode);
      emit(state.copyWith(status: BackupStatus.success, toast: 'Backup restored'));
    } catch (err) {
      emit(state.copyWith(status: BackupStatus.failure, error: err.toString(), toast: 'Restore failed: $err'));
    }
  }
}
