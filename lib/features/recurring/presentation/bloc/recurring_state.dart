import 'package:equatable/equatable.dart';
import '../../../../../core/db/app_db.dart';

enum RecurringStatus { loading, loaded, failure }

class RecurringState extends Equatable {
  const RecurringState({
    required this.status,
    required this.items,
    required this.error,
    required this.toast,
  });

  const RecurringState.initial()
      : status = RecurringStatus.loading,
        items = const [],
        error = '',
        toast = null;

  final RecurringStatus status;
  final List<RecurringTemplate> items;
  final String error;
  final String? toast;

  RecurringState copyWith({
    RecurringStatus? status,
    List<RecurringTemplate>? items,
    String? error,
    String? toast,
  }) {
    return RecurringState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error ?? this.error,
      toast: toast,
    );
  }

  @override
  List<Object?> get props => [status, items, error, toast];
}
