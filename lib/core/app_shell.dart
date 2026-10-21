import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';

import '../features/budget/presentation/bloc/budget_bloc.dart';
import '../features/budget/presentation/bloc/budget_event.dart';
import '../features/budget/presentation/budget_screen.dart';

import 'db/app_db.dart';
import '../features/reports/presentation/reportsbloc/reports_bloc.dart';
import '../features/reports/presentation/reportsbloc/reports_event.dart';
import '../features/reports/presentation/reports_screen.dart';

import '../features/transactions/bloc/tranasaction_bloc.dart';
import '../features/transactions/bloc/tranasaction_event.dart';
import '../features/transactions/presentation/transaction_list_screen.dart';

import 'state/month_cubit.dart'; // <-- create MonthCubit here

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  StreamSubscription<Object?>? _databaseUpdates;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    // Load initial month once
    final m = context.read<MonthCubit>().state;
    _reloadAll(m);
    _databaseUpdates = context.read<AppDatabase>().tableUpdates().listen((_) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(milliseconds: 20), () {
        if (mounted) _reloadAll(context.read<MonthCubit>().state);
      });
    });
  }

  void _reloadAll(String monthId) {
    context.read<DashboardBloc>().add(LoadDashboard(monthId));
    context.read<TransactionBloc>().add(LoadMonthTransactions(monthId));
    context.read<BudgetBloc>().add(LoadBudgetMonth(monthId));
    context.read<ReportsBloc>().add(LoadReports(monthId: monthId, force: true));
  }

  void _onTap(int i) {
    setState(() => index = i);

    final m = context.read<MonthCubit>().state;

    // refresh on tab switch using CURRENT selected month
    if (i == 0) context.read<DashboardBloc>().add(LoadDashboard(m));
    if (i == 1) context.read<TransactionBloc>().add(LoadMonthTransactions(m));
    if (i == 2) context.read<BudgetBloc>().add(LoadBudgetMonth(m));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _databaseUpdates?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DashboardScreen(),
      const TransactionsListScreen(),
      const BudgetScreen(),
      const ReportsScreen(),
    ];

    return BlocListener<MonthCubit, String>(
      listener: (context, newMonthId) {
        _reloadAll(newMonthId);
      },
      child: Scaffold(
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _onTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              label: 'Budget',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}
