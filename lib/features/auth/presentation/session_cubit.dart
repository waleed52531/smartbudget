import 'dart:async';
import 'dart:math';
import '../../../core/user_storage/storage_access.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/session_vault.dart';
import '../domain/lease_verifier.dart';
import '../domain/session_contracts.dart';

enum SessionStatus { restoring, signedOut, authorizing, authorized, locked }

class SessionState {
  const SessionState(
    this.status, {
    this.identity,
    this.message,
    this.busy = false,
    this.offline = false,
    this.expiresAt,
  });
  final SessionStatus status;
  final AuthIdentity? identity;
  final String? message;
  final bool busy;
  final bool offline;
  final int? expiresAt;
}

class SessionCubit extends Cubit<SessionState> implements StorageAuthority {
  SessionCubit({
    required this.auth,
    required this.authorization,
    required this.vault,
    required this.clock,
    required this.verifier,
    StorageLifecycle Function(StorageAuthority authority)? storageFactory,
  }) : super(const SessionState(SessionStatus.restoring)) {
    _storage = storageFactory?.call(this);
    _subscription = auth.changes.listen(
      (user) => unawaited(_identityChanged(user)),
      onError: (Object _, StackTrace _) {
        _requireOnline = true;
        _lock('Authentication could not be restored. Sign out and try again.');
      },
    );
  }
  final AuthGateway auth;
  final AuthorizationGateway authorization;
  final SessionVault vault;
  final SessionClock clock;
  final LeaseVerifier verifier;
  StorageLifecycle? _storage;
  bool _closingSession = false;
  Future<void>? _closingFuture;
  StorageGrant? _activeStorage;
  CachedAuthorization? _storageCached;
  int? _storageRevision;
  final _storageEvents = StreamController<void>.broadcast(sync: true);
  @override
  Stream<void> get storageChanges => _storageEvents.stream;
  @override
  StorageGrant? get storageGrant =>
      _activeStorage?.valid == true ? _activeStorage : null;

  void _invalidateStorage() {
    _activeStorage = null;
    _storageCached = null;
    _storageRevision = null;
    _storageEvents.add(null);
  }

  @override
  void emit(SessionState state) {
    if (_closingSession) return;
    if (state.status != SessionStatus.authorized) _invalidateStorage();
    super.emit(state);
  }

  @override
  Future<void> verifyStorage(StorageGrant grant) async {
    try {
      grant.check();
      if (!identical(grant, storageGrant)) {
        throw const StorageFailure(StorageFailureKind.locked);
      }
      final cached = _storageCached;
      if (cached == null) throw const StorageFailure(StorageFailureKind.locked);
      final installation = await vault.installation();
      final now = cached.timeAt(await clock.snapshot());
      await verifier.verify(
        cached.bundle,
        uid: grant.uid,
        installationId: installation,
        nowSeconds: now ~/ 1000,
      );
      grant.check();
      if (!identical(grant, storageGrant)) {
        throw const StorageFailure(StorageFailureKind.locked);
      }
    } catch (_) {
      if (identical(_activeStorage, grant) && !isClosed) {
        _requireOnline = true;
        _lock('Authorization could not be verified. Connect to verify access.');
      }
      throw const StorageFailure(StorageFailureKind.locked);
    }
  }

  late final StreamSubscription<AuthIdentity?> _subscription;
  Timer? _expiryTimer, _clockTimer;
  int _revision = 0;
  bool _background = false,
      _observed = false,
      _requireOnline = false,
      _signingOut = false,
      _loginPending = false,
      _cancelLogin = false;
  String? _seenUid, _logoutPendingUid;

  bool _current(int revision, String uid) =>
      !isClosed &&
      !_closingSession &&
      !_background &&
      !_signingOut &&
      revision == _revision &&
      auth.current?.uid == uid;
  void _cancelTimers() {
    _expiryTimer?.cancel();
    _clockTimer?.cancel();
  }

  void _lock(String message) {
    if (isClosed || _closingSession) return;
    _revision++;
    _cancelTimers();
    emit(
      SessionState(
        SessionStatus.locked,
        identity: auth.current,
        message: message,
      ),
    );
  }

  Future<void> _identityChanged(AuthIdentity? user) async {
    if (_closingSession) return;
    if (!isClosed &&
        !_signingOut &&
        user != null &&
        _loginPending &&
        _cancelLogin) {
      await signOut();
      return;
    }
    if (isClosed || _signingOut || (_observed && _seenUid == user?.uid)) return;
    final previousUid = _seenUid;
    _observed = true;
    _seenUid = user?.uid;
    final revision = ++_revision;
    _cancelTimers();
    emit(SessionState(SessionStatus.authorizing, identity: user));
    if (user == null) {
      try {
        if (previousUid != null) await vault.invalidate(previousUid);
        if (!isClosed && revision == _revision) {
          emit(SessionState(SessionStatus.signedOut, busy: _loginPending));
        }
      } catch (_) {
        _lock('Protected session storage is unavailable. Retry sign-out.');
      }
    } else if (!_background) {
      await _authorize(user, revision, onlineOnly: _requireOnline);
    }
  }

  Future<void> signIn(String email, String password) async {
    if (_closingSession ||
        state.status != SessionStatus.signedOut ||
        state.busy ||
        _loginPending) {
      return;
    }
    _loginPending = true;
    _cancelLogin = false;
    final revision = ++_revision;
    _requireOnline = true;
    emit(const SessionState(SessionStatus.signedOut, busy: true));
    try {
      await vault.lock();
      if (isClosed || revision != _revision) return;
      await auth.signIn(email.trim(), password);
      if (_cancelLogin) {
        await signOut();
        return;
      }
      // Some adapters deliver the stream event after the sign-in Future.
      await _identityChanged(auth.current);
    } catch (error) {
      if (isClosed || auth.current != null || revision != _revision) return;
      emit(
        SessionState(
          SessionStatus.signedOut,
          message:
              error is SessionFailure &&
                  error.kind == SessionFailureKind.storage
              ? 'Protected session storage is unavailable.'
              : 'Sign in failed. Check your connection, email and password.',
        ),
      );
    } finally {
      _loginPending = false;
      if (!isClosed &&
          !_signingOut &&
          auth.current == null &&
          state.status == SessionStatus.signedOut) {
        emit(SessionState(SessionStatus.signedOut, message: state.message));
      }
    }
  }

  Future<void> resetPassword(String email) async {
    if (_closingSession ||
        state.status != SessionStatus.signedOut ||
        state.busy) {
      return;
    }
    final revision = ++_revision;
    emit(const SessionState(SessionStatus.signedOut, busy: true));
    try {
      await auth.resetPassword(email.trim());
      if (!isClosed && revision == _revision) {
        emit(
          const SessionState(
            SessionStatus.signedOut,
            message:
                'If this account is eligible, password reset instructions have been sent.',
          ),
        );
      }
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit(
          const SessionState(
            SessionStatus.signedOut,
            message:
                'Password reset could not be completed. Check your connection and try again.',
          ),
        );
      }
    }
  }

  Future<void> refresh() async {
    final user = auth.current;
    if (user == null ||
        _background ||
        _signingOut ||
        isClosed ||
        _closingSession) {
      return;
    }
    final revision = ++_revision;
    _cancelTimers();
    emit(SessionState(SessionStatus.authorizing, identity: user));
    await _authorize(user, revision, onlineOnly: _requireOnline);
  }

  Future<void> _authorize(
    AuthIdentity user,
    int revision, {
    required bool onlineOnly,
  }) async {
    try {
      final installation = await vault.installation();
      if (!_current(revision, user.uid)) return;
      try {
        final before = await clock.snapshot();
        final bundle = await authorization.authorize(user.uid, installation);
        if (!_current(revision, user.uid)) return;
        final after = await clock.snapshot();
        if (before.bootId != after.bootId ||
            after.elapsedMs < before.elapsedMs ||
            after.wallMs <
                before.wallMs + after.elapsedMs - before.elapsedMs - 2000) {
          throw const SessionFailure(SessionFailureKind.invalidLease);
        }
        final lease = await verifier.verify(
          bundle,
          uid: user.uid,
          installationId: installation,
          nowSeconds: after.wallMs ~/ 1000,
        );
        // Never underestimate time spent issuing/delivering this grant. This can
        // expire a lease slightly early; it cannot extend its signed lifetime.
        final trustedMs = max(
          after.wallMs,
          lease.issuedAt * 1000 + after.elapsedMs - before.elapsedMs,
        );
        final cached = CachedAuthorization(
          bundle: bundle,
          clock: after,
          trustedMs: trustedMs,
        );
        await verifier.verify(
          bundle,
          uid: user.uid,
          installationId: installation,
          nowSeconds: trustedMs ~/ 1000,
        );
        await vault.save(
          user.uid,
          cached,
          stillCurrent: () => _current(revision, user.uid),
        );
        if (_current(revision, user.uid)) {
          _requireOnline = false;
          await _authorized(user, lease, cached, revision, offline: false);
        }
      } on SessionFailure catch (error) {
        if (!_current(revision, user.uid)) return;
        if (!{
              SessionFailureKind.unavailable,
              SessionFailureKind.network,
            }.contains(error.kind) ||
            onlineOnly) {
          rethrow;
        }
        final cached = await vault.cached(user.uid);
        if (cached == null) {
          rethrow;
        }
        final now = await clock.snapshot();
        final trustedMs = cached.timeAt(now);
        final lease = await verifier.verify(
          cached.bundle,
          uid: user.uid,
          installationId: installation,
          nowSeconds: trustedMs ~/ 1000,
        );
        final updated = CachedAuthorization(
          bundle: cached.bundle,
          clock: now,
          trustedMs: trustedMs,
        );
        await vault.save(
          user.uid,
          updated,
          stillCurrent: () => _current(revision, user.uid),
        );
        if (_current(revision, user.uid)) {
          await _authorized(user, lease, updated, revision, offline: true);
        }
      }
    } catch (error) {
      if (!_current(revision, user.uid)) return;
      final failure = error is SessionFailure
          ? error.kind
          : SessionFailureKind.invalidLease;
      if (!{
        SessionFailureKind.unavailable,
        SessionFailureKind.network,
      }.contains(failure)) {
        _requireOnline = true;
        try {
          await vault.invalidate(user.uid);
        } catch (_) {
          if (_current(revision, user.uid)) {
            _lock('Protected session storage is unavailable. Retry sign-out.');
          }
          return;
        }
      }
      if (!_current(revision, user.uid)) return;
      final message = switch (failure) {
        SessionFailureKind.denied =>
          'This account is not authorized. Contact your beta administrator or use another account.',
        SessionFailureKind.invalidLease =>
          'Authorization could not be verified. Check device time and connect to verify access.',
        SessionFailureKind.storage =>
          'Protected session storage is unavailable. Retry sign-out.',
        SessionFailureKind.configuration =>
          'The authorization backend is not configured or its endpoint is unavailable. Contact your beta administrator.',
        SessionFailureKind.attestation =>
          'App verification could not complete. Check your connection. If this continues, contact your beta administrator to check App Check configuration.',
        SessionFailureKind.network =>
          'The authorization service could not be reached. Check your connection and retry. No valid offline authorization is available.',
        _ =>
          'The authorization service is unavailable. Try again later. No valid offline authorization is available.',
      };
      emit(
        SessionState(SessionStatus.locked, identity: user, message: message),
      );
    }
  }

  Future<void> _authorized(
    AuthIdentity user,
    VerifiedLease lease,
    CachedAuthorization cached,
    int revision, {
    required bool offline,
  }) async {
    // Verification and KeyStore writes can take time. Re-sample after persistence
    // so those delays can never extend authorization beyond the signed expiry.
    final trustedMs = cached.timeAt(await clock.snapshot());
    if (!_current(revision, user.uid)) return;
    if (trustedMs >= lease.expiresAt * 1000) {
      throw const SessionFailure(SessionFailureKind.invalidLease);
    }
    _cancelTimers();
    final changed =
        _activeStorage == null ||
        _storageRevision != revision ||
        _storageCached?.bundle.lease != cached.bundle.lease;
    if (changed) {
      _activeStorage = StorageGrant(
        projectId: verifier.projectId,
        uid: user.uid,
        expiresAtMs: lease.expiresAt * 1000,
        trustedMs: trustedMs,
        stillCurrent: () =>
            _current(revision, user.uid) &&
            state.status == SessionStatus.authorized,
      );
      _storageRevision = revision;
    }
    _storageCached = cached;
    emit(
      SessionState(
        SessionStatus.authorized,
        identity: user,
        offline: offline,
        expiresAt: lease.expiresAt,
      ),
    );
    if (changed) _storageEvents.add(null);
    final remaining = lease.expiresAt * 1000 - trustedMs;
    _expiryTimer = Timer(Duration(milliseconds: max(0, remaining)), () {
      if (_current(revision, user.uid)) {
        _lock('Authorization expired. Connect to verify access.');
      }
    });
    _clockTimer = Timer(
      const Duration(seconds: 30),
      () => unawaited(_checkLocal(user, revision, offline)),
    );
  }

  Future<void> _checkLocal(
    AuthIdentity user,
    int revision,
    bool offline,
  ) async {
    if (!_current(revision, user.uid) ||
        state.status != SessionStatus.authorized) {
      return;
    }
    try {
      final installation = await vault.installation();
      final cached = await vault.cached(user.uid);
      if (cached == null) {
        throw const SessionFailure(SessionFailureKind.invalidLease);
      }
      final now = await clock.snapshot();
      final trustedMs = cached.timeAt(now);
      final lease = await verifier.verify(
        cached.bundle,
        uid: user.uid,
        installationId: installation,
        nowSeconds: trustedMs ~/ 1000,
      );
      final updated = CachedAuthorization(
        bundle: cached.bundle,
        clock: now,
        trustedMs: trustedMs,
      );
      await vault.save(
        user.uid,
        updated,
        stillCurrent: () => _current(revision, user.uid),
      );
      if (_current(revision, user.uid)) {
        await _authorized(user, lease, updated, revision, offline: offline);
      }
    } catch (_) {
      if (_current(revision, user.uid)) {
        _requireOnline = true;
        try {
          await vault.invalidate(user.uid);
        } catch (_) {
          /* Remain locked. */
        }
        if (_current(revision, user.uid)) {
          _lock(
            'Authorization could not be verified. Connect to verify access.',
          );
        }
      }
    }
  }

  void background() {
    _background = true;
    if (auth.current != null) {
      _revision++;
      _cancelTimers();
      emit(SessionState(SessionStatus.authorizing, identity: auth.current));
    }
  }

  Future<void> resume() async {
    _background = false;
    await refresh();
  }

  Future<void> signOut() async {
    if (_signingOut || isClosed || _closingSession) return;
    _signingOut = true;
    if (_loginPending) _cancelLogin = true;
    _requireOnline = true;
    ++_revision;
    _cancelTimers();
    _logoutPendingUid ??= auth.current?.uid;
    emit(
      SessionState(
        SessionStatus.locked,
        identity: auth.current,
        busy: true,
        message: 'Signing out…',
      ),
    );
    bool failed = false;
    try {
      await _storage?.lock();
    } catch (_) {
      failed = true;
    }
    try {
      if (_logoutPendingUid != null) {
        await vault.invalidate(_logoutPendingUid!);
      } else {
        await vault.lock();
      }
    } catch (_) {
      failed = true;
    }
    try {
      await auth.signOut();
    } catch (_) {
      failed = true;
    }
    _signingOut = false;
    if (isClosed) return;
    if (failed || auth.current != null) {
      _lock('Sign-out could not be completed securely. Retry sign-out.');
    } else {
      _seenUid = null;
      _observed = true;
      _logoutPendingUid = null;
      emit(SessionState(SessionStatus.signedOut, busy: _loginPending));
    }
  }

  @override
  Future<void> close() async {
    if (_closingSession) return _closingFuture;
    _closingSession = true;
    final closing = _closeSession();
    _closingFuture = closing;
    try {
      await closing;
    } finally {
      await super.close();
    }
  }

  Future<void> _closeSession() async {
    ++_revision;
    _cancelTimers();
    _invalidateStorage();
    await _subscription.cancel();
    await _storage?.dispose();
    await _storageEvents.close();
  }
}
