import 'package:equatable/equatable.dart';

sealed class ExportEvent extends Equatable {
  const ExportEvent();
  @override
  List<Object?> get props => [];
}

class ExportMonthRequested extends ExportEvent {
  const ExportMonthRequested(this.monthId);
  final String monthId;

  @override
  List<Object?> get props => [monthId];
}
