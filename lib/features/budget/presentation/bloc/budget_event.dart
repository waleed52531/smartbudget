import 'package:equatable/equatable.dart';
import '../../data/budget_repository.dart';

abstract class BudgetEvent extends Equatable {
  const BudgetEvent();

  @override
  List<Object?> get props => [];
}

class LoadBudgetMonth extends BudgetEvent {
  const LoadBudgetMonth(this.monthId);
  final String monthId;

  @override
  List<Object?> get props => [monthId];
}

class SaveMonthBudgetRequested extends BudgetEvent {
  const SaveMonthBudgetRequested({
    required this.monthId,
    required this.totalBudgetMinor,
    required this.savingTargetMinor,
  });

  final String monthId;
  final int totalBudgetMinor;
  final int savingTargetMinor;

  @override
  List<Object?> get props => [monthId, totalBudgetMinor, savingTargetMinor];
}

class SetCategoryLimitRequested extends BudgetEvent {
  const SetCategoryLimitRequested({
    required this.monthId,
    required this.categoryId,
    required this.limitMinor,
  });

  final String monthId;
  final String categoryId;
  final int limitMinor;

  @override
  List<Object?> get props => [monthId, categoryId, limitMinor];
}

class ClearCategoryLimitRequested extends BudgetEvent {
  const ClearCategoryLimitRequested({
    required this.monthId,
    required this.categoryId,
  });

  final String monthId;
  final String categoryId;

  @override
  List<Object?> get props => [monthId, categoryId];
}

/// copy previous month budget
class CopyFromPreviousMonthRequested extends BudgetEvent {
  const CopyFromPreviousMonthRequested({
    required this.monthId,
    required this.mode,
  });

  final String monthId;
  final CopyMode mode;

  @override
  List<Object?> get props => [monthId, mode];
}

/// clears toast after UI shows it
class ClearBudgetToast extends BudgetEvent {
  const ClearBudgetToast();
}
