import 'dart:convert';

enum SessionFailureKind {
  unavailable,
  denied,
  invalidLease,
  storage,
  credentials,
  configuration,
  attestation,
  network,
}

class SessionFailure implements Exception {
  const SessionFailure(this.kind);
  final SessionFailureKind kind;
  // Never include SDK errors, credentials, tokens or account data in exceptions.
  @override
  String toString() => 'SessionFailure(${kind.name})';
}

class AuthIdentity {
  const AuthIdentity(this.uid, this.email);
  final String uid;
  final String? email;
}

abstract interface class AuthGateway {
  AuthIdentity? get current;
  Stream<AuthIdentity?> get changes;
  Future<void> signIn(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class AuthorizationBundle {
  const AuthorizationBundle(this.lease, this.keys);
  final String lease;
  final Map<String, dynamic> keys;
}

abstract interface class AuthorizationGateway {
  Future<AuthorizationBundle> authorize(String uid, String installationId);
}

abstract interface class ProtectedStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class ClockSnapshot {
  const ClockSnapshot({
    required this.wallMs,
    required this.elapsedMs,
    required this.bootId,
  });
  factory ClockSnapshot.fromJson(Map<String, dynamic> value) {
    if (value['wallMs'] is! int ||
        value['elapsedMs'] is! int ||
        value['bootId'] is! String ||
        (value['bootId'] as String).isEmpty ||
        value['wallMs'] < 0 ||
        value['elapsedMs'] < 0) {
      throw const SessionFailure(SessionFailureKind.invalidLease);
    }
    return ClockSnapshot(
      wallMs: value['wallMs'],
      elapsedMs: value['elapsedMs'],
      bootId: value['bootId'],
    );
  }
  final int wallMs;
  final int elapsedMs;
  final String bootId;
  Map<String, dynamic> toJson() => {
    'wallMs': wallMs,
    'elapsedMs': elapsedMs,
    'bootId': bootId,
  };
}

abstract interface class SessionClock {
  Future<ClockSnapshot> snapshot();
}

class CachedAuthorization {
  const CachedAuthorization({
    required this.bundle,
    required this.clock,
    required this.trustedMs,
  });
  factory CachedAuthorization.decode(String text) {
    try {
      final value = jsonDecode(text) as Map<String, dynamic>;
      if (value['version'] != 1 ||
          value['trustedMs'] is! int ||
          value['trustedMs'] < 0 ||
          value['lease'] is! String ||
          (value['lease'] as String).length > 4096) {
        throw const FormatException();
      }
      return CachedAuthorization(
        bundle: AuthorizationBundle(
          value['lease'],
          value['keys'] as Map<String, dynamic>,
        ),
        clock: ClockSnapshot.fromJson(value['clock'] as Map<String, dynamic>),
        trustedMs: value['trustedMs'],
      );
    } catch (_) {
      throw const SessionFailure(SessionFailureKind.invalidLease);
    }
  }
  final AuthorizationBundle bundle;
  final ClockSnapshot clock;
  final int trustedMs;
  String encode() => jsonEncode({
    'version': 1,
    'lease': bundle.lease,
    'keys': bundle.keys,
    'clock': clock.toJson(),
    'trustedMs': trustedMs,
  });

  int timeAt(ClockSnapshot now) {
    final elapsed = now.elapsedMs - clock.elapsedMs;
    // Reboot/monotonic uncertainty or meaningful wall-clock rollback requires online verification.
    if (now.bootId != clock.bootId ||
        elapsed < 0 ||
        now.wallMs < clock.wallMs + elapsed - 2000) {
      throw const SessionFailure(SessionFailureKind.invalidLease);
    }
    final monotonicTime = trustedMs + elapsed;
    return now.wallMs > monotonicTime ? now.wallMs : monotonicTime;
  }
}
