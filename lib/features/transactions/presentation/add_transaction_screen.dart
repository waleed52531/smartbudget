import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/db/app_db.dart';
import '../../../core/storage/last_selection_store.dart';
import '../../../core/utils/money.dart';
import '../../categories/data/category_repository.dart';
import '../bloc/tranasaction_bloc.dart';
import '../bloc/tranasaction_event.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    required this.monthId,
    this.existing,
    this.prefillSubcategoryId,
  });

  final String monthId;

  /// If provided => EDIT mode
  final Transaction? existing;

  /// Optional quick-add (used by dashboard “top leaks” chips)
  final String? prefillSubcategoryId;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  final _lastStore = LastSelectionStore();

  bool isExpense = true;

  List<CategoryNode> categories = [];
  List<CategoryNode> subcategories = [];

  CategoryNode? selectedCategory;
  CategoryNode? selectedSubcategory;

  bool loading = true;
  String? error;

  late int dateMillis;

  bool get isEdit => widget.existing != null;

  DateTime _monthStart(String monthId) {
    final y = int.parse(monthId.substring(0, 4));
    final m = int.parse(monthId.substring(5, 7));
    return DateTime(y, m, 1);
  }

  DateTime _monthEnd(DateTime start) {
    return DateTime(start.year, start.month + 1, 0); // last day of month
  }

  int _defaultDateMillisForMonth(String monthId) {
    final start = _monthStart(monthId);
    final end = _monthEnd(start);

    final now = DateTime.now();
    final isCurrent = now.year == start.year && now.month == start.month;

    if (isCurrent) return now.millisecondsSinceEpoch;

    // For past/future months: default to last day @ noon
    final dt = DateTime(end.year, end.month, end.day, 12, 0);
    return dt.millisecondsSinceEpoch;
  }


  @override
  void initState() {
    super.initState();
    dateMillis = widget.existing?.dateMillis ?? _defaultDateMillisForMonth(widget.monthId);

    if (isEdit) {
      isExpense = widget.existing!.type == 'expense';
      amountCtrl.text = minorToRupees(widget.existing!.amountMinor);
      noteCtrl.text = widget.existing!.note ?? '';
    }

    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final catRepo = context.read<CategoryRepository>();
      categories = await catRepo.getCategories();

      // Default selection
      selectedCategory = categories.isNotEmpty ? categories.first : null;

      // 1) If EDIT and expense => locate category/subcategory by existing.subcategoryId
      if (isEdit && isExpense) {
        final subId = widget.existing!.subcategoryId;
        if (subId != null) {
          final found = await _findParentCategoryAndSub(catRepo, subId);
          if (found != null) {
            selectedCategory = found.$1;
            subcategories = await catRepo.getSubcategories(selectedCategory!.id);
            selectedSubcategory = found.$2;
          }
        }
      }

      // 2) If quick-add prefill
      if (!isEdit && widget.prefillSubcategoryId != null) {
        final found = await _findParentCategoryAndSub(catRepo, widget.prefillSubcategoryId!);
        if (found != null) {
          selectedCategory = found.$1;
          subcategories = await catRepo.getSubcategories(selectedCategory!.id);
          selectedSubcategory = found.$2;
          isExpense = true;
        }
      }

      // 3) Otherwise try restore last used (only for new expense)
      if (!isEdit && isExpense) {
        final (lastCatId, lastSubId) = await _lastStore.read();
        if (lastCatId != null) {
          final foundCat = categories.where((c) => c.id == lastCatId).toList();
          if (foundCat.isNotEmpty) selectedCategory = foundCat.first;
        }

        if (selectedCategory != null) {
          subcategories = await catRepo.getSubcategories(selectedCategory!.id);
          selectedSubcategory = subcategories.isNotEmpty ? subcategories.first : null;

          if (lastSubId != null) {
            final foundSub = subcategories.where((s) => s.id == lastSubId).toList();
            if (foundSub.isNotEmpty) selectedSubcategory = foundSub.first;
          }
        }
      }

      // Load subcategories if not loaded yet and category exists
      if (subcategories.isEmpty && selectedCategory != null) {
        subcategories = await catRepo.getSubcategories(selectedCategory!.id);
        selectedSubcategory = subcategories.isNotEmpty ? subcategories.first : null;
      }

      setState(() => loading = false);
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<(CategoryNode, CategoryNode)?> _findParentCategoryAndSub(
      CategoryRepository repo,
      String subId,
      ) async {
    for (final cat in categories) {
      final subs = await repo.getSubcategories(cat.id);
      final match = subs.where((s) => s.id == subId).toList();
      if (match.isNotEmpty) {
        return (cat, match.first);
      }
    }
    return null;
  }

  Future<void> _reloadSubcategories() async {
    if (selectedCategory == null) return;
    setState(() => loading = true);
    try {
      final catRepo = context.read<CategoryRepository>();
      subcategories = await catRepo.getSubcategories(selectedCategory!.id);
      if (subcategories.isNotEmpty) {
        if (selectedSubcategory == null ||
            !subcategories.any((x) => x.id == selectedSubcategory!.id)) {
          selectedSubcategory = subcategories.first;
        }
      } else {
        selectedSubcategory = null;
      }
      setState(() => loading = false);
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate() async {
    final start = _monthStart(widget.monthId);
    final end = _monthEnd(start);

    final current = DateTime.fromMillisecondsSinceEpoch(dateMillis).toLocal();

    // Keep initial date inside month
    DateTime initial = DateTime(current.year, current.month, current.day);
    if (initial.isBefore(start)) initial = start;
    if (initial.isAfter(end)) initial = end;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: start,
      lastDate: end,
    );
    if (picked == null) return;

    // keep time roughly same
    final updated = DateTime(
      picked.year,
      picked.month,
      picked.day,
      current.hour,
      current.minute,
      current.second,
    );

    setState(() => dateMillis = updated.millisecondsSinceEpoch);
  }


  Future<void> _save() async {
    try {
      final amountMinor = rupeesToMinor(amountCtrl.text);

      if (isExpense) {
        if (selectedCategory == null) {
          _toast('Select a category');
          return;
        }
        if (selectedSubcategory == null) {
          _toast('Select a subcategory');
          return;
        }
      }

      final note = noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim();

      if (isEdit) {
        final tx = widget.existing!;
        context.read<TransactionBloc>().add(
          UpdateTransactionRequested(
            id: tx.id,
            monthId: widget.monthId,
            type: isExpense ? 'expense' : 'income',
            amountMinor: amountMinor,
            dateMillis: dateMillis,
            subcategoryId: isExpense ? selectedSubcategory!.id : null,
            note: note,
          ),
        );
      } else {
        if (isExpense) {
          context.read<TransactionBloc>().add(
            AddExpenseRequested(
              monthId: widget.monthId,
              amountMinor: amountMinor,
              dateMillis: dateMillis,
              subcategoryId: selectedSubcategory!.id,
              note: note,
            ),
          );

          await _lastStore.write(
            categoryId: selectedCategory!.id,
            subcategoryId: selectedSubcategory!.id,
          );
        } else {
          context.read<TransactionBloc>().add(
            AddIncomeRequested(
              monthId: widget.monthId,
              amountMinor: amountMinor,
              dateMillis: dateMillis,
              note: note,
            ),
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _toast('Invalid input: $e');
    }
  }

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<CategoryNode>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SearchPickerBottomSheet<CategoryNode>(
        title: 'Select Category',
        items: categories,
        itemLabel: (c) => c.name,
        onAddRequested: () async {
          final name = await _nameDialog('Add Category');
          if (name == null) return null;
          try {
            await context.read<CategoryRepository>().addCategory(name);
            categories = await context.read<CategoryRepository>().getCategories();
            setState(() {});
          } catch (e) {
            _toast(e.toString());
          }
          return null;
        },
      ),
    );

    if (picked == null) return;

    setState(() {
      selectedCategory = picked;
      selectedSubcategory = null;
    });
    await _reloadSubcategories();
  }

  Future<void> _pickSubcategory() async {
    if (selectedCategory == null) {
      _toast('Add/select a category first');
      return;
    }

    final picked = await showModalBottomSheet<CategoryNode>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SearchPickerBottomSheet<CategoryNode>(
        title: 'Select Subcategory',
        items: subcategories,
        itemLabel: (s) => s.name,
        onAddRequested: () async {
          final name = await _nameDialog('Add Subcategory');
          if (name == null) return null;
          try {
            await context.read<CategoryRepository>().addSubcategory(
              categoryId: selectedCategory!.id,
              name: name,
            );
            await _reloadSubcategories();
          } catch (e) {
            _toast(e.toString());
          }
          return null;
        },
      ),
    );

    if (picked == null) return;
    setState(() => selectedSubcategory = picked);
  }

  Future<String?> _nameDialog(String title) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(body: Center(child: Text('Error: $error')));

    final date = DateTime.fromMillisecondsSinceEpoch(dateMillis).toLocal();

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Transaction' : 'Add Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Expense')),
                ButtonSegment(value: false, label: Text('Income')),
              ],
              selected: {isExpense},
              onSelectionChanged: isEdit
                  ? null // don’t allow changing type for edit unless you want chaos
                  : (s) => setState(() => isExpense = s.first),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (PKR)'),
            ),
            const SizedBox(height: 12),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text('${date.toString().substring(0, 10)}'),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: _pickDate,
            ),

            if (isExpense) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Category'),
                subtitle: Text(selectedCategory?.name ?? 'Select category'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickCategory,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Subcategory'),
                subtitle: Text(selectedSubcategory?.name ?? 'Select subcategory'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _pickSubcategory,
              ),
              const SizedBox(height: 8),
            ],

            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(isEdit ? 'Update' : 'Save'),
              ),
            ),
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
    required this.onAddRequested,
  });

  final String title;
  final List<T> items;
  final String Function(T) itemLabel;
  final Future<T?> Function() onAddRequested;

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
                    TextButton.icon(
                      onPressed: () async {
                        await widget.onAddRequested();
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
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
