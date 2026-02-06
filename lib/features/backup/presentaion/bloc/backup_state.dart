import 'dart:io';
import 'package:equatable/equatable.dart';

enum BackupStatus { idle, loading, success, failure }

class BackupState extends Equatable {
  const BackupState({
    required this.status,
    required this.file,
    required this.error,
    required this.toast,
  });

  const BackupState.initial()
      : status = BackupStatus.idle,
        file = null,
        error = '',
        toast = null;

  final BackupStatus status;
  final File? file;     // exported file
  final String error;
  final String? toast;

  BackupState copyWith({
    BackupStatus? status,
    File? file,
    String? error,
    String? toast,
  }) {
    return BackupState(
      status: status ?? this.status,
      file: file ?? this.file,
      error: error ?? this.error,
      toast: toast,
    );
  }

  @override
  List<Object?> get props => [status, file?.path, error, toast];
}
