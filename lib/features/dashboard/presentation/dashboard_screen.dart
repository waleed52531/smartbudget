import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/db/app_db.dart';
import '../../../core/db/report_models.dart';
import '../../../core/state/month_cubit.dart';
import '../../../core/ui/month_picker_sheet.dart';
import '../../../core/utils/money.dart';
import '../../categories/presentation/category_breakdown_screen.dart';
import '../../recurring/data/recurring_repository.dart';
import '../../recurring/presentation/bloc/recurring_bloc.dart';
import '../../recurring/presentation/bloc/recurring_event.dart';
import '../../recurring/presentation/manage_recurring_screen.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/presentation/bloc/export_bloc.dart';
import '../../reports/presentation/bloc/export_event.dart';
import '../../reports/presentation/bloc/export_state.dart';
import '../../transactions/bloc/tranasaction_bloc.dart';
import '../../transactions/bloc/tranasaction_event.dart';
import '../../transactions/bloc/tx_filters.dart';
import '../../transactions/presentation/add_transaction_screen.dart';
import '../../transactions/presentation/transaction_list_screen.dart';
import 'bloc/dashboard_bloc.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _projectMinor(int spentMinor, int daysElapsed, int daysInMonth) {
    if (daysElapsed <= 0) return spentMinor;
    return ((spentMinor / daysElapsed) * daysInMonth).round();
  }

  String _paceLabel({
    required int spentMinor,
    required int budgetMinor,
    required int daysElapsed,
    required int daysInMonth,
  }) {
    if (budgetMinor <= 0) return 'Set a budget to see pace';

    final timePct = daysElapsed / daysInMonth;
    final spendPct = spentMinor / budgetMinor;
    final diff = spendPct - timePct;

    if (diff > 0.07) return 'Over pace (risk)';
    if (diff < -0.07) return 'Under pace (good)';
    return 'On track';
  }

  Future<void> _openTransactionsWithFilter({
    required BuildContext context,
    required String monthId,
    required TxFilters filters,
  }) async {
    // ✅ 1) ensure month is correct
    final currentMonth = context.read<MonthCubit>().state;
    if (currentMonth != monthId) {
      context.read<MonthCubit>().setFromDate(MonthCubit.toDate(monthId));
    }

    // ✅ 2) apply filter + force reload for that month
    context.read<TransactionBloc>().add(
      ApplyTxFiltersRequested(monthId: monthId, filters: filters),
    );
    context.read<TransactionBloc>().add(LoadMonthTransactions(monthId));

    // ✅ 3) navigate
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionsListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthId = context.watch<MonthCubit>().state;

    final selected = MonthCubit.toDate(monthId);
    final now = DateTime.now();
    final isCurrentMonth = (now.year == selected.year && now.month == selected.month);

    final daysInMonth = DateTime(selected.year, selected.month + 1, 0).day;
    final daysElapsed = isCurrentMonth ? (now.day.clamp(1, daysInMonth) as int) : daysInMonth;

    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard (${MonthCubit.display(monthId)})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final picked = await showMonthPickerSheet(context, MonthCubit.toDate(monthId));
              if (picked != null && context.mounted) {
                context.read<MonthCubit>().setFromDate(picked);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {
              context.read<ExportBloc>().add(ExportMonthRequested(monthId));
            },
          ),
          IconButton(
            icon: const Icon(Icons.repeat_outlined),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageRecurringScreen()));
            },
          ),
        ],
      ),
      body: BlocListener<ExportBloc, ExportState>(
        listener: (context, s) async {
          if (s.status == ExportStatus.success && s.file != null) {
            await Share.shareXFiles(
              [XFile(s.file!.path)],
              text: 'Monthly Budget CSV (${MonthCubit.display(monthId)})',
            );
          } else if (s.status == ExportStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Export failed: ${s.error}')),
            );
          }
        },
        child: BlocBuilder<DashboardBloc, DashboardState>(
          builder: (context, state) {
            if (state.status == DashboardStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == DashboardStatus.failure) {
              return Center(child: Text('Error: ${state.error}'));
            }
            if (state.status != DashboardStatus.loaded || state.month == null || state.totals == null) {
              return const Center(child: Text('Loading...'));
            }

            final totalBudget = state.month!.totalBudgetMinor;
            final savingTarget = state.month!.savingTargetMinor;
            final spent = state.totals!.totalSpent;
            final remaining = state.remainingMinor;

            final projectedSpent = _projectMinor(spent, daysElapsed, daysInMonth);
            final projectedRemaining = totalBudget > 0 ? (totalBudget - projectedSpent) : 0;
            final pace = _paceLabel(
              spentMinor: spent,
              budgetMinor: totalBudget,
              daysElapsed: daysElapsed,
              daysInMonth: daysInMonth,
            );

            final alerts = <_AlertRow>[];
            for (final c in state.categoryCards) {
              if (c.budgetLimit == null) continue;
              final proj = _projectMinor(c.spent, daysElapsed, daysInMonth);
              if (proj > c.budgetLimit!) {
                alerts.add(
                  _AlertRow(
                    name: c.categoryName,
                    overByMinor: proj - c.budgetLimit!,
                    projectedMinor: proj,
                    limitMinor: c.budgetLimit!,
                  ),
                );
              }
            }
            alerts.sort((a, b) => b.overByMinor.compareTo(a.overByMinor));

            return RefreshIndicator(
              onRefresh: () async {
                final m = context.read<MonthCubit>().state;
                context.read<DashboardBloc>().add(LoadDashboard(m));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _kpiCard(
                    title: 'Month Summary',
                    lines: [
                      'Total Budget: ${minorToRupees(totalBudget)}',
                      'Spent: ${minorToRupees(spent)}',
                      'Remaining: ${minorToRupees(remaining)}',
                    ],
                  ),
                  const SizedBox(height: 12),
                  _kpiCard(
                    title: 'Saving',
                    lines: [
                      'Saving Target: ${minorToRupees(savingTarget)}',
                      'Saving Progress: ${minorToRupees(state.savingProgressMinor)}',
                    ],
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<int>(
                    future: context.read<RecurringRepository>().pendingCount(monthId),
                    builder: (context, snap) {
                      final pending = snap.data ?? 0;
                      if (pending <= 0) return const SizedBox.shrink();

                      return Card(
                        child: ListTile(
                          title: Text('$pending recurring items pending'),
                          subtitle: const Text('Apply them to this month'),
                          trailing: ElevatedButton(
                            onPressed: () {
                              context.read<RecurringBloc>().add(ApplyRecurringToMonthRequested(monthId));
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder(
                    future: context.read<ReportsRepository>().topSubcategories(monthId),
                    builder: (context, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final subs = (snap.data as List<SubcategoryRow>).take(4).toList();
                      if (subs.isEmpty) return const SizedBox.shrink();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Quick Add (Top Leaks)', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: subs.map((s) {
                              return ActionChip(
                                label: Text(s.subcategoryName),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddTransactionScreen(
                                        monthId: monthId,
                                        prefillSubcategoryId: s.subcategoryId,
                                      ),
                                    ),
                                  );
                                  if (!context.mounted) return;
                                  context.read<DashboardBloc>().add(LoadDashboard(monthId));
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Forecast', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('Days: $daysElapsed / $daysInMonth'),
                          Text('Pace: $pace'),
                          const SizedBox(height: 6),
                          if (isCurrentMonth && totalBudget > 0) ...[
                            Text('Projected Spend (end of month): ${minorToRupees(projectedSpent)}'),
                            Text('Projected Remaining: ${minorToRupees(projectedRemaining)}'),
                          ] else ...[
                            const Text('Select current month to see projections'),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (isCurrentMonth && alerts.isNotEmpty) ...[
                    const Text('Alerts (Projected Over Budget)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...alerts.take(5).map((a) {
                      return Card(
                        child: ListTile(
                          title: Text(a.name),
                          subtitle: Text(
                            'Over by: ${minorToRupees(a.overByMinor)} | Limit: ${minorToRupees(a.limitMinor)}',
                          ),
                          trailing: Text(minorToRupees(a.projectedMinor)),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ] else if (isCurrentMonth) ...[
                    const Text('Alerts', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    const Text('No projected overspends. Keep it up.'),
                    const SizedBox(height: 12),
                  ],
                  const Text('Categories', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...state.categoryCards.map((c) {
                    final limitText = c.budgetLimit == null ? '-' : minorToRupees(c.budgetLimit!);
                    final remText = c.remaining == null ? '-' : minorToRupees(c.remaining!);

                    final overspent = c.budgetLimit != null && c.spent > c.budgetLimit!;
                    final proj = isCurrentMonth ? _projectMinor(c.spent, daysElapsed, daysInMonth) : c.spent;
                    final projOver = (isCurrentMonth && c.budgetLimit != null && proj > c.budgetLimit!);

                    return Card(
                      child: ListTile(
                        title: Text(c.categoryName),
                        subtitle: Text(
                          'Spent: ${minorToRupees(c.spent)} | Limit: $limitText | Remaining: $remText'
                              '${overspent ? "  (OVER)" : ""}'
                              '${projOver ? "  | Projected OVER by ${minorToRupees(proj - c.budgetLimit!)}" : ""}',
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryBreakdownScreen(
                                monthId: monthId,
                                categoryId: c.categoryId,
                                categoryName: c.categoryName,
                              ),
                            ),
                          );
                        },
                        onLongPress: () async {
                          final db = context.read<AppDatabase>();
                          final subIds = await db.getSubcategoryIdsByCategory(c.categoryId);
                          if (!context.mounted) return;

                          await _openTransactionsWithFilter(
                            context: context,
                            monthId: monthId,
                            filters: TxFilters(
                              type: TxTypeFilter.expense,
                              categoryId: c.categoryId,
                              categorySubcategoryIds: subIds,
                              sort: TxSort.newest,
                              search: '',
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _kpiCard({required String title, required List<String> lines}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(l),
              ),
          ],
        ),
      ),
    );
  }
}

class _AlertRow {
  _AlertRow({
    required this.name,
    required this.overByMinor,
    required this.projectedMinor,
    required this.limitMinor,
  });

  final String name;
  final int overByMinor;
  final int projectedMinor;
  final int limitMinor;
}
