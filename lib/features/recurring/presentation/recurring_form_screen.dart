import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/db/app_db.dart';
import '../../../core/utils/money.dart';
import '../../categories/data/category_repository.dart';
import '../presentation/bloc/recurring_bloc.dart';
import '../presentation/bloc/recurring_event.dart';

class RecurringFormScreen extends StatefulWidget {
  const RecurringFormScreen({super.key, this.existing});
  final RecurringTemplate? existing;

  @override
  State<RecurringFormScreen> createState() => _RecurringFormScreenState();
}

class _RecurringFormScreenState extends State<RecurringFormScreen> {
  final titleCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();

  bool isExpense = true;
  bool isActive = true;
  int dayOfMonth = 1;

  List<CategoryNode> categories = [];
  List<CategoryNode> subcategories = [];
  CategoryNode? selectedCategory;
  CategoryNode? selectedSubcategory;

  bool loading = true;
  String? error;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();

    if (isEdit) {
      final t = widget.existing!;
      titleCtrl.text = t.title;
      amountCtrl.text = minorToRupees(t.amountMinor);
      noteCtrl.text = t.note ?? '';
      isExpense = t.type == 'expense';
      isActive = t.isActive;
      dayOfMonth = t.dayOfMonth;
    }

    _loadCats();
  }

  Future<void> _loadCats() async {
    try {
      final repo = context.read<CategoryRepository>();
      categories = await repo.getCategories();
      selectedCategory = categories.isNotEmpty ? categories.first : null;

      if (isEdit && isExpense && widget.existing!.subcategoryId != null) {
        final subId = widget.existing!.subcategoryId!;
        for (final c in categories) {
          final subs = await repo.getSubcategories(c.id);
          final match = subs.where((x) => x.id == subId).toList();
          if (match.isNotEmpty) {
            selectedCategory = c;
            subcategories = subs;
            selectedSubcategory = match.first;
            break;
          }
        }
      }

      if (subcategories.isEmpty && selectedCategory != null) {
        subcategories = await repo.getSubcategories(selectedCategory!.id);
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

  Future<void> _reloadSubs() async {
    if (selectedCategory == null) return;
    setState(() => loading = true);
    try {
      final repo = context.read<CategoryRepository>();
      subcategories = await repo.getSubcategories(selectedCategory!.id);
      selectedSubcategory = subcategories.isNotEmpty ? subcategories.first : null;
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

  Future<void> _pickCategory() async {
    final picked = await showModalBottomSheet<CategoryNode>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SearchPickerBottomSheet<CategoryNode>(
        title: 'Select Category',
        items: categories,
        itemLabel: (c) => c.name,
        onAddRequested: () async {
          final name = await _nameDialog('Add Subcategory');
          if (name == null) return null;

          await context.read<CategoryRepository>().addSubcategory(
            categoryId: selectedCategory!.id,
            name: name,
          );

          await _reloadSubs();
          if (subcategories.isNotEmpty) {
            setState(() => selectedSubcategory = subcategories.last);
          }

          // ✅ close picker so user sees update (otherwise sheet list stays stale)
          if (context.mounted) Navigator.pop(context);
          return null;
        },

      ),
    );

    if (picked == null) return;
    setState(() {
      selectedCategory = picked;
      selectedSubcategory = null;
    });
    await _reloadSubs();
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
          await context.read<CategoryRepository>().addSubcategory(
            categoryId: selectedCategory!.id,
            name: name,
          );
          await _reloadSubs();
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
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<void> _save() async {
    try {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) {
        _toast('Title required');
        return;
      }

      final amountMinor = rupeesToMinor(amountCtrl.text);

      if (dayOfMonth < 1 || dayOfMonth > 31) {
        _toast('Day of month must be 1..31');
        return;
      }

      if (isExpense && selectedSubcategory == null) {
        _toast('Expense recurring needs a subcategory');
        return;
      }

      context.read<RecurringBloc>().add(
        SaveRecurringTemplateRequested(
          id: widget.existing?.id,
          title: title,
          amountMinor: amountMinor,
          type: isExpense ? 'expense' : 'income',
          dayOfMonth: dayOfMonth,
          subcategoryId: isExpense ? selectedSubcategory!.id : null,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
          isActive: isActive,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _toast('Invalid input: $e');
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(body: Center(child: Text('Error: $error')));

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Recurring' : 'Add Recurring')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (PKR)'),
            ),
            const SizedBox(height: 12),

            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Expense')),
                ButtonSegment(value: false, label: Text('Income')),
              ],
              selected: {isExpense},
              onSelectionChanged: isEdit
                  ? null
                  : (s) async {
                final next = s.first;
                if (next == isExpense) return;

                setState(() {
                  isExpense = next;
                  // ✅ If switching to income, clear selection (optional but clean)
                  if (!isExpense) {
                    selectedSubcategory = null;
                  }
                });

                // ✅ If switching to expense and you have categories, ensure subs are loaded
                if (isExpense && selectedCategory != null) {
                  await _reloadSubs();
                }
              },

            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Text('Day of month:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: dayOfMonth.toDouble(),
                    min: 1,
                    max: 31,
                    divisions: 30,
                    label: '$dayOfMonth',
                    onChanged: (v) => setState(() => dayOfMonth = v.round()),
                  ),
                ),
                SizedBox(width: 44, child: Text('$dayOfMonth')),
              ],
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: isActive,
              onChanged: (v) => setState(() => isActive = v),
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

            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),

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
                      onPressed: () async => await widget.onAddRequested(),
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
