import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/dashboard/presentation/bloc/dashboard_bloc.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';

import '../features/budget/presentation/bloc/budget_bloc.dart';
import '../features/budget/presentation/bloc/budget_event.dart';
import '../features/budget/presentation/budget_screen.dart';

import '../features/recurring/presentation/bloc/recurring_bloc.dart';
import '../features/recurring/presentation/bloc/recurring_event.dart';
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

  @override
  void initState() {
    super.initState();

    // Load initial month once
    final m = context.read<MonthCubit>().state;
    _reloadAll(m);
  }

  void _reloadAll(String monthId) {
    context.read<DashboardBloc>().add(LoadDashboard(monthId));
    context.read<TransactionBloc>().add(LoadMonthTransactions(monthId));
    context.read<BudgetBloc>().add(LoadBudgetMonth(monthId));
    // Reports uses FutureBuilder, so no bloc needed here unless you later add one
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
  Widget build(BuildContext context) {
    final pages = [
      const DashboardScreen(),
      const TransactionsListScreen(),
      const BudgetScreen(),
      const ReportsScreen(),
    ];

    return BlocListener<MonthCubit, String>(
      listener: (context, newMonthId) {
        context.read<DashboardBloc>().add(LoadDashboard(newMonthId));
        context.read<TransactionBloc>().add(LoadMonthTransactions(newMonthId));
        context.read<BudgetBloc>().add(LoadBudgetMonth(newMonthId));

        // ✅ auto-apply recurring on month change
        context.read<RecurringBloc>().add(ApplyRecurringToMonthRequested(newMonthId));
      },
      child: Scaffold(
        body: pages[index],
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _onTap,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Transactions'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Budget'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Reports'),
          ],
        ),
      ),
    );
  }
}
