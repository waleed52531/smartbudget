import 'package:equatable/equatable.dart';

abstract class ReportsEvent extends Equatable {
  const ReportsEvent();
  @override
  List<Object?> get props => [];
}

class LoadReports extends ReportsEvent {
  const LoadReports({required this.monthId, this.force = false});
  final String monthId;
  final bool force;

  @override
  List<Object?> get props => [monthId, force];
}

class ClearReportsToast extends ReportsEvent {
  const ClearReportsToast();
}
