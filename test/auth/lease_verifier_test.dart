import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/features/auth/data/session_environment.dart';
import 'package:smartbudget/features/auth/domain/lease_verifier.dart';
import 'package:smartbudget/features/auth/domain/session_contracts.dart';
import 'support.dart';

void main() {
  final verifier = LeaseVerifier(projectId: fixture['projectId']);
  Future<VerifiedLease> verify(
    AuthorizationBundle bundle, {
    String? uid,
    String? install,
    int? now,
    LeaseVerifier? using,
  }) => (using ?? verifier).verify(
    bundle,
    uid: uid ?? alice.uid,
    installationId: install ?? installation,
    nowSeconds: now ?? fixture['now'],
  );
  final rejected = throwsA(isA<SessionFailure>());

  test(
    'Dart verifies a lease issued by the actual Stage 2 Node signer',
    () async {
      final lease = await verify(fixtureBundle());
      expect(lease.uid, alice.uid);
      expect(lease.expiresAt - lease.issuedAt, 86400);
      expect(verifier.parseKeys(fixtureBundle().keys).length, 2);
    },
  );
  test(
    'expiry, issue time, UID, installation, project and policy are enforced',
    () async {
      await expectLater(
        verify(fixtureBundle(), now: fixture['now'] + 86400),
        rejected,
      );
      await expectLater(
        verify(fixtureBundle(), now: fixture['now'] - 1),
        rejected,
      );
      await expectLater(verify(fixtureBundle(), uid: bob.uid), rejected);
      await expectLater(
        verify(
          fixtureBundle(),
          install: '87654321-1234-4234-8234-123456789abc',
        ),
        rejected,
      );
      await expectLater(
        verify(
          fixtureBundle(),
          using: const LeaseVerifier(projectId: 'wrong-project'),
        ),
        rejected,
      );
      await expectLater(
        verify(
          fixtureBundle(),
          using: LeaseVerifier(
            projectId: fixture['projectId'],
            policyVersion: 2,
          ),
        ),
        rejected,
      );
    },
  );
  test('modified expiry and invalid signature never verify', () async {
    final parts = fixtureBundle().lease.split('.');
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    claims['exp'] += 86400;
    final modified = base64Url
        .encode(utf8.encode(jsonEncode(claims)))
        .replaceAll('=', '');
    await expectLater(
      verify(
        AuthorizationBundle(
          '${parts[0]}.$modified.${parts[2]}',
          fixtureBundle().keys,
        ),
      ),
      rejected,
    );
    await expectLater(
      verify(
        AuthorizationBundle(
          '${parts[0]}.${parts[1]}.${base64Url.encode(List.filled(64, 0)).replaceAll('=', '')}',
          fixtureBundle().keys,
        ),
      ),
      rejected,
    );
  });
  test(
    'rotation supports overlap and rejects removed or unknown key IDs',
    () async {
      await verify(fixtureBundle(rotated: true));
      final onlySecond = {
        'keys': [(fixture['keys']['keys'] as List)[1]],
      };
      await verify(
        AuthorizationBundle(fixtureBundle(rotated: true).lease, onlySecond),
      );
      await expectLater(
        verify(AuthorizationBundle(fixtureBundle().lease, onlySecond)),
        rejected,
      );
    },
  );
  test(
    'private key fields, duplicate IDs, malformed encodings and algorithms are rejected',
    () async {
      final key = Map<String, dynamic>.from(fixture['keys']['keys'][0]);
      expect(
        () => verifier.parseKeys({
          'keys': [
            {...key, 'd': 'private'},
          ],
        }),
        rejected,
      );
      expect(
        () => verifier.parseKeys({
          'keys': [key, key],
        }),
        rejected,
      );
      final parts = fixtureBundle().lease.split('.');
      await expectLater(
        verify(
          AuthorizationBundle(
            '${parts[0]}=.${parts[1]}.${parts[2]}',
            fixtureBundle().keys,
          ),
        ),
        rejected,
      );
      final header = base64Url
          .encode(
            utf8.encode(
              jsonEncode({
                'alg': 'none',
                'typ': 'sb-auth-lease+jwt',
                'kid': 'first',
              }),
            ),
          )
          .replaceAll('=', '');
      await expectLater(
        verify(
          AuthorizationBundle(
            '$header.${parts[1]}.${parts[2]}',
            fixtureBundle().keys,
          ),
        ),
        rejected,
      );
    },
  );
  test(
    'release/profile cannot enable emulator authorization or arbitrary key origins',
    () {
      expect(
        () => SessionEnvironment.validated(
          emulator: true,
          debugBuild: false,
          host: '127.0.0.1',
        ),
        throwsFormatException,
      );
      expect(
        () => SessionEnvironment.validated(
          emulator: true,
          debugBuild: true,
          host: 'untrusted.example',
        ),
        throwsFormatException,
      );
      final production = SessionEnvironment.validated(
        emulator: false,
        debugBuild: false,
        host: 'unused',
        workerOrigin: 'https://smartbudget-authorization.synthetic.workers.dev',
      );
      expect(
        production.keysEndpoint.toString(),
        'https://smartbudget-authorization.synthetic.workers.dev/leaseVerificationKeys',
      );
    },
  );
  test(
    'clock guard rejects rollback and reboot, and never moves trusted time back',
    () {
      final cached = CachedAuthorization(
        bundle: fixtureBundle(),
        clock: const ClockSnapshot(
          wallMs: 10000,
          elapsedMs: 10000,
          bootId: 'one',
        ),
        trustedMs: 12000,
      );
      expect(
        cached.timeAt(
          const ClockSnapshot(wallMs: 14000, elapsedMs: 14000, bootId: 'one'),
        ),
        16000,
      );
      expect(
        () => cached.timeAt(
          const ClockSnapshot(wallMs: 9000, elapsedMs: 15000, bootId: 'one'),
        ),
        rejected,
      );
      expect(
        () => cached.timeAt(
          const ClockSnapshot(wallMs: 15000, elapsedMs: 10, bootId: 'two'),
        ),
        rejected,
      );
    },
  );
}
