import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/db/app_db.dart';
import '../../../core/state/month_cubit.dart';
import '../../../core/ui/month_picker_sheet.dart';
import '../../../core/utils/money.dart';
import '../../categories/data/category_repository.dart';
import '../bloc/tranasaction_bloc.dart';
import '../bloc/tranasaction_event.dart';
import '../bloc/tranasaction_state.dart';
import '../bloc/tx_filters.dart';
import 'add_transaction_screen.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  String? _lastMonthId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final monthId = context.watch<MonthCubit>().state;
    if (_lastMonthId != monthId) {
      _lastMonthId = monthId;
      context.read<TransactionBloc>().add(LoadMonthTransactions(monthId));
    }
  }

  Future<void> _openFilters(BuildContext context) async {
    final root = context; // use this for Bloc/Repo access (safer than sheet ctx)

    final monthId = root.read<MonthCubit>().state;
    final current = root.read<TransactionBloc>().state.filters;
    final catRepo = root.read<CategoryRepository>();

    TxTypeFilter type = current.type;
    TxSort sort = current.sort;

    DateTime? from =
    current.fromMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(current.fromMillis!).toLocal();
    DateTime? to =
    current.toMillis == null ? null : DateTime.fromMillisecondsSinceEpoch(current.toMillis!).toLocal();

    final minCtrl = TextEditingController(
      text: current.minMinor == null ? '' : minorToRupees(current.minMinor!),
    );
    final maxCtrl = TextEditingController(
      text: current.maxMinor == null ? '' : minorToRupees(current.maxMinor!),
    );
    final searchCtrl = TextEditingController(text: current.search);

    String? categoryId = current.categoryId;
    String? subcategoryId = current.subcategoryId;

    // Load categories/subcategories
    final cats = await catRepo.getCategories();
    List<CategoryNode> subs = [];

    CategoryNode? selectedCat = categoryId == null ? null : cats.firstWhereOrNull((x) => x.id == categoryId);
    if (selectedCat != null) subs = await catRepo.getSubcategories(selectedCat.id);

    CategoryNode? selectedSub = subcategoryId == null ? null : subs.firstWhereOrNull((x) => x.id == subcategoryId);

    if (!mounted) return;

    await showModalBottomSheet(
      context: root,
      isScrollControlled: true,
      builder: (sheetCtx) {
        String? moneyError; // show validation inside the sheet

        int? _safeMoneyToMinor(String raw, {required String label}) {
          final t = raw.trim();
          if (t.isEmpty) return null;

          // basic sanitization: allow "30,000"
          final cleaned = t.replaceAll(',', '');

          try {
            return rupeesToMinor(cleaned);
          } catch (_) {
            moneyError = '$label is invalid';
            return null;
          }
        }

        String _fmtDate(DateTime d) => d.toString().substring(0, 10);

        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> pickRange() async {
              final initial = DateTime.now();
              final picked = await showDateRangePicker(
                context: ctx,
                firstDate: DateTime(2020),
                lastDate: DateTime(initial.year + 1),
                initialDateRange: (from != null && to != null) ? DateTimeRange(start: from!, end: to!) : null,
              );
              if (picked == null) return;
              setSheet(() {
                from = picked.start;
                to = picked.end;
              });
            }

            Future<void> pickCategory() async {
              final picked = await showModalBottomSheet<CategoryNode>(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => _SearchPickerBottomSheet<CategoryNode>(
                  title: 'Select Category',
                  items: cats,
                  itemLabel: (c) => c.name,
                ),
              );
              if (picked == null) return;

              final newSubs = await catRepo.getSubcategories(picked.id);
              setSheet(() {
                selectedCat = picked;
                categoryId = picked.id;

                subs = newSubs;
                selectedSub = null;
                subcategoryId = null;
              });
            }

            Future<void> pickSubcategory() async {
              if (selectedCat == null) return;

              final picked = await showModalBottomSheet<CategoryNode>(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => _SearchPickerBottomSheet<CategoryNode>(
                  title: 'Select Subcategory',
                  items: subs,
                  itemLabel: (s) => s.name,
                ),
              );
              if (picked == null) return;

              setSheet(() {
                selectedSub = picked;
                subcategoryId = picked.id;
              });
            }

            Future<void> apply() async {
              setSheet(() => moneyError = null);

              // ✅ Safe parsing (no crash)
              final minMinor = _safeMoneyToMinor(minCtrl.text, label: 'Min amount');
              final maxMinor = _safeMoneyToMinor(maxCtrl.text, label: 'Max amount');

              // if parsing failed, show message and stay open
              if (moneyError != null) {
                setSheet(() {});
                return;
              }

              // ✅ min <= max validation
              if (minMinor != null && maxMinor != null && minMinor > maxMinor) {
                setSheet(() => moneyError = 'Min amount can’t be greater than Max amount');
                return;
              }

              // If user selected category but not subcategory -> filter by all subs of that category
              List<String>? catSubIds;
              if (subcategoryId == null && categoryId != null) {
                final list = await catRepo.getSubcategories(categoryId!);
                catSubIds = list.map((e) => e.id).toList();
              }

              final f = TxFilters(
                type: type,
                sort: sort,
                search: searchCtrl.text.trim(),
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                categorySubcategoryIds: catSubIds,
                fromMillis: from == null
                    ? null
                    : DateTime(from!.year, from!.month, from!.day, 0, 0).millisecondsSinceEpoch,
                toMillis: to == null
                    ? null
                    : DateTime(to!.year, to!.month, to!.day, 23, 59, 59).millisecondsSinceEpoch,
                minMinor: minMinor,
                maxMinor: maxMinor,
              );

              root.read<TransactionBloc>().add(
                ApplyTxFiltersRequested(monthId: monthId, filters: f),
              );
              Navigator.pop(ctx);
            }

            void clear() {
              root.read<TransactionBloc>().add(
                ClearTxFiltersRequested(monthId: monthId),
              );
              Navigator.pop(ctx);
            }

            final pad = MediaQuery.of(ctx).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.only(bottom: pad),
              child: SafeArea(
                child: SizedBox(
                  height: 660,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text('Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            ),
                            TextButton(onPressed: clear, child: const Text('Clear')),
                            const SizedBox(width: 8),
                            ElevatedButton(onPressed: apply, child: const Text('Apply')),
                          ],
                        ),
                      ),

                      if (moneyError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              moneyError!,
                              style: TextStyle(color: Theme.of(ctx).colorScheme.error, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: searchCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Search note',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SegmentedButton<TxTypeFilter>(
                          segments: const [
                            ButtonSegment(value: TxTypeFilter.all, label: Text('All')),
                            ButtonSegment(value: TxTypeFilter.expense, label: Text('Expense')),
                            ButtonSegment(value: TxTypeFilter.income, label: Text('Income')),
                          ],
                          selected: {type},
                          onSelectionChanged: (s) => setSheet(() => type = s.first),
                        ),
                      ),
                      const SizedBox(height: 12),

                      ListTile(
                        title: const Text('Date range'),
                        subtitle: Text(from == null || to == null ? 'Any' : '${_fmtDate(from!)} → ${_fmtDate(to!)}'),
                        trailing: const Icon(Icons.date_range_outlined),
                        onTap: pickRange,
                      ),

                      ListTile(
                        title: const Text('Category'),
                        subtitle: Text(selectedCat?.name ?? 'Any'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: pickCategory,
                      ),

                      ListTile(
                        title: const Text('Subcategory'),
                        subtitle: Text(selectedSub?.name ?? (selectedCat == null ? 'Select category first' : 'Any')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: selectedCat == null ? null : pickSubcategory,
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: minCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Min PKR'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: maxCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'Max PKR'),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DropdownButtonFormField<TxSort>(
                          value: sort,
                          decoration: const InputDecoration(labelText: 'Sort'),
                          items: const [
                            DropdownMenuItem(value: TxSort.newest, child: Text('Newest')),
                            DropdownMenuItem(value: TxSort.oldest, child: Text('Oldest')),
                            DropdownMenuItem(value: TxSort.amountHigh, child: Text('Amount high → low')),
                            DropdownMenuItem(value: TxSort.amountLow, child: Text('Amount low → high')),
                          ],
                          onChanged: (v) => setSheet(() => sort = v ?? TxSort.newest),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthId = context.watch<MonthCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions (${MonthCubit.display(monthId)})'),
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
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () => _openFilters(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddTransactionScreen(monthId: monthId)),
              );
              if (!context.mounted) return;
              context.read<TransactionBloc>().add(LoadMonthTransactions(monthId));
            },
          ),
        ],
      ),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        builder: (context, state) {
          if (state.status == TxStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == TxStatus.failure) {
            return Center(child: Text('Error: ${state.error}'));
          }

          final items = state.items;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return _summaryCard(state);
              }

              final t = items[i - 1];
              final isExpense = t.type == 'expense';
              final amount = minorToRupees(t.amountMinor);
              final date = DateTime.fromMillisecondsSinceEpoch(t.dateMillis).toLocal();

              return Card(
                child: ListTile(
                  title: Text('${isExpense ? "Expense" : "Income"}  $amount'),
                  subtitle: Text('${date.toString().substring(0, 16)}  |  ${t.note ?? ""}'),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddTransactionScreen(monthId: monthId, existing: t)),
                    );
                    if (!context.mounted) return;
                    context.read<TransactionBloc>().add(LoadMonthTransactions(monthId));
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      context.read<TransactionBloc>().add(
                        DeleteTransactionRequested(id: t.id, monthId: monthId),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryCard(TransactionState s) {
    final exp = minorToRupees(s.totalExpenseMinor);
    final inc = minorToRupees(s.totalIncomeMinor);
    final net = minorToRupees(s.netMinor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Expense: $exp'),
            Text('Income: $inc'),
            Text('Net: $net'),
            const SizedBox(height: 10),
            if (s.filters.hasAny)
              Text(
                'Filters active',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            else
              const Text('No filters'),
          ],
        ),
      ),
    );
  }
}

class _SearchPickerBottomSheet<T> extends StatefulWidget {
  const _SearchPickerBottomSheet({
    required this.title,
    required this.items,
    required this.itemLabel,
  });

  final String title;
  final List<T> items;
  final String Function(T) itemLabel;

  @override
  State<_SearchPickerBottomSheet<T>> createState() => _SearchPickerBottomSheetState<T>();
}

class _SearchPickerBottomSheetState<T> extends State<_SearchPickerBottomSheet<T>> {
  final searchCtrl = TextEditingController();
  late List<T> filtered;

  @override
  void initState() {
    super.initState();
    filtered = widget.items;
    searchCtrl.addListener(_apply);
  }

  void _apply() {
    final q = searchCtrl.text.trim().toLowerCase();
    setState(() {
      filtered = q.isEmpty
          ? widget.items
          : widget.items.where((x) => widget.itemLabel(x).toLowerCase().contains(q)).toList();
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: 520,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(child: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    return ListTile(
                      title: Text(widget.itemLabel(item)),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension FirstWhereOrNullExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final x in this) {
      if (test(x)) return x;
    }
    return null;
  }
}

