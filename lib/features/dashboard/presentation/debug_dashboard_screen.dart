import 'package:flutter/material.dart';
import '../../../core/db/app_db.dart';
import '../../../core/utils/month_id.dart';

class DebugDashboardScreen extends StatefulWidget {
  const DebugDashboardScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<DebugDashboardScreen> createState() => _DebugDashboardScreenState();
}

class _DebugDashboardScreenState extends State<DebugDashboardScreen> {
  late String monthId;

  @override
  void initState() {
    super.initState();
    monthId = currentMonthId();
    widget.db.ensureBudgetMonthExists(monthId);
  }

  Future<void> _addTestExpense() async {
    try {
      await widget.db.insertExpense(
        amountMinor: 50000,
        dateMillis: DateTime.now().millisecondsSinceEpoch,
        subcategoryId: 'sub_groceries_milk', // test another category
        note: 'Test expense',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense inserted')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insert failed: $e')),
      );
    }
  }

  Future<void> _addTestIncome() async {
    try {
      await widget.db.insertIncome(
        amountMinor: 200000,
        dateMillis: DateTime.now().millisecondsSinceEpoch,
        note: 'Test income',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Income inserted')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Insert failed: $e')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard Debug ($monthId)')),
      body: FutureBuilder(
        future: Future.wait([
          widget.db.getMonthTotals(monthId),
          widget.db.getCategoryCardsOptionA(monthId),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final totals = snapshot.data![0] as dynamic;
          final cards = snapshot.data![1] as dynamic;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Spent: ${totals.totalSpent}'),
                Text('Total Income: ${totals.totalIncome}'),
                const SizedBox(height: 16),
                const Text('Category Cards (Option A):', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (_, i) {
                      final c = cards[i];
                      return ListTile(
                        title: Text(c.categoryName),
                        subtitle: Text('Spent: ${c.spent} | Limit: ${c.budgetLimit ?? '-'} | Remaining: ${c.remaining ?? '-'}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'income',
            onPressed: _addTestIncome,
            label: const Text('Add Income'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'expense',
            onPressed: _addTestExpense,
            label: const Text('Add Expense'),
          ),
        ],
      ),
    );
  }
}
