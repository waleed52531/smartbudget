import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/features/auth/data/authorization_gateway.dart';
import 'package:smartbudget/features/auth/data/session_vault.dart';
import 'package:smartbudget/features/auth/domain/lease_verifier.dart';
import 'package:smartbudget/features/auth/domain/session_contracts.dart';
import 'package:smartbudget/features/auth/presentation/session_cubit.dart';
import 'support.dart';

const enabled = bool.fromEnvironment('SMARTBUDGET_AUTH_EMULATOR_TEST');
const project = 'demo-smartbudget-authz';
const base = 'http://127.0.0.1:5001/$project/asia-south1';

Future<({int status, Map<String, dynamic> body})> request(
  Uri endpoint,
  Map<String, dynamic> body, {
  String? token,
}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final req = await client.postUrl(endpoint);
    req.headers.contentType = ContentType.json;
    if (token != null) req.headers.set('Authorization', 'Bearer $token');
    req.write(jsonEncode(body));
    final res = await req.close().timeout(const Duration(seconds: 20));
    return (
      status: res.statusCode,
      body:
          jsonDecode(await utf8.decoder.bind(res).join())
              as Map<String, dynamic>,
    );
  } finally {
    client.close(force: true);
  }
}

class EmulatorTransport implements AuthorizationTransport {
  EmulatorTransport(this.token);
  final String token;
  bool offline = false;
  @override
  Future<Object?> call(String installationId) async {
    try {
      final response = await request(
        Uri.parse(
          offline ? 'http://127.0.0.1:59999' : '$base/authorizeSession',
        ),
        {
          'data': {'installationId': installationId},
        },
        token: token,
      );
      if (response.status == 401 || response.status == 403) {
        throw const SessionFailure(SessionFailureKind.denied);
      }
      if (response.status != 200) {
        throw const SessionFailure(SessionFailureKind.unavailable);
      }
      return response.body['result'];
    } on SocketException {
      throw const SessionFailure(SessionFailureKind.unavailable);
    }
  }

  @override
  Future<Map<String, dynamic>> publicKeys() =>
      fetchVerificationKeys(Uri.parse('$base/leaseVerificationKeys'));
}

class EmulatorClock implements SessionClock {
  final watch = Stopwatch()..start();
  @override
  Future<ClockSnapshot> snapshot() async => ClockSnapshot(
    wallMs: DateTime.now().millisecondsSinceEpoch,
    elapsedMs: watch.elapsedMilliseconds,
    bootId: 'isolated-client-test',
  );
}

Future<void> provision(String command, String uid) async {
  final result = await Process.run(
    'node',
    [
      'functions/lib/src/admin_cli.js',
      command,
      '--project',
      project,
      '--emulator',
      '--uid',
      uid,
    ],
    environment: {
      'GCLOUD_PROJECT': project,
      'GOOGLE_CLOUD_PROJECT': project,
      'FIRESTORE_EMULATOR_HOST': '127.0.0.1:8080',
      'FIREBASE_AUTH_EMULATOR_HOST': '127.0.0.1:9099',
    },
  );
  expect(
    result.exitCode,
    0,
    reason: 'Local demo administrator operation must succeed. Output omitted.',
  );
}

void main() {
  test(
    'Dart consumes real emulator authorization, restores offline and rejects revoked access',
    () async {
      expect(Platform.environment.containsKey('GEMINI_API_KEY'), false);
      final email =
          'synthetic-stage3-${DateTime.now().microsecondsSinceEpoch}@example.test';
      const password = 'Synthetic-only-Password-123!';
      Uri auth(String action) => Uri.parse(
        'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:$action?key=demo-key',
      );
      final created = await request(auth('signUp'), {
        'email': email,
        'password': password,
        'returnSecureToken': true,
      });
      expect(created.status, 200);
      final failed = await request(auth('signInWithPassword'), {
        'email': email,
        'password': 'synthetic-wrong-password',
        'returnSecureToken': true,
      });
      expect(failed.status, 400);
      final loggedIn = await request(auth('signInWithPassword'), {
        'email': email,
        'password': password,
        'returnSecureToken': true,
      });
      expect(loggedIn.status, 200);
      final reset = await request(auth('sendOobCode'), {
        'requestType': 'PASSWORD_RESET',
        'email': email,
      });
      expect(reset.status, 200);
      final uid = loggedIn.body['localId'] as String;
      final transport = EmulatorTransport(loggedIn.body['idToken']);
      final identity = FakeAuth(AuthIdentity(uid, email)),
          storage = MemoryStore(),
          clock = EmulatorClock();
      SessionCubit create() => SessionCubit(
        auth: identity,
        authorization: BackendAuthorizationGateway(transport),
        vault: SessionVault(storage),
        clock: clock,
        verifier: const LeaseVerifier(projectId: project),
      );
      var session = create();
      addTearDown(() async {
        await session.close();
        await identity.events.close();
      });
      await waitFor(() => session.state.status == SessionStatus.locked);
      await provision('approve', uid);
      await session.refresh();
      expect(session.state.status, SessionStatus.authorized);
      expect(session.state.offline, false);
      await session.close();
      transport.offline = true;
      session = create();
      await waitFor(() => session.state.status == SessionStatus.authorized);
      expect(session.state.offline, true);
      transport.offline = false;
      await provision('revoke', uid);
      await session.refresh();
      expect(session.state.status, SessionStatus.locked);
      expect(storage.values[SessionVault.bindingKey], '');
      await session.signOut();
      expect(session.state.status, SessionStatus.signedOut);
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
