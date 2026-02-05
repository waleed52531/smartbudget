import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/month_cubit.dart';
import '../../../core/ui/month_picker_sheet.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/month_id.dart';
import '../../categories/presentation/manage_categories_screen.dart';
import '../data/budget_repository.dart';
import 'bloc/budget_bloc.dart';
import 'bloc/budget_event.dart';
import 'bloc/budget_state.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final totalCtrl = TextEditingController();
  final savingCtrl = TextEditingController();

  String? _prefilledMonthId;

  @override
  void dispose() {
    totalCtrl.dispose();
    savingCtrl.dispose();
    super.dispose();
  }

  void _saveMonth(String monthId) {
    try {
      final total = rupeesToMinor(totalCtrl.text);
      final saving = rupeesToMinor(savingCtrl.text);

      context.read<BudgetBloc>().add(
        SaveMonthBudgetRequested(
          monthId: monthId,
          totalBudgetMinor: total,
          savingTargetMinor: saving,
        ),
      );
      // ✅ don't show snackbar here (BlocListener will handle)
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid input: $e')),
      );
    }
  }

  Future<void> _setCategoryLimit(
      BuildContext context,
      String monthId,
      String categoryId,
      String categoryName,
      int? currentLimit,
      ) async {
    final ctrl = TextEditingController(
      text: currentLimit == null ? '' : minorToRupees(currentLimit),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Set limit: $categoryName'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'e.g., 30000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null) return;

    if (result.isEmpty) {
      context.read<BudgetBloc>().add(
        ClearCategoryLimitRequested(monthId: monthId, categoryId: categoryId),
      );
      return;
    }

    try {
      final limitMinor = rupeesToMinor(result);
      context.read<BudgetBloc>().add(
        SetCategoryLimitRequested(
          monthId: monthId,
          categoryId: categoryId,
          limitMinor: limitMinor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid limit: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthId = context.watch<MonthCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text('Budget Setup (${MonthCubit.display(monthId)})'),
        actions: [
          // Calendar picker
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async {
              final picked = await showMonthPickerSheet(
                context,
                MonthCubit.toDate(monthId),
              );
              if (picked != null && context.mounted) {
                context.read<MonthCubit>().setFromDate(picked);
              }
            },
          ),

          // Copy previous month
          IconButton(
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              final prev = previousMonthId(monthId);

              final mode = await showDialog<CopyMode>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Copy previous month budget?'),
                  content: Text(
                    'Copy from $prev into $monthId.\n\n'
                        'Merge = copy only missing values.\n'
                        'Overwrite = replace everything.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, CopyMode.mergeMissingOnly),
                      child: const Text('Merge'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, CopyMode.overwriteAll),
                      child: const Text('Overwrite'),
                    ),
                  ],
                ),
              );

              if (mode == null) return;

              context.read<BudgetBloc>().add(
                CopyFromPreviousMonthRequested(monthId: monthId, mode: mode),
              );
            },
          ),

          // Manage categories
          IconButton(
            icon: const Icon(Icons.category_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
              );
            },
          ),
        ],
      ),

      body: BlocListener<BudgetBloc, BudgetState>(
        listener: (context, state) {
          final msg = state.toastMessage;
          if (msg == null) return;

          // ✅ Important: if copy happened, force prefill refresh
          if (msg.contains('Copied budget')) {
            _prefilledMonthId = null;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );

          context.read<BudgetBloc>().add(const ClearBudgetToast());
        },
        child: BlocBuilder<BudgetBloc, BudgetState>(
          builder: (context, state) {
            if (state.status == BudgetStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == BudgetStatus.failure) {
              return Center(child: Text('Error: ${state.error}'));
            }
            if (state.status != BudgetStatus.loaded || state.month == null) {
              return const Center(child: Text('Loading...'));
            }

            // Prefill only when month changes (prevents cursor jumping)
            if (_prefilledMonthId != monthId) {
              totalCtrl.text = minorToRupees(state.month!.totalBudgetMinor);
              savingCtrl.text = minorToRupees(state.month!.savingTargetMinor);
              _prefilledMonthId = monthId;
            }

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: totalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total Monthly Budget (PKR)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: savingCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Saving Target (PKR)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _saveMonth(monthId),
                      child: const Text('Save Month Budget'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Category Limits',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: state.categories.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = state.categories[i];
                        final limit = state.categoryLimits[c.id];

                        return ListTile(
                          title: Text(c.name),
                          subtitle: Text(
                            limit == null ? 'No limit set' : 'Limit: ${minorToRupees(limit)}',
                          ),
                          trailing: const Icon(Icons.edit),
                          onTap: () => _setCategoryLimit(
                            context,
                            monthId,
                            c.id,
                            c.name,
                            limit,
                          ),
                        );
                      },
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
}
