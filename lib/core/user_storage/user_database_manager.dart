import 'dart:async';
import '../db/app_db.dart';
import 'encrypted_database_factory.dart';
import 'storage_access.dart';

/// Serializes database generations. Invalidates SQL immediately on auth changes;
/// waits for pending callbacks/rollback/close before opening another user's file.
class UserDatabaseManager implements StorageLifecycle {
  UserDatabaseManager({required this.authority, required this.factory}) {
    _subscription = authority.storageChanges.listen((_) => _changed());
    _changed();
  }
  final StorageAuthority authority;
  final EncryptedDatabaseFactory factory;
  late final StreamSubscription<void> _subscription;
  Future<void> _pending = Future<void>.value();
  OpenUserDatabase? _opened;
  StorageGrant? _grant;
  int _generation = 0;
  bool _disposed = false, _closeFailed = false;
  StorageFailureKind? _failure;
  StorageFailureKind? get failure => _failure;
  bool get isOpen =>
      _opened != null &&
      _grant == authority.storageGrant &&
      (_grant?.valid ?? false);

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _check(StorageGrant grant, int generation) {
    if (_disposed ||
        generation != _generation ||
        !identical(grant, authority.storageGrant)) {
      throw const StorageFailure(StorageFailureKind.locked);
    }
    grant.check();
  }

  void _changed() {
    final next = authority.storageGrant;
    if (identical(next, _grant) && next != null && next.valid) return;
    final generation = ++_generation;
    // Invalidation happens before any asynchronous await or queued callback.
    _grant = null;
    unawaited(
      _serial(() async {
        await _closeCurrent();
        _failure = null;
        if (_disposed ||
            _closeFailed ||
            next == null ||
            generation != _generation) {
          return;
        }
        try {
          _check(next, generation);
          await authority.verifyStorage(next);
          _check(next, generation);
          final candidate = await factory.open(
            next,
            () => _check(next, generation),
          );
          try {
            _check(next, generation);
          } catch (_) {
            await candidate.close();
            rethrow;
          }
          _opened = candidate;
          _grant = next;
        } catch (error) {
          if (generation == _generation) {
            _failure = error is StorageFailure
                ? error.kind
                : StorageFailureKind.locked;
          }
        }
      }).catchError((Object _, StackTrace _) {
        _closeFailed = true;
        _failure = StorageFailureKind.damaged;
      }),
    );
  }

  /// A callback is scoped to the current verified grant. It cannot select a UID.
  /// All its writes commit together, or roll back if the grant changes mid-flight.
  /// Give this capability, rather than the manager, to session-scoped services.
  /// Keeping a scope across await/account switching can never redirect it to B.
  UserDatabaseScope get scope =>
      UserDatabaseScope._(this, authority.storageGrant, _generation);

  Future<T> _run<T>(
    StorageGrant? grant,
    int generation,
    Future<T> Function(AppDatabase database) action,
  ) {
    return _serial(() async {
      if (grant == null) throw const StorageFailure(StorageFailureKind.locked);
      _check(grant, generation);
      if (_opened == null || !identical(_grant, grant)) {
        throw StorageFailure(_failure ?? StorageFailureKind.locked);
      }
      try {
        await authority.verifyStorage(grant);
        _check(grant, generation);
        return await _opened!.database.transaction(() async {
          _check(grant, generation);
          final result = await action(_opened!.database);
          _check(grant, generation);
          await authority.verifyStorage(grant);
          _check(grant, generation);
          return result;
        });
      } on StorageFailure {
        rethrow;
      } catch (_) {
        throw const StorageFailure(StorageFailureKind.damaged);
      }
    });
  }

  Future<void> get settled => _pending;

  /// Stops normal access and closes SQLite before session-bound file maintenance.
  /// A concurrent logout/account switch invalidates the operation immediately.
  Future<T> maintenance<T>(
    Future<T> Function(StorageGrant grant, void Function() check) action,
  ) {
    final grant = authority.storageGrant;
    final generation = ++_generation;
    _grant = null;
    return _serial(() async {
      await _closeCurrent();
      try {
        if (grant == null) {
          throw const StorageFailure(StorageFailureKind.locked);
        }
        _check(grant, generation);
        await authority.verifyStorage(grant);
        _check(grant, generation);
        final result = await action(grant, () => _check(grant, generation));
        _check(grant, generation);
        await authority.verifyStorage(grant);
        _check(grant, generation);
        return result;
      } finally {
        if (!_disposed && generation == _generation) _changed();
      }
    });
  }

  Future<void> _closeCurrent() async {
    final previous = _opened;
    _opened = null;
    _grant = null;
    if (previous != null) {
      try {
        await previous.close();
      } catch (_) {
        _closeFailed = true;
        throw const StorageFailure(StorageFailureKind.damaged);
      }
    }
  }

  @override
  Future<void> lock() {
    ++_generation;
    _grant = null;
    return _serial(_closeCurrent);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    ++_generation;
    _grant = null;
    await _subscription.cancel();
    await _serial(_closeCurrent);
  }
}

class UserDatabaseScope {
  UserDatabaseScope._(this._manager, this._grant, this._generation);
  final UserDatabaseManager _manager;
  final StorageGrant? _grant;
  final int _generation;
  Future<T> run<T>(Future<T> Function(AppDatabase database) action) =>
      _manager._run(_grant, _generation, action);
}
