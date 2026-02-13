import 'package:equatable/equatable.dart';

abstract class RecurringEvent extends Equatable {
  const RecurringEvent();
  @override
  List<Object?> get props => [];
}

class LoadRecurringTemplates extends RecurringEvent {
  const LoadRecurringTemplates();
}

class SaveRecurringTemplateRequested extends RecurringEvent {
  const SaveRecurringTemplateRequested({
    this.id,
    required this.title,
    required this.amountMinor,
    required this.type, // 'income' | 'expense'
    required this.dayOfMonth,
    this.subcategoryId, // only for expense
    this.note,
    required this.isActive,
  });

  final String? id;
  final String title;
  final int amountMinor;
  final String type;
  final int dayOfMonth;
  final String? subcategoryId;
  final String? note;
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    title,
    amountMinor,
    type,
    dayOfMonth,
    subcategoryId,
    note,
    isActive,
  ];
}

class DeleteRecurringTemplateRequested extends RecurringEvent {
  const DeleteRecurringTemplateRequested(this.id);
  final String id;

  @override
  List<Object?> get props => [id];
}

class ToggleRecurringActiveRequested extends RecurringEvent {
  const ToggleRecurringActiveRequested(this.id, this.active);
  final String id;
  final bool active;

  @override
  List<Object?> get props => [id, active];
}

class ApplyRecurringToMonthRequested extends RecurringEvent {
  const ApplyRecurringToMonthRequested(this.monthId);
  final String monthId;

  @override
  List<Object?> get props => [monthId];
}

class ClearRecurringToast extends RecurringEvent {
  const ClearRecurringToast();
}
