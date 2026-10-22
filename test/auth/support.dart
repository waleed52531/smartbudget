import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:smartbudget/features/auth/data/session_vault.dart';
import 'package:smartbudget/features/auth/domain/lease_verifier.dart';
import 'package:smartbudget/features/auth/domain/session_contracts.dart';
import 'package:smartbudget/features/auth/presentation/session_cubit.dart';

final fixture =
    jsonDecode(
          File('test/fixtures/stage2_authorization.json').readAsStringSync(),
        )
        as Map<String, dynamic>;
final installation = fixture['installationId'] as String;
final alice = AuthIdentity(fixture['uid'], 'synthetic@example.test');
final bob = AuthIdentity(fixture['secondUid'], 'second@example.test');
AuthorizationBundle fixtureBundle({
  bool secondUser = false,
  bool rotated = false,
}) => AuthorizationBundle(
  fixture[secondUser
      ? 'secondUserLease'
      : rotated
      ? 'rotatedLease'
      : 'lease'],
  fixture['keys'],
);

class MemoryStore implements ProtectedStore {
  final values = <String, String>{SessionVault.installationKey: installation};
  bool fail = false;
  Completer<void>? delayedWrite;
  bool writeWaiting = false;
  void _check() {
    if (fail) throw const SessionFailure(SessionFailureKind.storage);
  }

  @override
  Future<String?> read(String key) async {
    _check();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _check();
    if (key.startsWith('auth.lease.') && delayedWrite != null) {
      writeWaiting = true;
      await delayedWrite!.future;
      delayedWrite = null;
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _check();
    values.remove(key);
  }
}

class FakeAuth implements AuthGateway {
  FakeAuth([AuthIdentity? initial]) : _user = initial;
  AuthIdentity? _user;
  final events = StreamController<AuthIdentity?>.broadcast();
  bool failLogin = false, failReset = false, failLogout = false;
  int resets = 0, logins = 0;
  Completer<void>? pendingLogin;
  @override
  AuthIdentity? get current => _user;
  @override
  Stream<AuthIdentity?> get changes async* {
    yield _user;
    yield* events.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    logins++;
    if (pendingLogin != null) await pendingLogin!.future;
    if (failLogin) throw const SessionFailure(SessionFailureKind.credentials);
    _user = email.startsWith('second') ? bob : alice;
    events.add(_user);
  }

  @override
  Future<void> resetPassword(String email) async {
    resets++;
    if (failReset) throw const SessionFailure(SessionFailureKind.unavailable);
  }

  @override
  Future<void> signOut() async {
    if (failLogout) throw const SessionFailure(SessionFailureKind.unavailable);
    _user = null;
    events.add(null);
  }
}

class FakeClock implements SessionClock {
  int wall = (fixture['now'] as int) * 1000, elapsed = 100000;
  String boot = 'boot-one';
  void advance(int milliseconds) {
    wall += milliseconds;
    elapsed += milliseconds;
  }

  @override
  Future<ClockSnapshot> snapshot() async =>
      ClockSnapshot(wallMs: wall, elapsedMs: elapsed, bootId: boot);
}

class FakeAuthorization implements AuthorizationGateway {
  SessionFailureKind? failure;
  AuthorizationBundle? overrideBundle;
  Completer<AuthorizationBundle>? pending;
  int calls = 0;
  @override
  Future<AuthorizationBundle> authorize(
    String uid,
    String installationId,
  ) async {
    calls++;
    if (failure != null) throw SessionFailure(failure!);
    if (pending != null) return pending!.future;
    return overrideBundle ?? fixtureBundle(secondUser: uid == bob.uid);
  }
}

class Harness {
  Harness({AuthIdentity? initial, MemoryStore? storage})
    : auth = FakeAuth(initial),
      store = storage ?? MemoryStore();
  final FakeAuth auth;
  final MemoryStore store;
  final gateway = FakeAuthorization(), clock = FakeClock();
  SessionCubit create() => SessionCubit(
    auth: auth,
    authorization: gateway,
    vault: SessionVault(store),
    clock: clock,
    verifier: LeaseVerifier(projectId: fixture['projectId']),
  );
}

Future<void> waitFor(bool Function() condition) async {
  for (var i = 0; i < 1500; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  throw StateError('Expected synthetic session state not reached.');
}
