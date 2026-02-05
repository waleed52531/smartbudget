import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/db/app_db.dart';
import '../../../core/storage/last_selection_store.dart';
import '../../../core/utils/money.dart';
import '../../categories/data/category_repository.dart';
import '../bloc/tranasaction_bloc.dart';
import '../bloc/tranasaction_event.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, required this.monthId});
  final String monthId;

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

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final catRepo = context.read<CategoryRepository>();
      categories = await catRepo.getCategories();

      // default selection
      selectedCategory = categories.isNotEmpty ? categories.first : null;

      // try restore last used
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

      setState(() => loading = false);
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString();
      });
    }
  }

  Future<void> _reloadSubcategories() async {
    if (selectedCategory == null) return;
    setState(() => loading = true);
    try {
      final catRepo = context.read<CategoryRepository>();
      subcategories = await catRepo.getSubcategories(selectedCategory!.id);
      if (subcategories.isNotEmpty) {
        // keep selection if still exists
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

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    try {
      final amountMinor = rupeesToMinor(amountCtrl.text);
      final nowMillis = DateTime.now().millisecondsSinceEpoch;

      if (isExpense) {
        if (selectedCategory == null) {
          _toast('Select a category');
          return;
        }
        if (selectedSubcategory == null) {
          _toast('Select a subcategory');
          return;
        }

        context.read<TransactionBloc>().add(
          AddExpenseRequested(
            monthId: widget.monthId,
            amountMinor: amountMinor,
            dateMillis: nowMillis,
            subcategoryId: selectedSubcategory!.id,
            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          ),
        );

        // remember last used
        await _lastStore.write(
          categoryId: selectedCategory!.id,
          subcategoryId: selectedSubcategory!.id,
        );
      } else {
        context.read<TransactionBloc>().add(
          AddIncomeRequested(
            monthId: widget.monthId,
            amountMinor: amountMinor,
            dateMillis: nowMillis,
            note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _toast('Invalid input: $e');
    }
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

    return Scaffold(
      appBar: AppBar(title: const Text('Add Transaction')),
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
              onSelectionChanged: (s) => setState(() => isExpense = s.first),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (PKR)'),
            ),
            const SizedBox(height: 12),

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
                child: const Text('Save'),
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

  /// Return null; this is just a hook to add new items then keep sheet open
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
                        // Don’t close sheet; caller reloads list after returning
                        // If you want auto-refresh inside the sheet, you need to pass updated items.
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

