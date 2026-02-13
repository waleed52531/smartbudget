import 'package:equatable/equatable.dart';
import '../../../../../core/db/app_db.dart';
import '../../data/recurring_repository.dart';

enum RecurringStatus { loading, loaded, failure }

class RecurringState extends Equatable {
  const RecurringState({
    required this.status,
    required this.items,
    required this.error,
    required this.toast,
    required this.lastApplySummary,
  });

  const RecurringState.initial()
      : status = RecurringStatus.loading,
        items = const [],
        error = '',
        toast = null,
        lastApplySummary = null;

  final RecurringStatus status;
  final List<RecurringTemplate> items;
  final String error;

  final String? toast;

  /// Only set after Apply
  final ApplyRecurringSummary? lastApplySummary;

  RecurringState copyWith({
    RecurringStatus? status,
    List<RecurringTemplate>? items,
    String? error,
    String? toast,
    ApplyRecurringSummary? lastApplySummary,
    bool clearToast = false,
    bool clearApplySummary = false,
  }) {
    return RecurringState(
      status: status ?? this.status,
      items: items ?? this.items,
      error: error ?? this.error,
      toast: clearToast ? null : (toast ?? this.toast),
      lastApplySummary: clearApplySummary ? null : (lastApplySummary ?? this.lastApplySummary),
    );
  }

  @override
  List<Object?> get props => [status, items, error, toast, lastApplySummary];
}
