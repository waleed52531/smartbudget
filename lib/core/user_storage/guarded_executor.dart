import 'package:drift/drift.dart';

/// Sticky interception also guards retained database references and transaction
/// commits. Rollback and close deliberately remain available after authorization.
class GuardedExecutor extends QueryInterceptor {
  GuardedExecutor(this.check);
  final void Function() check;
  @override
  Future<bool> ensureOpen(QueryExecutor executor, QueryExecutorUser user) {
    check();
    return executor.ensureOpen(user);
  }

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    check();
    return parent.beginTransaction();
  }

  @override
  QueryExecutor beginExclusive(QueryExecutor parent) {
    check();
    return parent.beginExclusive();
  }

  @override
  Future<void> commitTransaction(TransactionExecutor inner) {
    check();
    return inner.send();
  }

  @override
  Future<void> runBatched(
    QueryExecutor executor,
    BatchedStatements statements,
  ) {
    check();
    return executor.runBatched(statements);
  }

  @override
  Future<void> runCustom(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    check();
    return executor.runCustom(statement, args);
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    check();
    return executor.runInsert(statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    check();
    return executor.runDelete(statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    check();
    return executor.runUpdate(statement, args);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    check();
    return executor.runSelect(statement, args);
  }
}
