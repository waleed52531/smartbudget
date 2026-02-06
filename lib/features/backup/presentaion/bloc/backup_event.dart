import 'dart:io';
import 'package:equatable/equatable.dart';
import '../../data/backup_repository.dart';

abstract class BackupEvent extends Equatable {
  const BackupEvent();
  @override
  List<Object?> get props => [];
}

class ExportBackupRequested extends BackupEvent {
  const ExportBackupRequested();
}

class RestoreBackupRequested extends BackupEvent {
  const RestoreBackupRequested({required this.file, required this.mode});
  final File file;
  final RestoreMode mode;

  @override
  List<Object?> get props => [file.path, mode];
}

class ClearBackupToast extends BackupEvent {
  const ClearBackupToast();
}
