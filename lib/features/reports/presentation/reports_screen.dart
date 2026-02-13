import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smartbudget/features/reports/presentation/reportsbloc/reports_bloc.dart';
import 'package:smartbudget/features/reports/presentation/reportsbloc/reports_event.dart';
import 'package:smartbudget/features/reports/presentation/reportsbloc/reports_state.dart';

import '../../../core/db/app_db.dart';
import '../../../core/state/month_cubit.dart';
import '../../../core/ui/month_picker_sheet.dart';
import '../../../core/utils/money.dart';
import '../../categories/presentation/category_breakdown_screen.dart';
import '../../transactions/bloc/tranasaction_bloc.dart';
import '../../transactions/bloc/tranasaction_event.dart';
import '../../transactions/bloc/tx_filters.dart';
import '../../transactions/presentation/transaction_list_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _lastMonth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final monthId = context.watch<MonthCubit>().state;

    if (_lastMonth != monthId) {
      _lastMonth = monthId;
      context.read<ReportsBloc>().add(LoadReports(monthId: monthId));
    }
  }

  double _ratio(int a, int b) {
    if (b <= 0) return 0;
    final r = a / b;
    if (r.isNaN || r.isInfinite) return 0;
    return r.clamp(0, 1).toDouble();
  }

  Future<void> _openCategoryTransactions({
    required BuildContext context,
    required String monthId,
    required String categoryId,
  }) async {
    final db = context.read<AppDatabase>();
    final subIds = await db.getSubcategoryIdsByCategory(categoryId);
    if (!context.mounted) return;

    context.read<TransactionBloc>().add(
      ApplyTxFiltersRequested(
        monthId: monthId,
        filters: TxFilters(
          type: TxTypeFilter.expense,
          categoryId: categoryId,
          categorySubcategoryIds: subIds,
          sort: TxSort.newest,
          search: '',
        ),
      ),
    );
    context.read<TransactionBloc>().add(LoadMonthTransactions(monthId));

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionsListScreen()),
    );
  }

  Future<void> _openSubcategoryTransactions({
    required BuildContext context,
    required String monthId,
    required String subcategoryId,
  }) async {
    // ✅ enforce month so your tx screen doesn't show wrong month
    final current = context.read<MonthCubit>().state;
    if (current != monthId) {
      context.read<MonthCubit>().setFromDate(MonthCubit.toDate(monthId));
    }

    context.read<TransactionBloc>().add(
      ApplyTxFiltersRequested(
        monthId: monthId,
        filters: TxFilters(
          type: TxTypeFilter.expense,
          subcategoryId: subcategoryId,
          sort: TxSort.newest,
          search: '',
        ),
      ),
    );
    context.read<TransactionBloc>().add(LoadMonthTransactions(monthId));

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionsListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthId = context.watch<MonthCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text('Reports (${MonthCubit.display(monthId)})'),
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
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => context.read<ReportsBloc>().add(
              LoadReports(monthId: monthId, force: true),
            ),
          ),
        ],
      ),
      body: BlocListener<ReportsBloc, ReportsState>(
        listener: (context, s) {
          if (s.toast == null) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.toast!)));
          context.read<ReportsBloc>().add(const ClearReportsToast());
        },
        child: BlocBuilder<ReportsBloc, ReportsState>(
          builder: (context, s) {
            if (s.status == ReportsStatus.loading || s.status == ReportsStatus.idle) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.status == ReportsStatus.failure) {
              return Center(child: Text('Error: ${s.error}'));
            }

            final totals = s.totals!;
            final month = s.monthBudget;
            final cats = s.topCategories;
            final subs = s.topSubcategories;

            final totalBudget = month?.totalBudgetMinor ?? 0;
            final savingTarget = month?.savingTargetMinor ?? 0;
            final allowedSpend = (totalBudget - savingTarget);

            final spent = totals.totalSpent;
            final income = totals.totalIncome;

            final spendVsBudget = _ratio(spent, totalBudget);
            final spendVsAllowed = _ratio(spent, allowedSpend);

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ReportsBloc>().add(LoadReports(monthId: monthId, force: true));
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _card(
                    title: 'Summary',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Spent: ${minorToRupees(spent)}'),
                        Text('Income: ${minorToRupees(income)}'),
                        const SizedBox(height: 10),
                        Text('Budget: ${minorToRupees(totalBudget)}'),
                        Text('Saving Target: ${minorToRupees(savingTarget)}'),
                        const SizedBox(height: 12),
                        const Text('Spent vs Total Budget'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: spendVsBudget),
                        const SizedBox(height: 12),
                        const Text('Spent vs Allowed Spend (Budget - Saving Target)'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: spendVsAllowed),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  _card(
                    title: 'Top Categories (Bar Chart)',
                    child: cats.isEmpty
                        ? const Text('No category data yet.')
                        : _SimpleBarList(
                      rows: cats.map((c) {
                        final limit = c.budgetLimit;
                        final over = (limit != null && c.spent > limit);
                        return _BarRow(
                          label: c.categoryName,
                          valueMinor: c.spent,
                          rightText: minorToRupees(c.spent) + (over ? '  (OVER)' : ''),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  _card(
                    title: 'Top Subcategories (Bar Chart)',
                    child: subs.isEmpty
                        ? const Text('No subcategory data yet.')
                        : _SimpleBarList(
                      rows: subs.map((x) {
                        return _BarRow(
                          label: x.subcategoryName,
                          valueMinor: x.spent,
                          rightText: minorToRupees(x.spent),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ✅ NEW: separate tappable list
                  _card(
                    title: 'Top Subcategories (Tap to open transactions)',
                    child: subs.isEmpty
                        ? const Text('No subcategory data yet.')
                        : Column(
                      children: subs.take(10).map((x) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(x.subcategoryName),
                          trailing: Text(minorToRupees(x.spent)),
                          onTap: () => _openSubcategoryTransactions(
                            context: context,
                            monthId: monthId,
                            subcategoryId: x.subcategoryId,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  _card(
                    title: 'Budget Deltas (Top Categories)',
                    child: cats.isEmpty
                        ? const Text('No category data yet.')
                        : Column(
                      children: cats.map((c) {
                        final limit = c.budgetLimit;
                        final remaining = c.remaining;

                        final limitText = limit == null ? '-' : minorToRupees(limit);
                        final remText = remaining == null ? '-' : minorToRupees(remaining);

                        return ListTile(
                          dense: true,
                          title: Text(c.categoryName),
                          subtitle: Text('Limit: $limitText | Remaining: $remText'),
                          trailing: Text(minorToRupees(c.spent)),
                          onTap: () => _openCategoryTransactions(
                            context: context,
                            monthId: monthId,
                            categoryId: c.categoryId,
                          ),
                          onLongPress: () {
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
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _BarRow {
  _BarRow({required this.label, required this.valueMinor, required this.rightText});
  final String label;
  final int valueMinor;
  final String rightText;
}

class _SimpleBarList extends StatelessWidget {
  const _SimpleBarList({required this.rows});
  final List<_BarRow> rows;

  @override
  Widget build(BuildContext context) {
    final maxVal = rows.fold<int>(0, (m, r) => r.valueMinor > m ? r.valueMinor : m);
    final denom = maxVal <= 0 ? 1 : maxVal;

    return Column(
      children: rows.take(8).map((r) {
        final frac = (r.valueMinor / denom).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(r.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Text(r.rightText),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: frac),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
