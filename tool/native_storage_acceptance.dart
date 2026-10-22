// Device-only acceptance entry point. Build explicitly with --debug --target;
// never used by lib/main.dart. All identities/data belong to one disposable run.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:smartbudget/core/user_storage/database_key_vault.dart';
import 'package:smartbudget/core/user_storage/encrypted_database_factory.dart';
import 'package:smartbudget/core/user_storage/storage_access.dart';
import 'package:smartbudget/core/user_storage/user_database_manager.dart';
import 'package:smartbudget/features/auth/data/firebase_session_services.dart';
import 'package:smartbudget/features/auth/data/session_vault.dart';
import 'package:smartbudget/features/auth/domain/lease_verifier.dart';
import 'package:smartbudget/features/auth/domain/session_contracts.dart';
import 'package:smartbudget/features/auth/presentation/session_cubit.dart';

const runId = String.fromEnvironment('NATIVE_ACCEPTANCE_RUN');
late String phase;
const users = ['a', 'b', 'missing', 'corrupt', 'expiry'];
final project = 'native-acceptance-$runId';
final vault = AndroidDatabaseKeyVault();
final cases = <String, String>{};
final keyDigests = <String, String>{};
final diagnostics = <String, Object?>{};
late Directory root;
File dbFile(String uid) =>
    File('${root.path}/${storageScope(project, uid)}/financial.sqlite');
File envelope(String uid) =>
    File('${root.path}/${storageScope(project, uid)}/key.envelope.json');
String digest(File file) => sha256.convert(file.readAsBytesSync()).toString();
void check(bool value, String code) {
  if (!value) throw _Failure(code);
}

void checkpoint(String step) {
  diagnostics['step'] = step;
  File('${root.path}/acceptance-$runId-progress.json').writeAsStringSync(
    jsonEncode({'diagnostics': diagnostics, 'cases': cases}),
    flush: true,
  );
}

class _Failure implements Exception {
  _Failure(this.code);
  final String code;
}

Future<void> rejected(Future<void> Function() action, String code) async {
  try {
    await action();
  } on StorageFailure {
    cases[code] = 'pass';
    return;
  }
  throw _Failure(code);
}

Future<void> waitFor(
  bool Function() condition,
  String code, {
  int seconds = 15,
}) async {
  final elapsed = Stopwatch()..start();
  while (!condition()) {
    if (elapsed.elapsed.inSeconds >= seconds) throw _Failure(code);
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

int descriptors(String uid) {
  final target = dbFile(uid).resolveSymbolicLinksSync();
  var count = 0;
  for (final entry in Directory('/proc/self/fd').listSync()) {
    try {
      if (Link(entry.path).targetSync() == target) count++;
    } catch (_) {
      /* FD closed during enumeration. */
    }
  }
  return count;
}

// The auth service and issuer are test fixtures. Production SessionCubit,
// LeaseVerifier, native clock, database manager, vault and SQLite are unmodified.
class _Auth implements AuthGateway {
  _Auth(String uid) : _current = AuthIdentity(uid, null);
  AuthIdentity? _current;
  final events = StreamController<AuthIdentity?>.broadcast();
  @override
  AuthIdentity? get current => _current;
  @override
  Stream<AuthIdentity?> get changes async* {
    yield _current;
    yield* events.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    _current = AuthIdentity(email, null);
    events.add(_current);
  }

  @override
  Future<void> signOut() async {
    _current = null;
    events.add(null);
  }

  @override
  Future<void> resetPassword(String email) async =>
      throw UnsupportedError('Not an authentication acceptance test');
}

class _LeaseStore implements ProtectedStore {
  final values = <String, String>{
    SessionVault.installationKey: '12345678-1234-4234-8234-123456789abc',
  };
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _Issuer implements AuthorizationGateway {
  _Issuer(this.keyPair, this.publicKey, this.seconds);
  final SimpleKeyPair keyPair;
  final SimplePublicKey publicKey;
  final int seconds;
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  @override
  Future<AuthorizationBundle> authorize(
    String uid,
    String installationId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = encode({
      'alg': 'EdDSA',
      'kid': 'native-test',
      'typ': 'sb-auth-lease+jwt',
    });
    final payload = encode({
      'iss': 'smartbudget:$project:authorization',
      'aud': project,
      'project_id': project,
      'sub': uid,
      'installation_id': installationId,
      'policy_version': 1,
      'jti': '$runId-$uid-$now',
      'iat': now,
      'exp': now + seconds,
    });
    final bytes = utf8.encode('$header.$payload');
    final signature = await Ed25519().sign(bytes, keyPair: keyPair);
    return AuthorizationBundle(
      '$header.$payload.${base64Url.encode(signature.bytes).replaceAll('=', '')}',
      {
        'keys': [
          {
            'kty': 'OKP',
            'crv': 'Ed25519',
            'alg': 'EdDSA',
            'use': 'sig',
            'kid': 'native-test',
            'x': base64Url.encode(publicKey.bytes).replaceAll('=', ''),
          },
        ],
      },
    );
  }
}

class _RecordingClock implements SessionClock {
  final native = PlatformSessionClock();
  final values = <Map<String, Object>>[];
  @override
  Future<ClockSnapshot> snapshot() async {
    checkpoint('native-clock-request');
    final value = await native.snapshot();
    values.add({
      ...value.toJson(),
      'dartWallMs': DateTime.now().millisecondsSinceEpoch,
    });
    diagnostics['clockSnapshots'] = values;
    checkpoint('native-clock-response');
    return value;
  }
}

class _Session {
  _Session(this.cubit, this.manager, this.auth);
  final SessionCubit cubit;
  final UserDatabaseManager manager;
  final _Auth auth;
  Future<void> close() async {
    await cubit.close();
    await auth.events.close();
  }
}

Future<_Session> _session(
  String uid, {
  int seconds = 3600,
  bool expectStorage = true,
}) async {
  checkpoint('session-test-fixture-start');
  // PUBLIC RFC 8032 section 7.1 test vector, never a service/signing secret.
  // https://www.rfc-editor.org/rfc/rfc8032.html#section-7.1
  // Avoid unrelated private-key/installation generation in a storage probe.
  List<int> vector(String hex) => List.generate(
    hex.length ~/ 2,
    (i) => int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
  );
  final public = SimplePublicKey(
    vector('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'),
    type: KeyPairType.ed25519,
  );
  final pair = SimpleKeyPairData(
    vector('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'),
    publicKey: public,
    type: KeyPairType.ed25519,
  );
  checkpoint('session-test-fixture-ready');
  final auth = _Auth(uid);
  final store = _LeaseStore();
  final sessionVault = SessionVault(store);
  final recordingClock = _RecordingClock();
  late UserDatabaseManager manager;
  final cubit = SessionCubit(
    auth: auth,
    authorization: _Issuer(pair, public, seconds),
    vault: sessionVault,
    clock: recordingClock,
    verifier: LeaseVerifier(projectId: project),
    storageFactory: (authority) {
      authority.storageChanges.listen((_) {
        final grant = authority.storageGrant;
        if (grant != null) {
          diagnostics['issuedGrant'] = {
            'trustedMs': grant.trustedMs,
            'expiresAtMs': grant.expiresAtMs,
          };
        }
      });
      return manager = UserDatabaseManager(
        authority: authority,
        factory: EncryptedDatabaseFactory(vault),
      );
    },
  );
  await waitFor(
    () =>
        cubit.state.status == SessionStatus.authorized ||
        cubit.state.status == SessionStatus.locked,
    'session-verification',
  );
  check(cubit.state.status == SessionStatus.authorized, 'signed-test-lease');
  checkpoint('before-manager-settled');
  await manager.settled;
  diagnostics['state'] = cubit.state.status.name;
  diagnostics['grantPresent'] = cubit.storageGrant != null;
  diagnostics['managerFailure'] = manager.failure?.name;
  checkpoint('after-manager-settled');
  if (expectStorage && !manager.isOpen) {
    checkpoint('before-cache-diagnostic');
    final cached = await sessionVault.cached(uid);
    checkpoint('after-cache-diagnostic');
    diagnostics['state'] = cubit.state.status.name;
    diagnostics['message'] = cubit.state.message;
    diagnostics['currentGrant'] = cubit.storageGrant != null;
    diagnostics['clockSnapshots'] = recordingClock.values;
    if (cached != null) {
      final now = await recordingClock.snapshot();
      diagnostics['cachedClock'] = cached.clock.toJson();
      diagnostics['trustedMs'] = cached.trustedMs;
      try {
        final trusted = cached.timeAt(now);
        diagnostics['cachedTimeAt'] = trusted;
        await LeaseVerifier(projectId: project).verify(
          cached.bundle,
          uid: uid,
          installationId: await sessionVault.installation(),
          nowSeconds: trusted ~/ 1000,
        );
        diagnostics['recheckedSignature'] = 'valid';
      } catch (_) {
        diagnostics['recheckedSignature'] = 'rejected';
      }
    }
    checkpoint('before-failed-session-close');
    await cubit.close();
    await auth.events.close();
    checkpoint('after-failed-session-close');
    throw _Failure('encrypted-open-${manager.failure?.name ?? 'unknown'}');
  }
  return _Session(cubit, manager, auth);
}

Future<void> _income(_Session s, int amount, {String? note}) =>
    s.manager.scope.run(
      (db) => db.insertIncome(
        amountMinor: amount,
        dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
        note: note,
      ),
    );
Future<int> _total(_Session s) => s.manager.scope.run(
  (db) async => (await db.getMonthTotals('2026-01')).totalIncome,
);
Future<void> keyFingerprint(String uid) async {
  final key = await vault.load(project, uid);
  try {
    keyDigests[uid] = sha256.convert(key.bytes).toString();
  } finally {
    key.erase();
  }
}

Future<void> _integrity(_Session s) => s.manager.scope.run((db) async {
  check(
    (await db.customSelect('PRAGMA integrity_check').getSingle())
            .data['integrity_check'] ==
        'ok',
    'sqlite-integrity',
  );
  check(
    (await db.customSelect('PRAGMA foreign_key_check').get()).isEmpty,
    'sqlite-foreign-keys',
  );
});
void unkeyedRejected(String uid) {
  final raw = sql.sqlite3.open(dbFile(uid).path, mode: sql.OpenMode.readOnly);
  var failed = false;
  try {
    raw.select('SELECT * FROM sqlite_master');
  } on sql.SqliteException {
    failed = true;
  } finally {
    raw.close();
  }
  check(failed, 'no-plaintext-fallback');
  check(
    !utf8
        .decode(
          dbFile(uid).readAsBytesSync().take(16).toList(),
          allowMalformed: true,
        )
        .startsWith('SQLite format 3'),
    'encrypted-header',
  );
}

Future<void> prepare() async {
  final registry = File('${root.path}/acceptance-$runId-registry.json');
  check(!registry.existsSync(), 'run-already-exists');
  for (final uid in users) {
    check(
      !await vault.contains(project, uid) && !dbFile(uid).parent.existsSync(),
      'pre-existing-scope',
    );
  }
  registry.writeAsStringSync(
    jsonEncode({
      'runId': runId,
      'project': project,
      'users': users,
      'preparePid': pid,
    }),
    flush: true,
  );
  final s = await _session('a');
  try {
    await s.manager.scope.run((db) => db.seedDefaultsIfEmpty());
    await _income(s, 12345, note: 'private-acceptance-$runId');
    check(descriptors('a') > 0, 'open-database-file-descriptor');
    await keyFingerprint('a');
    await _integrity(s);
    unkeyedRejected('a');
    final aScope = s.manager.scope;
    await s.cubit.signOut();
    check(
      !s.manager.isOpen && descriptors('a') == 0,
      'logout-physically-closed',
    );
    await rejected(() async {
      await aScope.run((db) => db.customSelect('SELECT 1').get());
    }, 'logout-rejects-stale-scope');
    await s.cubit.signIn('b', 'disposable-test-only');
    await waitFor(
      () => s.cubit.state.status == SessionStatus.authorized,
      'switch-b',
    );
    await s.manager.settled;
    check(descriptors('a') == 0 && await _total(s) == 0, 'user-b-isolation');
    await _income(s, 67890);
    await keyFingerprint('b');
    check(keyDigests['a'] != keyDigests['b'], 'independent-database-keys');
    await rejected(
      () => aScope.run(
        (db) => db.insertIncome(
          amountMinor: 999,
          dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
        ),
      ),
      'switch-rejects-a-writes',
    );
    await s.cubit.signOut();
    check(descriptors('b') == 0, 'switch-b-closed');
    await s.cubit.signIn('a', 'disposable-test-only');
    await waitFor(
      () => s.cubit.state.status == SessionStatus.authorized,
      'switch-a',
    );
    await s.manager.settled;
    check(await _total(s) == 12345, 'user-a-persistence');
    final entered = Completer<void>(), release = Completer<void>();
    final pending = s.manager.scope.run((db) async {
      await db.insertIncome(
        amountMinor: 999,
        dateMillis: DateTime(2026, 1, 2).millisecondsSinceEpoch,
      );
      entered.complete();
      await release.future;
    });
    final denied = rejected(() => pending, 'pending-logout-rollback');
    await entered.future;
    final logout = s.cubit.signOut();
    check(s.cubit.storageGrant == null, 'logout-instant-lock');
    release.complete();
    await denied;
    await logout;
    check(descriptors('a') == 0, 'pending-logout-physically-closed');
    cases['encrypted-create-isolation-and-switch'] = 'pass';
    cases['sqlite-integrity-and-foreign-keys'] = 'pass';
    cases['unkeyed-sqlite-rejected'] = 'pass';
  } finally {
    await s.close();
  }
  for (final uid in ['missing', 'corrupt']) {
    final s = await _session(uid);
    try {
      await _income(s, 111);
      await keyFingerprint(uid);
    } finally {
      await s.close();
    }
    check(descriptors(uid) == 0, 'failure-fixture-closed');
  }
  final expiry = await _session('expiry', seconds: 5);
  try {
    check(descriptors('expiry') > 0, 'expiry-fixture-open');
    await keyFingerprint('expiry');
    await waitFor(
      () => expiry.cubit.state.status == SessionStatus.locked,
      'expiry-timer',
      seconds: 10,
    );
    await expiry.manager.settled;
    check(
      !expiry.manager.isOpen && descriptors('expiry') == 0,
      'expiry-physically-closed',
    );
    await rejected(() async {
      await expiry.manager.scope.run((db) => db.customSelect('SELECT 1').get());
    }, 'expiry-locks-storage');
    cases['signed-lease-expiry-closes-database'] = 'pass';
  } finally {
    await expiry.close();
  }
  final value = jsonDecode(registry.readAsStringSync()) as Map<String, dynamic>;
  value['keyDigests'] = keyDigests;
  value['databaseDigests'] = {
    for (final uid in ['a', 'b', 'missing', 'corrupt'])
      uid: digest(dbFile(uid)),
  };
  value['envelopeDigests'] = {
    for (final uid in ['a', 'b', 'missing', 'corrupt'])
      uid: digest(envelope(uid)),
  };
  registry.writeAsStringSync(jsonEncode(value), flush: true);
}

Future<void> reopened() async {
  final value =
      jsonDecode(
            File(
              '${root.path}/acceptance-$runId-registry.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  check(
    value['runId'] == runId &&
        value['project'] == project &&
        value['preparePid'] != pid,
    'process-was-restarted',
  );
  for (final uid in ['a', 'b']) {
    final s = await _session(uid);
    try {
      await keyFingerprint(uid);
      check(
        keyDigests[uid] == value['keyDigests'][uid],
        'keystore-key-survived-restart',
      );
      check(
        await _total(s) == (uid == 'a' ? 12345 : 67890),
        'encrypted-reopen-totals',
      );
      await _integrity(s);
      unkeyedRejected(uid);
    } finally {
      await s.close();
    }
    check(descriptors(uid) == 0, 'restart-handle-closed');
  }
  cases['process-restart-unwrapping-and-encrypted-reopen'] = 'pass';
  final key = await vault.load(project, 'a');
  final wrong = sql.sqlite3.open(dbFile('a').path, mode: sql.OpenMode.readOnly);
  var rejectedWrong = false;
  try {
    wrong.execute("PRAGMA cipher='chacha20'");
    final bytes = Uint8List.fromList(key.bytes);
    bytes[0] ^= 0xff;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    wrong.execute("PRAGMA hexkey='$hex'");
    bytes.fillRange(0, bytes.length, 0);
    try {
      wrong.select('SELECT * FROM transactions');
    } on sql.SqliteException {
      rejectedWrong = true;
    }
  } finally {
    wrong.close();
    key.erase();
  }
  check(rejectedWrong, 'incorrect-key-rejection');
  cases['incorrect-key-rejection'] = 'pass';
  check(
    digest(dbFile('a')) == value['databaseDigests']['a'],
    'wrong-key-no-overwrite',
  );

  // A native instrumentation action removed only this run's 'missing' wrapping
  // alias between processes. No fallback key or file can be manufactured here.
  await rejected(() async {
    final key = await vault.load(project, 'missing');
    key.erase();
  }, 'missing-protected-key');
  final missing = await _session('missing', expectStorage: false);
  try {
    check(
      !missing.manager.isOpen &&
          missing.manager.failure == StorageFailureKind.keyUnavailable,
      'missing-key-safe-state',
    );
    await rejected(() async {
      await missing.manager.scope.run(
        (db) => db.customSelect('SELECT 1').get(),
      );
    }, 'missing-key-access-denied');
    check(
      digest(dbFile('missing')) == value['databaseDigests']['missing'] &&
          digest(envelope('missing')) == value['envelopeDigests']['missing'],
      'missing-key-files-preserved',
    );
    await rejected(() async {
      final key = await vault.create(project, 'missing');
      key.erase();
    }, 'missing-key-no-regeneration');
  } finally {
    await missing.close();
  }
  cases['missing-key-safe-recovery-and-preserved-files'] = 'pass';
  final corrupt = envelope('corrupt');
  final record = jsonDecode(corrupt.readAsStringSync()) as Map<String, dynamic>;
  record['databaseId'] = '00000000-0000-4000-8000-000000000000';
  corrupt.writeAsStringSync(jsonEncode(record), flush: true);
  final damagedDigest = digest(corrupt);
  final damaged = await _session('corrupt', expectStorage: false);
  try {
    check(
      !damaged.manager.isOpen &&
          damaged.manager.failure == StorageFailureKind.keyUnavailable,
      'corrupt-envelope-safe-state',
    );
    check(
      digest(corrupt) == damagedDigest &&
          digest(dbFile('corrupt')) == value['databaseDigests']['corrupt'],
      'corrupt-envelope-no-repair',
    );
    await rejected(() async {
      final key = await vault.create(project, 'corrupt');
      key.erase();
    }, 'corrupt-envelope-no-replacement');
  } finally {
    await damaged.close();
  }
  cases['corrupted-authenticated-envelope-rejected'] = 'pass';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode ||
      !Platform.isAndroid ||
      !RegExp(r'^[a-f0-9]{12}$').hasMatch(runId)) {
    throw UnsupportedError(
      'Explicit disposable debug acceptance configuration required',
    );
  }
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Disposable native storage acceptance')),
      ),
    ),
  );
  root = await vault.root();
  check(
    root.path.contains('/com.corehines.smartbudget/') &&
        root.path.endsWith('/no_backup/user_storage_v1'),
    'new-app-no-backup-root',
  );
  final prepared = File('${root.path}/acceptance-$runId-prepare-result.json');
  phase = prepared.existsSync() ? 'reopen' : 'prepare';
  if (phase == 'reopen') {
    check(
      (jsonDecode(prepared.readAsStringSync()) as Map)['status'] == 'passed',
      'prepare-did-not-pass',
    );
  }
  final result = <String, dynamic>{'runId': runId, 'phase': phase, 'pid': pid};
  try {
    if (phase == 'prepare') {
      await prepare();
    } else {
      await reopened();
    }
    result['status'] = 'passed';
  } catch (error) {
    result['status'] = 'failed';
    result['failure'] = error is _Failure
        ? error.code
        : error.runtimeType.toString();
  }
  result['diagnostics'] = diagnostics;
  result['cases'] = cases;
  result['keyDigests'] =
      keyDigests; // One-way test canaries for scanning logs; never raw keys.
  File(
    '${root.path}/acceptance-$runId-$phase-result.json',
  ).writeAsStringSync(jsonEncode(result), flush: true);
}
