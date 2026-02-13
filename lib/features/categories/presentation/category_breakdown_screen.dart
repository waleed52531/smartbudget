import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/db/app_db.dart';
import '../../../core/state/month_cubit.dart';
import '../../../core/utils/money.dart';
import '../../transactions/bloc/tranasaction_bloc.dart';
import '../../transactions/bloc/tranasaction_event.dart';
import '../../transactions/bloc/tx_filters.dart';
import '../../transactions/presentation/transaction_list_screen.dart';

class CategoryBreakdownScreen extends StatelessWidget {
  const CategoryBreakdownScreen({
    super.key,
    required this.monthId,
    required this.categoryId,
    required this.categoryName,
  });

  final String monthId;
  final String categoryId;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: _BreakdownBody(
        monthId: monthId,
        categoryId: categoryId,
        categoryName: categoryName,
      ),
    );
  }
}

class _BreakdownBody extends StatelessWidget {
  const _BreakdownBody({
    required this.monthId,
    required this.categoryId,
    required this.categoryName,
  });

  final String monthId;
  final String categoryId;
  final String categoryName;

  Future<void> _openTx(
      BuildContext context, {
        required TxFilters filters,
      }) async {
    // ✅ enforce month
    final current = context.read<MonthCubit>().state;
    if (current != monthId) {
      context.read<MonthCubit>().setFromDate(MonthCubit.toDate(monthId));
    }

    context.read<TransactionBloc>().add(
      ApplyTxFiltersRequested(monthId: monthId, filters: filters),
    );
    context.read<TransactionBloc>().add(LoadMonthTransactions(monthId));

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionsListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = RepositoryProvider.of<AppDatabase>(context);

    return FutureBuilder(
      future: db.getSubcategoryBreakdown(monthId, categoryId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return const Center(child: Text('No data'));

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: ListTile(
                title: const Text('View all transactions in this category'),
                subtitle: Text(categoryName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final subIds = await db.getSubcategoryIdsByCategory(categoryId);
                  if (!context.mounted) return;

                  await _openTx(
                    context,
                    filters: TxFilters(
                      type: TxTypeFilter.expense,
                      categoryId: categoryId,
                      categorySubcategoryIds: subIds,
                      sort: TxSort.newest,
                      search: '',
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            const Text('Subcategories', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...rows.map((r) {
              return Card(
                child: ListTile(
                  title: Text(r.subcategoryName),
                  trailing: Text(minorToRupees(r.spent)),
                  onTap: () => _openTx(
                    context,
                    filters: TxFilters(
                      type: TxTypeFilter.expense,
                      subcategoryId: r.subcategoryId,
                      sort: TxSort.newest,
                      search: '',
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
