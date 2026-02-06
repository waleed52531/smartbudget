import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smartbudget/features/budget/presentation/budget_screen.dart';

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
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/recurring/data/recurring_repository.dart';
import 'features/recurring/presentation/bloc/recurring_bloc.dart';
import 'features/reports/data/export_repository.dart';
import 'features/reports/data/reports_repository.dart';
import 'features/reports/presentation/bloc/export_bloc.dart';
import 'features/reports/presentation/reportsbloc/reports_bloc.dart';
import 'features/transactions/bloc/tranasaction_bloc.dart';
import 'features/transactions/data/transaction_repository.dart';
import 'features/transactions/presentation/transaction_list_screen.dart';

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
        RepositoryProvider.value(value: db),
        RepositoryProvider(create: (_) => CategoryRepository(db)),
        RepositoryProvider(create: (_) => TransactionRepository(db)),
        RepositoryProvider(create: (_) => BudgetRepository(db)),
        RepositoryProvider(create: (_) => DashboardRepository(db)),
        RepositoryProvider(create: (_) => ExportRepository(db)),
        RepositoryProvider(create: (_) => ReportsRepository(db)),
        RepositoryProvider(create: (_) => RecurringRepository(db)),
        RepositoryProvider(create: (_) => BackupRepository(db)),


      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (ctx) => TransactionBloc(ctx.read<TransactionRepository>())),
          BlocProvider(
            create: (ctx) => BudgetBloc(
              budgetRepo: ctx.read<BudgetRepository>(),
              categoryRepo: ctx.read<CategoryRepository>(),
            ),
          ),
          BlocProvider(create: (ctx) => DashboardBloc(ctx.read<DashboardRepository>())),
          BlocProvider(create: (ctx) => ExportBloc(repo: ctx.read<ExportRepository>())),
          BlocProvider(create: (_) => MonthCubit(currentMonthId())),
          BlocProvider(create: (ctx) => RecurringBloc(repo: ctx.read<RecurringRepository>())),
          BlocProvider(create: (ctx) => BackupBloc(repo: ctx.read<BackupRepository>())),
          BlocProvider(create: (ctx) => ReportsBloc(reportsRepo: ctx.read<ReportsRepository>(), budgetRepo: ctx.read<BudgetRepository>(),),),

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
