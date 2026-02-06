import 'dart:io';
import 'package:equatable/equatable.dart';

enum ExportStatus { idle, loading, success, failure }

class ExportState extends Equatable {
  const ExportState({
    required this.status,
    required this.file,
    required this.error,
  });

  const ExportState.initial()
      : status = ExportStatus.idle,
        file = null,
        error = '';

  final ExportStatus status;
  final File? file;
  final String error;

  ExportState copyWith({
    ExportStatus? status,
    File? file,
    String? error,
  }) {
    return ExportState(
      status: status ?? this.status,
      file: file,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, file?.path, error];
}
