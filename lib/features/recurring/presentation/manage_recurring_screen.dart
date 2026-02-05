import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/money.dart';
import '../data/recurring_repository.dart';
import 'bloc/recurring_bloc.dart';
import 'bloc/recurring_event.dart';
import 'bloc/recurring_state.dart';

class ManageRecurringScreen extends StatefulWidget {
  const ManageRecurringScreen({super.key, required this.monthId});
  final String monthId;

  @override
  State<ManageRecurringScreen> createState() => _ManageRecurringScreenState();
}

class _ManageRecurringScreenState extends State<ManageRecurringScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RecurringBloc>().add(const LoadRecurringTemplates());
  }

  Future<void> _openEditor({String? id, String? title, int? amountMinor, String? type, int? day, bool? active}) async {
    final titleCtrl = TextEditingController(text: title ?? '');
    final amountCtrl = TextEditingController(text: amountMinor == null ? '' : minorToRupees(amountMinor));
    String t = type ?? 'expense';
    int d = day ?? 1;
    bool isActive = active ?? true;

    final res = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(id == null ? 'Add Recurring' : 'Edit Recurring'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title (e.g. Rent)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (PKR)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: t,
                items: const [
                  DropdownMenuItem(value: 'expense', child: Text('Expense')),
                  DropdownMenuItem(value: 'income', child: Text('Income')),
                ],
                onChanged: (v) => setLocal(() => t = v ?? 'expense'),
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                value: d,
                items: List.generate(31, (i) => i + 1)
                    .map((x) => DropdownMenuItem(value: x, child: Text('Day $x')))
                    .toList(),
                onChanged: (v) => setLocal(() => d = v ?? 1),
                decoration: const InputDecoration(labelText: 'Day of month'),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: isActive,
                onChanged: (v) => setLocal(() => isActive = v),
                title: const Text('Active'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (res != true) return;

    final parsedAmount = rupeesToMinor(amountCtrl.text);
    context.read<RecurringBloc>().add(
      SaveRecurringTemplateRequested(
        id: id,
        title: titleCtrl.text.trim(),
        amountMinor: parsedAmount,
        type: t,
        dayOfMonth: d,
        nodeId: null,
        note: null,
        isActive: isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Templates'),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_outlined),
            onPressed: () {
              context.read<RecurringBloc>().add(ApplyRecurringToMonthRequested(widget.monthId));
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: BlocListener<RecurringBloc, RecurringState>(
        listener: (context, s) {
          if (s.toast == null) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.toast!)));
          context.read<RecurringBloc>().add(const ClearRecurringToast());
        },
        child: BlocBuilder<RecurringBloc, RecurringState>(
          builder: (context, s) {
            if (s.status == RecurringStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.status == RecurringStatus.failure) {
              return Center(child: Text('Error: ${s.error}'));
            }
            if (s.items.isEmpty) {
              return const Center(child: Text('No recurring templates yet.'));
            }

            return ListView.separated(
              itemCount: s.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = s.items[i];
                return ListTile(
                  title: Text(r.title),
                  subtitle: Text(
                    '${r.type.toUpperCase()}  •  Day ${r.dayOfMonth}  •  ${minorToRupees(r.amountMinor)}',
                  ),
                  leading: Switch(
                    value: r.isActive,
                    onChanged: (v) => context.read<RecurringBloc>().add(ToggleRecurringActiveRequested(r.id, v)),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => context.read<RecurringBloc>().add(DeleteRecurringTemplateRequested(r.id)),
                  ),
                  onTap: () => _openEditor(
                    id: r.id,
                    title: r.title,
                    amountMinor: r.amountMinor,
                    type: r.type,
                    day: r.dayOfMonth,
                    active: r.isActive,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
