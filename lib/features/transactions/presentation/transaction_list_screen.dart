import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/month_cubit.dart';
import '../../../core/ui/month_picker_sheet.dart';
import '../../../core/utils/money.dart';
import '../../categories/data/category_repository.dart';
import '../bloc/tranasaction_bloc.dart';
import '../bloc/tranasaction_event.dart';
import '../bloc/tranasaction_state.dart';
import 'add_transaction_screen.dart';

class TransactionsListScreen extends StatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  State<TransactionsListScreen> createState() => _TransactionsListScreenState();
}

class _TransactionsListScreenState extends State<TransactionsListScreen> {
  final _searchCtrl = TextEditingController();

  // filters
  String _q = '';
  String _type = 'all'; // all | expense | income
  String? _nodeId; // category/subcategory node id
  int? _minMinor;
  int? _maxMinor;

  // undo delete (UI-level)
  final Map<String, Timer> _deleteTimers = {};
  final Set<String> _pendingDeleteIds = {};

  // cache for category filter
  List<dynamic> _nodes = []; // CategoryNode list, kept dynamic to avoid compile if your model differs
  bool _loadingNodes = false;

  String? _lastMonthId;

  @override
  void initState() {
    super.initState();

    // initial load (DON’T use context.watch in initState)
    _lastMonthId = context.read<MonthCubit>().state;
    context.read<TransactionBloc>().add(LoadMonthTransactions(_lastMonthId!));

    _searchCtrl.addListener(() {
      setState(() => _q = _searchCtrl.text.trim().toLowerCase());
    });

    _loadCategoryNodes();
  }

  Future<void> _loadCategoryNodes() async {
    try {
      setState(() => _loadingNodes = true);
      final repo = context.read<CategoryRepository>();
      final items = await repo.getCategories(); // must return list with .id and .name
      if (!mounted) return;
      setState(() {
        _nodes = items;
        _loadingNodes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingNodes = false);
    }
  }

  @override
  void dispose() {
    for (final t in _deleteTimers.values) {
      t.cancel();
    }
    _deleteTimers.clear();
    _pendingDeleteIds.clear();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _clearPendingDeletes() {
    for (final t in _deleteTimers.values) {
      t.cancel();
    }
    _deleteTimers.clear();
    _pendingDeleteIds.clear();
  }

  bool _matches(dynamic tx) {
    // tx must have: id, type, amountMinor, dateMillis, note?, nodeId?
    final int id = tx.id as int;
    if (_pendingDeleteIds.contains(id)) return false;

    final String type = (tx.type as String?) ?? '';
    final int amount = (tx.amountMinor as int?) ?? 0;
    final String note = ((tx.note as String?) ?? '').toLowerCase();
    final String nodeId = (tx.nodeId as String?) ?? '';

    if (_type != 'all' && type != _type) return false;
    if (_minMinor != null && amount < _minMinor!) return false;
    if (_maxMinor != null && amount > _maxMinor!) return false;
    if (_nodeId != null && _nodeId!.isNotEmpty && nodeId != _nodeId) return false;

    if (_q.isNotEmpty) {
      final amountText = amount.toString(); // crude but works
      if (!note.contains(_q) && !amountText.contains(_q) && !type.contains(_q)) {
        return false;
      }
    }

    return true;
  }

  Future<void> _openFiltersSheet() async {
    final minCtrl = TextEditingController(text: _minMinor == null ? '' : minorToRupees(_minMinor!));
    final maxCtrl = TextEditingController(text: _maxMinor == null ? '' : minorToRupees(_maxMinor!));

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        String localType = _type;
        String? localNodeId = _nodeId;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final bottom = MediaQuery.of(ctx).viewInsets.bottom;

            return Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: localType,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'expense', child: Text('Expense')),
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                    ],
                    onChanged: (v) => setLocal(() => localType = v ?? 'all'),
                    decoration: const InputDecoration(labelText: 'Type'),
                  ),

                  const SizedBox(height: 10),

                  if (_loadingNodes)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Loading categories...'),
                    )
                  else
                    DropdownButtonFormField<String?>(
                      value: localNodeId,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                        ..._nodes.map((n) {
                          // expects n.id and n.name
                          final id = (n.id as String);
                          final name = (n.name as String);
                          return DropdownMenuItem<String?>(
                            value: id,
                            child: Text(name),
                          );
                        }),
                      ],
                      onChanged: (v) => setLocal(() => localNodeId = v),
                      decoration: const InputDecoration(labelText: 'Category/Subcategory'),
                    ),

                  const SizedBox(height: 10),

                  TextField(
                    controller: minCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Min amount (PKR)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: maxCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Max amount (PKR)'),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _type = 'all';
                              _nodeId = null;
                              _minMinor = null;
                              _maxMinor = null;
                            });
                            Navigator.pop(ctx);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            int? parsedMin;
                            int? parsedMax;

                            if (minCtrl.text.trim().isNotEmpty) {
                              parsedMin = rupeesToMinor(minCtrl.text.trim());
                            }
                            if (maxCtrl.text.trim().isNotEmpty) {
                              parsedMax = rupeesToMinor(maxCtrl.text.trim());
                            }

                            setState(() {
                              _type = localType;
                              _nodeId = localNodeId;
                              _minMinor = parsedMin;
                              _maxMinor = parsedMax;
                            });

                            Navigator.pop(ctx);
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _deleteWithUndo({
    required String id,
    required String monthId,
  }) {
    // hide immediately
    setState(() => _pendingDeleteIds.add(id));

    // cancel any existing timer for same id
    _deleteTimers[id]?.cancel();

    final timer = Timer(const Duration(seconds: 4), () {
      // if still pending after 4 seconds -> actually delete
      if (!mounted) return;
      if (_pendingDeleteIds.contains(id)) {
        context.read<TransactionBloc>().add(
          DeleteTransactionRequested(id: id, monthId: monthId),
        );
        setState(() => _pendingDeleteIds.remove(id));
      }
      _deleteTimers.remove(id);
    });

    _deleteTimers[id] = timer;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: const Text('Transaction deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            _deleteTimers[id]?.cancel();
            _deleteTimers.remove(id);
            setState(() => _pendingDeleteIds.remove(id));
          },
        ),
      ),
    );
  }

  String _activeFiltersText() {
    final parts = <String>[];
    if (_type != 'all') parts.add(_type);
    if (_nodeId != null) parts.add('category');
    if (_minMinor != null) parts.add('min');
    if (_maxMinor != null) parts.add('max');
    if (_q.isNotEmpty) parts.add('search');
    if (parts.isEmpty) return 'No filters';
    return 'Filters: ${parts.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MonthCubit, String>(
      listener: (context, newMonthId) {
        if (_lastMonthId == newMonthId) return;
        _lastMonthId = newMonthId;

        _clearPendingDeletes();

        // reload when month changes
        context.read<TransactionBloc>().add(LoadMonthTransactions(newMonthId));
      },
      child: Builder(
        builder: (context) {
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
                  icon: const Icon(Icons.tune_outlined),
                  onPressed: _openFiltersSheet,
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
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(84),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search note / type / amount',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _q.isEmpty
                              ? null
                              : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _activeFiltersText(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                if (state.status == TxStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == TxStatus.failure) {
                  return Center(child: Text('Error: ${state.error}'));
                }

                final items = state.items.where(_matches).toList();

                if (items.isEmpty) {
                  return const Center(child: Text('No transactions found.'));
                }

                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = items[i];
                    final isExpense = t.type == 'expense';
                    final amount = minorToRupees(t.amountMinor);
                    final date = DateTime.fromMillisecondsSinceEpoch(t.dateMillis).toLocal();

                    return ListTile(
                      title: Text('${isExpense ? "Expense" : "Income"}  $amount'),
                      subtitle: Text('${date.toString().substring(0, 16)}  |  ${t.note ?? ""}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteWithUndo(id: t.id, monthId: monthId),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
