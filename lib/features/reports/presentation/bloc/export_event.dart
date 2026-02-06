import 'package:equatable/equatable.dart';

abstract class ExportEvent extends Equatable {
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

/// ✅ Export what user is currently viewing (filters)
class ExportFilteredRequested extends ExportEvent {
  const ExportFilteredRequested({
    required this.monthId,
    this.query,
    this.type, // 'expense' | 'income' | null
    this.subcategoryId,
    this.minMinor,
    this.maxMinor,
  });

  final String monthId;
  final String? query;
  final String? type;
  final String? subcategoryId;
  final int? minMinor;
  final int? maxMinor;

  @override
  List<Object?> get props => [monthId, query, type, subcategoryId, minMinor, maxMinor];
}
