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
    on<ClearRecurringToast>(_onClearToast);
  }

  final RecurringRepository repo;

  Future<void> _onLoad(LoadRecurringTemplates e, Emitter<RecurringState> emit) async {
    emit(state.copyWith(
      status: RecurringStatus.loading,
      clearToast: true,
      clearApplySummary: true,
      error: '',
    ));

    try {
      final items = await repo.listTemplates();
      emit(state.copyWith(
        status: RecurringStatus.loaded,
        items: items,
        error: '',
      ));
    } catch (err) {
      emit(state.copyWith(
        status: RecurringStatus.failure,
        error: err.toString(),
        toast: 'Load failed: $err',
        clearApplySummary: true,
      ));
    }
  }

  Future<void> _onSave(SaveRecurringTemplateRequested e, Emitter<RecurringState> emit) async {
    emit(state.copyWith(
      status: RecurringStatus.loading,
      clearToast: true,
      clearApplySummary: true,
      error: '',
    ));

    try {
      await repo.upsertTemplate(
        id: e.id,
        title: e.title,
        amountMinor: e.amountMinor,
        type: e.type,
        subcategoryId: e.subcategoryId,
        note: e.note,
        dayOfMonth: e.dayOfMonth,
        isActive: e.isActive,
      );

      final items = await repo.listTemplates();
      emit(state.copyWith(
        status: RecurringStatus.loaded,
        items: items,
        toast: 'Recurring saved',
        error: '',
        clearApplySummary: true,
      ));
    } catch (err) {
      emit(state.copyWith(
        status: RecurringStatus.failure,
        error: err.toString(),
        toast: 'Save failed: $err',
        clearApplySummary: true,
      ));
    }
  }

  Future<void> _onDelete(DeleteRecurringTemplateRequested e, Emitter<RecurringState> emit) async {
    emit(state.copyWith(
      status: RecurringStatus.loading,
      clearToast: true,
      clearApplySummary: true,
      error: '',
    ));

    try {
      await repo.deleteTemplate(e.id);
      final items = await repo.listTemplates();

      emit(state.copyWith(
        status: RecurringStatus.loaded,
        items: items,
        toast: 'Recurring deleted',
        error: '',
        clearApplySummary: true,
      ));
    } catch (err) {
      emit(state.copyWith(
        status: RecurringStatus.failure,
        error: err.toString(),
        toast: 'Delete failed: $err',
        clearApplySummary: true,
      ));
    }
  }

  Future<void> _onToggle(ToggleRecurringActiveRequested e, Emitter<RecurringState> emit) async {
    // Don’t wipe UI with loading for a switch flip unless you enjoy jank
    try {
      await repo.toggleActive(e.id, e.active);
      final items = await repo.listTemplates();

      emit(state.copyWith(
        status: RecurringStatus.loaded,
        items: items,
        error: '',
        clearApplySummary: true,
      ));
    } catch (err) {
      emit(state.copyWith(
        status: RecurringStatus.failure,
        error: err.toString(),
        toast: 'Update failed: $err',
        clearApplySummary: true,
      ));
    }
  }

  Future<void> _onApply(ApplyRecurringToMonthRequested e, Emitter<RecurringState> emit) async {
    emit(state.copyWith(
      status: RecurringStatus.loading,
      clearToast: true,
      clearApplySummary: true,
      error: '',
    ));

    try {
      final summary = await repo.applyToMonth(e.monthId);

      final msg = summary.hasSkips
          ? 'Applied ${summary.appliedCount}. Skipped ${summary.skippedInvalidCount} invalid.'
          : 'Applied ${summary.appliedCount} recurring items.';

      final items = await repo.listTemplates();

      emit(state.copyWith(
        status: RecurringStatus.loaded,
        items: items,
        toast: msg,
        lastApplySummary: summary,
        error: '',
      ));
    } catch (err) {
      emit(state.copyWith(
        status: RecurringStatus.failure,
        error: err.toString(),
        toast: 'Apply failed: $err',
        clearApplySummary: true,
      ));
    }
  }

  void _onClearToast(ClearRecurringToast e, Emitter<RecurringState> emit) {
    // ✅ IMPORTANT: clears BOTH so your screen doesn't re-trigger apply behavior later
    emit(state.copyWith(clearToast: true, clearApplySummary: true));
  }
}
