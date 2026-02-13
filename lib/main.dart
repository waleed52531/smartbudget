import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/app_shell.dart';
import 'core/db/app_db.dart';
import 'core/state/month_cubit.dart';
import 'core/utils/month_id.dart';

import 'features/backup/data/backup_repository.dart';
import 'features/backup/presentaion/bloc/backup_bloc.dart';

import 'features/budget/data/budget_repository.dart';
import 'features/budget/presentation/bloc/budget_bloc.dart';

import 'features/categories/data/category_repository.dart';

import 'features/dashboard/data/dashboard_repository.dart';
import 'features/dashboard/presentation/bloc/dashboard_bloc.dart';

import 'features/recurring/data/recurring_repository.dart';
import 'features/recurring/presentation/bloc/recurring_bloc.dart';

import 'features/reports/data/export_repository.dart';
import 'features/reports/data/reports_repository.dart';
import 'features/reports/presentation/bloc/export_bloc.dart';
import 'features/reports/presentation/reportsbloc/reports_bloc.dart';

import 'features/transactions/data/transaction_repository.dart';
import 'features/transactions/bloc/tranasaction_bloc.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase();
  await db.seedDefaultsIfEmpty();

  runApp(MonthlyBudgetApp(db: db));
}

class MonthlyBudgetApp extends StatelessWidget {
  const MonthlyBudgetApp({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // ✅ This is what enables: context.read<AppDatabase>()
        RepositoryProvider<AppDatabase>.value(value: db),

        RepositoryProvider<CategoryRepository>(
          create: (_) => CategoryRepository(db),
        ),
        RepositoryProvider<TransactionRepository>(
          create: (_) => TransactionRepository(db),
        ),
        RepositoryProvider<BudgetRepository>(
          create: (_) => BudgetRepository(db),
        ),
        RepositoryProvider<DashboardRepository>(
          create: (_) => DashboardRepository(db),
        ),
        RepositoryProvider<ExportRepository>(
          create: (_) => ExportRepository(db),
        ),
        RepositoryProvider<ReportsRepository>(
          create: (_) => ReportsRepository(db),
        ),
        RepositoryProvider<RecurringRepository>(
          create: (_) => RecurringRepository(db),
        ),
        RepositoryProvider<BackupRepository>(
          create: (_) => BackupRepository(db),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          // ✅ Month cubit should exist globally
          BlocProvider<MonthCubit>(
            create: (_) => MonthCubit(currentMonthId()),
          ),

          BlocProvider<TransactionBloc>(
            create: (ctx) => TransactionBloc(ctx.read<TransactionRepository>()),
          ),

          BlocProvider<BudgetBloc>(
            create: (ctx) => BudgetBloc(
              budgetRepo: ctx.read<BudgetRepository>(),
              categoryRepo: ctx.read<CategoryRepository>(),
            ),
          ),

          BlocProvider<DashboardBloc>(
            create: (ctx) => DashboardBloc(ctx.read<DashboardRepository>()),
          ),

          BlocProvider<ExportBloc>(
            create: (ctx) => ExportBloc(repo: ctx.read<ExportRepository>()),
          ),

          BlocProvider<RecurringBloc>(
            create: (ctx) => RecurringBloc(repo: ctx.read<RecurringRepository>()),
          ),

          BlocProvider<BackupBloc>(
            create: (ctx) => BackupBloc(repo: ctx.read<BackupRepository>()),
          ),

          BlocProvider<ReportsBloc>(
            create: (ctx) => ReportsBloc(
              reportsRepo: ctx.read<ReportsRepository>(),
              budgetRepo: ctx.read<BudgetRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true),
          home: const AppShell(),
        ),
      ),
    );
  }
}
