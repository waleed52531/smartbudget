import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/month_cubit.dart';
import '../../../core/utils/money.dart';
import '../../reports/presentation/reportsbloc/reports_bloc.dart';
import '../../reports/presentation/reportsbloc/reports_event.dart';
import '../data/recurring_repository.dart';
import 'bloc/recurring_bloc.dart';
import 'bloc/recurring_event.dart';
import 'bloc/recurring_state.dart';
import 'recurring_form_screen.dart';

class ManageRecurringScreen extends StatefulWidget {
  const ManageRecurringScreen({super.key});

  @override
  State<ManageRecurringScreen> createState() => _ManageRecurringScreenState();
}

class _ManageRecurringScreenState extends State<ManageRecurringScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RecurringBloc>().add(const LoadRecurringTemplates());
  }

  Future<void> _showSkippedDialog(List<String> titles) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Skipped Invalid Recurring'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: titles.length,
            itemBuilder: (_, i) => Text('• ${titles[i]}'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthId = context.watch<MonthCubit>().state;
    final repo = context.read<RecurringRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RecurringFormScreen()),
              );
              if (!context.mounted) return;
              context.read<RecurringBloc>().add(const LoadRecurringTemplates());
            },
          ),
        ],
      ),
      body: BlocConsumer<RecurringBloc, RecurringState>(
        listener: (context, s) async {
          final msg = s.toast;
          if (msg == null) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );

          // ✅ Only apply sets lastApplySummary, and we clear it on ClearRecurringToast now
          final summary = s.lastApplySummary;
          if (summary != null) {
            context.read<ReportsBloc>().add(
              LoadReports(monthId: monthId, force: true),
            );

            if (summary.hasSkips) {
              await _showSkippedDialog(summary.skippedTitles);
            }
          }

          context.read<RecurringBloc>().add(const ClearRecurringToast());
        },
        builder: (context, state) {
          return Column(
            children: [
              FutureBuilder<int>(
                future: repo.pendingCount(monthId),
                builder: (context, snap) {
                  final pending = snap.data ?? 0;
                  if (pending <= 0) return const SizedBox.shrink();

                  return Card(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                    child: ListTile(
                      title: Text('$pending recurring items pending'),
                      subtitle: Text('Apply to ${MonthCubit.display(monthId)}'),
                      trailing: ElevatedButton(
                        onPressed: state.status == RecurringStatus.loading
                            ? null
                            : () => context.read<RecurringBloc>().add(
                          ApplyRecurringToMonthRequested(monthId),
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  );
                },
              ),
              Expanded(
                child: Builder(
                  builder: (_) {
                    if (state.status == RecurringStatus.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.status == RecurringStatus.failure) {
                      return Center(child: Text('Error: ${state.error}'));
                    }

                    final items = state.items;
                    if (items.isEmpty) {
                      return const Center(child: Text('No recurring templates yet.'));
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = items[i];
                        final isExpense = t.type == 'expense';

                        return ListTile(
                          key: ValueKey(t.id),
                          title: Text(t.title),
                          subtitle: Text(
                            '${isExpense ? "Expense" : "Income"}'
                                ' • Day ${t.dayOfMonth}'
                                ' • ${minorToRupees(t.amountMinor)}'
                                '${(t.note == null || t.note!.trim().isEmpty) ? "" : " • ${t.note}"}',
                          ),
                          leading: Switch(
                            value: t.isActive,
                            onChanged: (v) => context.read<RecurringBloc>().add(
                              ToggleRecurringActiveRequested(t.id, v),
                            ),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RecurringFormScreen(existing: t),
                                  ),
                                );
                                if (!context.mounted) return;
                                context.read<RecurringBloc>().add(const LoadRecurringTemplates());
                              } else if (v == 'delete') {
                                context.read<RecurringBloc>().add(
                                  DeleteRecurringTemplateRequested(t.id),
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecurringFormScreen(existing: t),
                              ),
                            );
                            if (!context.mounted) return;
                            context.read<RecurringBloc>().add(const LoadRecurringTemplates());
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
