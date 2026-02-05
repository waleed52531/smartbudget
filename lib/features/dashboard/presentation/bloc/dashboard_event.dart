part of 'dashboard_bloc.dart';

sealed class DashboardEvent extends Equatable {
  const DashboardEvent();
  @override
  List<Object?> get props => [];
}

class LoadDashboard extends DashboardEvent {
  const LoadDashboard(this.monthId);
  final String monthId;

  @override
  List<Object?> get props => [monthId];
}
