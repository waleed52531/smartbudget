import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/features/auth/data/session_environment.dart';
import 'package:smartbudget/features/auth/data/worker_authorization_transport.dart';
import 'package:smartbudget/features/auth/domain/session_contracts.dart';
import 'package:smartbudget/features/auth/presentation/session_cubit.dart';
import 'support.dart';

Future<WorkerAuthorizationTransport> transport(
  Future<void> Function(HttpRequest) handler, {
  String? Function()? currentUid,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen(handler);
  addTearDown(() => server.close(force: true));
  final base = Uri.parse('http://127.0.0.1:${server.port}');
  return WorkerAuthorizationTransport(
    endpoint: base.resolve('/authorizeSession'),
    keysEndpoint: base.resolve('/leaseVerificationKeys'),
    credentials: () async => const WorkerCredentials(
      'synthetic',
      'synthetic-id-token',
      'synthetic-app-token',
    ),
    currentUid: currentUid ?? () => 'synthetic',
  );
}

Matcher failure(SessionFailureKind kind) =>
    isA<SessionFailure>().having((e) => e.kind, 'failure kind', kind);

void main() {
  test(
    'Worker HTTPS origin is compiled and constrained; no Cloud Functions fallback',
    () {
      for (final origin in [
        'http://smartbudget-authorization.synthetic.workers.dev',
        'https://other-worker.synthetic.workers.dev',
        'https://smartbudget-authorization.synthetic.workers.dev.attacker.test',
        'https://user@smartbudget-authorization.synthetic.workers.dev',
        'https://smartbudget-authorization.synthetic.workers.dev:8443',
        'https://smartbudget-authorization.synthetic.workers.dev/path',
        'https://smartbudget-authorization.synthetic.workers.dev?token=synthetic',
      ]) {
        expect(
          () => SessionEnvironment.validated(
            emulator: false,
            debugBuild: false,
            host: 'unused',
            workerOrigin: origin,
          ),
          throwsFormatException,
        );
      }
      final missing = SessionEnvironment.validated(
        emulator: false,
        debugBuild: false,
        host: 'unused',
      );
      expect(() => missing.keysEndpoint, throwsFormatException);
      expect(() => missing.authorizationEndpoint, throwsFormatException);
      final production = SessionEnvironment.validated(
        emulator: false,
        debugBuild: false,
        host: 'unused',
        workerOrigin: 'https://smartbudget-authorization.synthetic.workers.dev',
      );
      expect(production.authorizationEndpoint.path, '/authorizeSession');
      expect(
        () => SessionEnvironment.validated(
          emulator: true,
          debugBuild: true,
          host: '127.0.0.1',
          workerOrigin: production.workerOrigin.toString(),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'HTTP transport sends Firebase and App Check tokens with installation only',
    () async {
      final worker = await transport((request) async {
        expect(request.method, 'POST');
        expect(
          request.headers.value('authorization'),
          'Bearer synthetic-id-token',
        );
        expect(
          request.headers.value('x-firebase-appcheck'),
          'synthetic-app-token',
        );
        expect(jsonDecode(await utf8.decoder.bind(request).join()), {
          'installationId': installation,
        });
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'lease': 'synthetic-signed-lease'}));
        await request.response.close();
      });
      expect(await worker.call(installation), {
        'lease': 'synthetic-signed-lease',
      });
    },
  );

  for (final scenario in [
    (401, 'unauthenticated', SessionFailureKind.denied),
    (403, 'permission-denied', SessionFailureKind.denied),
    (403, 'app-check-failed', SessionFailureKind.attestation),
    (404, 'not-found', SessionFailureKind.configuration),
    (503, 'unavailable', SessionFailureKind.unavailable),
    (429, 'resource-exhausted', SessionFailureKind.unavailable),
  ]) {
    test(
      'HTTP ${scenario.$1} ${scenario.$2} yields a distinct safe failure',
      () async {
        final worker = await transport((request) async {
          request.response.statusCode = scenario.$1;
          request.response.write(
            jsonEncode({
              'error': {'code': scenario.$2},
            }),
          );
          await request.response.close();
        });
        await expectLater(
          worker.call(installation),
          throwsA(failure(scenario.$3)),
        );
      },
    );
  }

  test(
    'malformed success cannot be mistaken for a network outage or reuse old authorization',
    () async {
      final worker = await transport((request) async {
        request.response.write('<html>not a lease</html>');
        await request.response.close();
      });
      await expectLater(
        worker.call(installation),
        throwsA(failure(SessionFailureKind.invalidLease)),
      );
    },
  );

  test('HTTP redirects never forward credentials to a second host', () async {
    var redirected = false;
    final destination = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    destination.listen((request) async {
      redirected = true;
      await request.response.close();
    });
    addTearDown(() => destination.close(force: true));
    final worker = await transport((request) async {
      request.response.statusCode = 307;
      request.response.headers.set(
        'location',
        'http://127.0.0.1:${destination.port}/',
      );
      await request.response.close();
    });
    await expectLater(
      worker.call(installation),
      throwsA(failure(SessionFailureKind.configuration)),
    );
    expect(redirected, false);
  });

  test('account switching discards an in-flight Worker response', () async {
    var uid = 'synthetic';
    final worker = await transport((request) async {
      uid = 'another';
      request.response.write(jsonEncode({'lease': 'synthetic'}));
      await request.response.close();
    }, currentUid: () => uid);
    await expectLater(
      worker.call(installation),
      throwsA(failure(SessionFailureKind.denied)),
    );
  });

  for (final scenario in [
    (SessionFailureKind.configuration, 'backend is not configured'),
    (SessionFailureKind.attestation, 'App verification'),
    (SessionFailureKind.network, 'could not be reached'),
    (SessionFailureKind.unavailable, 'service is unavailable'),
    (SessionFailureKind.denied, 'account is not authorized'),
  ]) {
    test('locked screen explains ${scenario.$1.name} separately', () async {
      final h = Harness(initial: alice);
      h.gateway.failure = scenario.$1;
      final session = h.create();
      addTearDown(session.close);
      await waitFor(() => session.state.status == SessionStatus.locked);
      expect(session.state.message, contains(scenario.$2));
      expect(session.storageGrant, isNull);
    });
  }

  test(
    'previously authorized same-user lease still permits a genuine network outage',
    () async {
      final h = Harness(initial: alice);
      var session = h.create();
      await waitFor(() => session.state.status == SessionStatus.authorized);
      await session.close();
      h.gateway.failure = SessionFailureKind.network;
      session = h.create();
      addTearDown(session.close);
      await waitFor(() => session.state.status == SessionStatus.authorized);
      expect(session.state.offline, true);
    },
  );
}
