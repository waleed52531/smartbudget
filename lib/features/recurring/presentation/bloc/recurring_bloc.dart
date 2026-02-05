import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/recurring_repository.dart';
import 'recurring_event.dart';
import 'recurring_state.dart';

class RecurringBloc extends Bloc<RecurringEvent, RecurringState> {
  RecurringBloc({required this.repo}) : super(const RecurringState.initial()) {
    on<LoadRecurringTemplates>(_onLoad);
    on<SaveRecurringTemplateRequested>(_onSave);
    on<DeleteRecurringTemplateRequested>(_onDelete);
    on<ToggleRecurringActiveRequested>(_onToggle);
    on<ApplyRecurringToMonthRequested>(_onApply);
    on<ClearRecurringToast>((e, emit) => emit(state.copyWith(toast: null)));
  }

  final RecurringRepository repo;

  Future<void> _onLoad(
      LoadRecurringTemplates e,
      Emitter<RecurringState> emit,
      ) async {
    emit(state.copyWith(status: RecurringStatus.loading, toast: null));
    try {
      final items = await repo.listTemplates();
      emit(
        state.copyWith(
          status: RecurringStatus.loaded,
          items: items,
          error: '',
        ),
      );
    } catch (err) {
      emit(
        state.copyWith(
          status: RecurringStatus.failure,
          error: err.toString(),
        ),
      );
    }
  }

  Future<void> _onSave(
      SaveRecurringTemplateRequested e,
      Emitter<RecurringState> emit,
      ) async {
    try {
      await repo.upsertTemplate(
        id: e.id,
        title: e.title,
        amountMinor: e.amountMinor,
        type: e.type,
        dayOfMonth: e.dayOfMonth,
        subcategoryId: e.subcategoryId, // ✅ FIX
        note: e.note,
        isActive: e.isActive,
      );
      add(const LoadRecurringTemplates());
      emit(state.copyWith(toast: 'Recurring saved'));
    } catch (err) {
      emit(
        state.copyWith(
          status: RecurringStatus.failure,
          error: err.toString(),
          toast: 'Save failed: $err',
        ),
      );
    }
  }

  Future<void> _onDelete(
      DeleteRecurringTemplateRequested e,
      Emitter<RecurringState> emit,
      ) async {
    try {
      await repo.deleteTemplate(e.id);
      add(const LoadRecurringTemplates());
      emit(state.copyWith(toast: 'Recurring deleted'));
    } catch (err) {
      emit(
        state.copyWith(
          status: RecurringStatus.failure,
          error: err.toString(),
          toast: 'Delete failed: $err',
        ),
      );
    }
  }

  Future<void> _onToggle(
      ToggleRecurringActiveRequested e,
      Emitter<RecurringState> emit,
      ) async {
    try {
      await repo.toggleActive(e.id, e.active);
      add(const LoadRecurringTemplates());
    } catch (err) {
      emit(
        state.copyWith(
          status: RecurringStatus.failure,
          error: err.toString(),
          toast: 'Update failed: $err',
        ),
      );
    }
  }

  Future<void> _onApply(
      ApplyRecurringToMonthRequested e,
      Emitter<RecurringState> emit,
      ) async {
    try {
      await repo.applyToMonth(e.monthId);
      emit(state.copyWith(toast: 'Recurring applied to ${e.monthId}'));
    } catch (err) {
      emit(
        state.copyWith(
          status: RecurringStatus.failure,
          error: err.toString(),
          toast: 'Apply failed: $err',
        ),
      );
    }
  }
}
