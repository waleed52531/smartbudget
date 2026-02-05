import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/db/app_db.dart';
import '../../../core/utils/money.dart';

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
    final db = (context.findAncestorWidgetOfExactType<MaterialApp>() == null)
        ? null
        : null; // ignore; we’ll use RepositoryProvider in main.dart below

    return Scaffold(
      appBar: AppBar(title: Text(categoryName)),
      body: _BreakdownBody(monthId: monthId, categoryId: categoryId),
    );
  }
}

class _BreakdownBody extends StatelessWidget {
  const _BreakdownBody({required this.monthId, required this.categoryId});
  final String monthId;
  final String categoryId;

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

        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final r = rows[i];
            return ListTile(
              title: Text(r.subcategoryName),
              trailing: Text(minorToRupees(r.spent)),
            );
          },
        );
      },
    );
  }
}
