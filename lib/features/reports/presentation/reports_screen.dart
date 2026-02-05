import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/db/app_db.dart';
import '../../../core/state/month_cubit.dart';
import '../../../core/ui/month_picker_sheet.dart';
import '../../../core/utils/money.dart';
import '../data/reports_repository.dart';
import '../../../core/db/report_models.dart';
import '../../budget/data/budget_repository.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  int _projectMinor(int spentMinor, int daysElapsed, int daysInMonth) {
    if (daysElapsed <= 0) return spentMinor;
    return ((spentMinor / daysElapsed) * daysInMonth).round();
  }

  List<_CutSuggestion> _buildCutPlan({
    required int gapMinor,
    required List<CategoryCardRow> topCats,
  }) {
    var remaining = gapMinor;
    final out = <_CutSuggestion>[];

    // simple plan: cut from biggest categories first, max 20% per category
    for (final c in topCats) {
      if (remaining <= 0) break;

      final maxCut = (c.spent * 0.20).round(); // 20%
      if (maxCut <= 0) continue;

      final cut = remaining < maxCut ? remaining : maxCut;
      out.add(_CutSuggestion(
        name: c.categoryName,
        cutMinor: cut,
        pct: (cut / (c.spent == 0 ? 1 : c.spent)) * 100.0,
      ));
      remaining -= cut;
    }

    return out;
  }

  @override
  Widget build(BuildContext context) {
    final monthId = context.watch<MonthCubit>().state;

    final reportsRepo = context.read<ReportsRepository>();
    final budgetRepo = context.read<BudgetRepository>();

    final selected = MonthCubit.toDate(monthId);
    final now = DateTime.now();
    final isCurrentMonth = (now.year == selected.year && now.month == selected.month);
    final daysInMonth = DateTime(selected.year, selected.month + 1, 0).day;
    final daysElapsed = isCurrentMonth ? now.day.clamp(1, daysInMonth) : daysInMonth;

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
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([
          reportsRepo.monthTotals(monthId),
          reportsRepo.topCategories(monthId),
          reportsRepo.topSubcategories(monthId),
          budgetRepo.getOrCreateMonth(monthId),
          budgetRepo.getLimitsForMonth(monthId),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final totals = snapshot.data![0] as MonthTotals;
          final topCats = snapshot.data![1] as List<CategoryCardRow>;
          final topSubs = snapshot.data![2] as List<SubcategoryRow>;
          final month = snapshot.data![3] as BudgetMonth;
          final limits = snapshot.data![4] as Map<String, int>;

          final totalSpent = totals.totalSpent;
          final totalIncome = totals.totalIncome;

          final totalBudget = month.totalBudgetMinor;
          final savingTarget = month.savingTargetMinor;
          final allowedSpend = (totalBudget - savingTarget);

          // Forecast (only meaningful for current month with a budget)
          final projectedSpent = isCurrentMonth ? _projectMinor(totalSpent, daysElapsed, daysInMonth) : totalSpent;
          final projectedSaving = totalBudget > 0 ? (totalBudget - projectedSpent) : 0;

          final savingNow = totalBudget > 0 ? (totalBudget - totalSpent) : 0;
          final savingGapNow = savingTarget > 0 ? (savingTarget - savingNow) : 0;

          final projectedGap = (savingTarget > 0) ? (savingTarget - projectedSaving) : 0;

          // Overspend risks (projected vs category limit if we can map categoryId->limit)
          final overspends = <_OverspendRow>[];
          for (final c in topCats) {
            final limit = limits[c.categoryId]; // IMPORTANT: CategoryCardRow must include categoryId
            if (limit == null) continue;

            final proj = isCurrentMonth ? _projectMinor(c.spent, daysElapsed, daysInMonth) : c.spent;
            if (proj > limit) {
              overspends.add(
                _OverspendRow(
                  name: c.categoryName,
                  limitMinor: limit,
                  projectedMinor: proj,
                  overByMinor: proj - limit,
                ),
              );
            }
          }
          overspends.sort((a, b) => b.overByMinor.compareTo(a.overByMinor));

          // Top leaks (subcategories)
          final denom = totalSpent == 0 ? 1 : totalSpent;
          final leaks = topSubs.take(5).map((s) {
            final pct = (s.spent / denom) * 100;
            return _LeakRow(
              name: s.subcategoryName,
              spentMinor: s.spent,
              pct: pct,
            );
          }).toList();

          // Cut plan to hit saving target (based on projected gap)
          final needCut = projectedGap > 0 ? projectedGap : 0;
          final cutPlan = needCut > 0 ? _buildCutPlan(gapMinor: needCut, topCats: topCats) : <_CutSuggestion>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _card(
                title: 'Summary',
                children: [
                  Text('Spent: ${minorToRupees(totalSpent)}'),
                  Text('Income: ${minorToRupees(totalIncome)}'),
                  const SizedBox(height: 8),
                  Text('Budget: ${minorToRupees(totalBudget)}'),
                  Text('Saving Target: ${minorToRupees(savingTarget)}'),
                ],
              ),

              const SizedBox(height: 12),

              _card(
                title: 'Saving Status',
                children: [
                  if (totalBudget <= 0) const Text('Set a total budget to unlock saving insights.'),
                  if (totalBudget > 0 && savingTarget <= 0) const Text('Set a saving target to unlock recommendations.'),
                  if (totalBudget > 0 && savingTarget > 0) ...[
                    Text('Saving Now: ${minorToRupees(savingNow)}'),
                    Text('Gap Now: ${savingGapNow > 0 ? minorToRupees(savingGapNow) : "On track"}'),
                    const SizedBox(height: 8),
                    if (isCurrentMonth) ...[
                      Text('Projected Spend: ${minorToRupees(projectedSpent)}'),
                      Text('Projected Saving: ${minorToRupees(projectedSaving)}'),
                      Text('Projected Gap: ${projectedGap > 0 ? minorToRupees(projectedGap) : "On track"}'),
                    ] else
                      const Text('Select current month for projections.'),
                    const SizedBox(height: 8),
                    if (allowedSpend > 0)
                      Text('Allowed Spend (Budget - Target): ${minorToRupees(allowedSpend)}'),
                  ],
                ],
              ),

              const SizedBox(height: 12),

              _card(
                title: 'Top Leaks (Subcategories)',
                children: [
                  if (leaks.isEmpty) const Text('No subcategory data yet.'),
                  ...leaks.map((l) => ListTile(
                    dense: true,
                    title: Text(l.name),
                    subtitle: Text('${l.pct.toStringAsFixed(1)}% of spending'),
                    trailing: Text(minorToRupees(l.spentMinor)),
                  )),
                ],
              ),

              const SizedBox(height: 12),

              _card(
                title: 'Overspend Risks (Projected vs Limits)',
                children: [
                  if (!isCurrentMonth) const Text('Select current month to see projected overspends.'),
                  if (isCurrentMonth && overspends.isEmpty) const Text('No projected overspends.'),
                  if (isCurrentMonth)
                    ...overspends.take(5).map((o) => ListTile(
                      dense: true,
                      title: Text(o.name),
                      subtitle: Text('Over by: ${minorToRupees(o.overByMinor)} | Limit: ${minorToRupees(o.limitMinor)}'),
                      trailing: Text(minorToRupees(o.projectedMinor)),
                    )),
                ],
              ),

              const SizedBox(height: 12),

              _card(
                title: 'Cut Plan (To Hit Saving Target)',
                children: [
                  if (!isCurrentMonth) const Text('Select current month to get actionable cut plan.'),
                  if (isCurrentMonth && savingTarget <= 0) const Text('Set a saving target first.'),
                  if (isCurrentMonth && savingTarget > 0 && needCut <= 0) const Text('No cuts needed. You’re on track.'),
                  if (isCurrentMonth && savingTarget > 0 && needCut > 0) ...[
                    Text('You need to cut ~${minorToRupees(needCut)} this month to hit target.'),
                    const SizedBox(height: 8),
                    ...cutPlan.map((c) => ListTile(
                      dense: true,
                      title: Text(c.name),
                      subtitle: Text('Suggested cut: ${c.pct.toStringAsFixed(1)}%'),
                      trailing: Text(minorToRupees(c.cutMinor)),
                    )),
                    if (cutPlan.isEmpty)
                      const Text('Not enough spending data to build a plan yet. Add more transactions.'),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LeakRow {
  _LeakRow({required this.name, required this.spentMinor, required this.pct});
  final String name;
  final int spentMinor;
  final double pct;
}

class _OverspendRow {
  _OverspendRow({
    required this.name,
    required this.limitMinor,
    required this.projectedMinor,
    required this.overByMinor,
  });
  final String name;
  final int limitMinor;
  final int projectedMinor;
  final int overByMinor;
}

class _CutSuggestion {
  _CutSuggestion({required this.name, required this.cutMinor, required this.pct});
  final String name;
  final int cutMinor;
  final double pct;
}
