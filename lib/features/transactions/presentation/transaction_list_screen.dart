import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/db/app_db.dart';
import '../../../core/state/month_cubit.dart';
import '../../../core/ui/month_picker_sheet.dart';
import '../../../core/utils/money.dart';
import '../../reports/presentation/bloc/export_bloc.dart';
import '../../reports/presentation/bloc/export_event.dart';
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

  String _q = '';
  String _type = 'all'; // all | expense | income

  /// can be either a categoryId (cat_*) or subcategoryId (sub_*)
  String? _pickedNodeId;

  int? _minMinor;
  int? _maxMinor;

  // undo delete (Transaction.id is String)
  final Map<String, Timer> _deleteTimers = {};
  final Set<String> _pendingDeleteIds = {};

  // category/subcategory data
  bool _loadingNodes = false;
  final Map<String, CategoryNode> _idToNode = {};
  final Map<String, String> _subToParent = {}; // subId -> catId

  String? _lastMonthId;

  @override
  void initState() {
    super.initState();

    _lastMonthId = context.read<MonthCubit>().state;
    context.read<TransactionBloc>().add(LoadMonthTransactions(_lastMonthId!));

    _searchCtrl.addListener(() {
      setState(() => _q = _searchCtrl.text.trim().toLowerCase());
    });

    _loadNodes();
  }

  Future<void> _loadNodes() async {
    try {
      setState(() => _loadingNodes = true);
      final db = context.read<AppDatabase>();

      final rows = await (db.select(db.categoryNodes)
        ..where((n) => n.archived.equals(false))
        ..orderBy([
              (n) => OrderingTerm(expression: n.sortOrder),
              (n) => OrderingTerm(expression: n.name),
        ]))
          .get();

      _idToNode.clear();
      _subToParent.clear();

      for (final n in rows) {
        _idToNode[n.id] = n;
        if (n.type == 'subcategory' && n.parentId != null) {
          _subToParent[n.id] = n.parentId!;
        }
      }

      if (!mounted) return;
      setState(() => _loadingNodes = false);
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

  bool _matches(Transaction tx) {
    if (_pendingDeleteIds.contains(tx.id)) return false;

    if (_type != 'all' && tx.type != _type) return false;

    final amount = tx.amountMinor;
    if (_minMinor != null && amount < _minMinor!) return false;
    if (_maxMinor != null && amount > _maxMinor!) return false;

    // Filter by category/subcategory (tx stores ONLY subcategoryId)
    if (_pickedNodeId != null && _pickedNodeId!.isNotEmpty) {
      final picked = _pickedNodeId!;
      final subId = tx.subcategoryId; // nullable for income

      // picked a subcategory -> exact match
      if (picked.startsWith('sub_')) {
        if (subId == null || subId != picked) return false;
      }

      // picked a category -> match by subcategory parentId
      if (picked.startsWith('cat_')) {
        if (subId == null) return false;
        final parent = _subToParent[subId];
        if (parent != picked) return false;
      }
    }

    if (_q.isNotEmpty) {
      final note = (tx.note ?? '').toLowerCase();
      final amountText = amount.toString();
      if (!note.contains(_q) && !amountText.contains(_q) && !tx.type.contains(_q)) {
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
        String? localPicked = _pickedNodeId;

        final cats = _idToNode.values.where((n) => n.type == 'category').toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final subs = _idToNode.values.where((n) => n.type == 'subcategory').toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

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
                    const Align(alignment: Alignment.centerLeft, child: Text('Loading categories...'))
                  else
                    DropdownButtonFormField<String?>(
                      value: localPicked,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                        ...cats.map((c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text('${c.name} (All)'),
                        )),
                        ...subs.map((s) {
                          final parentName = s.parentId == null ? '' : (_idToNode[s.parentId!]?.name ?? '');
                          return DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text('$parentName > ${s.name}'),
                          );
                        }),
                      ],
                      onChanged: (v) => setLocal(() => localPicked = v),
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
                              _pickedNodeId = null;
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
                              _pickedNodeId = localPicked;
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
    setState(() => _pendingDeleteIds.add(id));
    _deleteTimers[id]?.cancel();

    final timer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_pendingDeleteIds.contains(id)) {
        context.read<TransactionBloc>().add(DeleteTransactionRequested(id: id, monthId: monthId));
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
    if (_pickedNodeId != null) parts.add(_pickedNodeId!.startsWith('cat_') ? 'category' : 'subcategory');
    if (_minMinor != null) parts.add('min');
    if (_maxMinor != null) parts.add('max');
    if (_q.isNotEmpty) parts.add('search');
    return parts.isEmpty ? 'No filters' : 'Filters: ${parts.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MonthCubit, String>(
      listener: (context, newMonthId) {
        if (_lastMonthId == newMonthId) return;
        _lastMonthId = newMonthId;

        _clearPendingDeletes();
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
                IconButton(icon: const Icon(Icons.tune_outlined), onPressed: _openFiltersSheet),
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

                /// ✅ EXPORT (fixed)
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: () {
                    context.read<ExportBloc>().add(
                      ExportFilteredRequested(
                        monthId: monthId,
                        query: _q.isEmpty ? null : _q,
                        type: _type == 'all' ? null : _type,
                        subcategoryId: _pickedNodeId,
                        minMinor: _minMinor,
                        maxMinor: _maxMinor,
                      ),
                    );
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
                        child: Text(_activeFiltersText(), style: Theme.of(context).textTheme.bodySmall),
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

                    final subName = t.subcategoryId == null ? null : _idToNode[t.subcategoryId!]?.name;

                    return ListTile(
                      title: Text('${isExpense ? "Expense" : "Income"}  $amount'),
                      subtitle: Text(
                        '${date.toString().substring(0, 16)}'
                            '  |  ${subName ?? (t.subcategoryId ?? "")}'
                            '  |  ${t.note ?? ""}',
                      ),
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
