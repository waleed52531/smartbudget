import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/firebase/firebase_foundation.dart';
import '../domain/session_contracts.dart';
import 'authorization_gateway.dart';
import 'session_environment.dart';
import 'worker_authorization_transport.dart';

class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuthGateway(this.auth);
  final FirebaseAuth auth;
  AuthIdentity? _identity(User? user) =>
      user == null ? null : AuthIdentity(user.uid, user.email);
  @override
  AuthIdentity? get current => _identity(auth.currentUser);
  @override
  Stream<AuthIdentity?> get changes => auth.authStateChanges().map(_identity);
  @override
  Future<void> signIn(String email, String password) async {
    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found') throw _failure(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await auth.signOut();
    } on FirebaseAuthException catch (e) {
      throw _failure(e);
    }
  }

  SessionFailure _failure(FirebaseAuthException e) => SessionFailure(
    {
          'network-request-failed',
          'too-many-requests',
          'internal-error',
        }.contains(e.code)
        ? SessionFailureKind.unavailable
        : SessionFailureKind.credentials,
  );
}

class FirebaseAuthorizationTransport implements AuthorizationTransport {
  FirebaseAuthorizationTransport(this.auth, this.functions, this.environment);
  final FirebaseAuth auth;
  final FirebaseFunctions functions;
  final SessionEnvironment environment;
  @override
  Future<Object?> call(String installationId) async {
    final user = auth.currentUser;
    if (user == null) throw const SessionFailure(SessionFailureKind.denied);
    try {
      final result = await functions
          .httpsCallable(
            'authorizeSession',
            options: HttpsCallableOptions(
              timeout: const Duration(seconds: 20),
              limitedUseAppCheckToken: !environment.emulator,
            ),
          )
          .call(<String, dynamic>{'installationId': installationId});
      if (auth.currentUser?.uid != user.uid) {
        throw const SessionFailure(SessionFailureKind.denied);
      }
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      if ({
        'unauthenticated',
        'permission-denied',
        'invalid-argument',
        'failed-precondition',
      }.contains(e.code)) {
        throw const SessionFailure(SessionFailureKind.denied);
      }
      throw SessionFailure(
        {
              'unavailable',
              'deadline-exceeded',
              'resource-exhausted',
              'not-found',
              'internal',
              'unknown',
              'cancelled',
            }.contains(e.code)
            ? SessionFailureKind.unavailable
            : SessionFailureKind.invalidLease,
      );
    } on FirebaseAuthException catch (e) {
      throw SessionFailure(
        e.code == 'network-request-failed'
            ? SessionFailureKind.unavailable
            : SessionFailureKind.denied,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> publicKeys() =>
      fetchVerificationKeys(environment.keysEndpoint);
}

class PlatformProtectedStore implements ProtectedStore {
  PlatformProtectedStore(String projectId)
    : storage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          resetOnError: false,
          migrateOnAlgorithmChange: false,
          keyCipherAlgorithm: KeyCipherAlgorithm.AES_GCM_NoPadding,
          storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
          storageNamespace: 'smartbudget_auth_v1_$projectId',
        ),
        iOptions: IOSOptions(
          accountName: 'smartbudget.auth.$projectId',
          accessibility: KeychainAccessibility.unlocked_this_device,
          synchronizable: false,
        ),
        mOptions: MacOsOptions(
          accountName: 'smartbudget.auth.$projectId',
          accessibility: KeychainAccessibility.unlocked_this_device,
          synchronizable: false,
        ),
      );
  final FlutterSecureStorage storage;
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      throw const SessionFailure(SessionFailureKind.storage);
    }
  }

  @override
  Future<String?> read(String key) => _guard(() => storage.read(key: key));
  @override
  Future<void> write(String key, String value) =>
      _guard(() => storage.write(key: key, value: value));
  @override
  Future<void> delete(String key) => _guard(() => storage.delete(key: key));
}

class PlatformSessionClock implements SessionClock {
  static const channel = MethodChannel(
    'com.corehines.smartbudget/session_clock',
  );
  @override
  Future<ClockSnapshot> snapshot() async {
    try {
      final value = await channel.invokeMapMethod<String, dynamic>('snapshot');
      if (value == null) throw const FormatException();
      return ClockSnapshot.fromJson(value);
    } catch (_) {
      throw const SessionFailure(SessionFailureKind.unavailable);
    }
  }
}

class FirebaseSessionServices {
  FirebaseSessionServices(this.auth, this.authorization);
  final AuthGateway auth;
  final AuthorizationGateway authorization;
  static Future<FirebaseSessionServices> initialize(
    SessionEnvironment environment,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Only the approved Android beta is configured.');
    }
    final FirebaseApp app;
    if (environment.emulator) {
      // Named app prevents emulator identities from mixing with the production app's sessions.
      app = await Firebase.initializeApp(
        name: 'smartbudget-auth-emulator',
        options: const FirebaseOptions(
          apiKey: 'demo-key',
          appId: '1:000000000000:android:0000000000000000000000',
          messagingSenderId: '000000000000',
          projectId: 'demo-smartbudget-authz',
        ),
      );
    } else {
      await initializeFirebaseFoundation();
      app = Firebase.app();
      // Never allow SDK-generated debug secrets to be printed into logcat.
      // Development tokens are provided from an ignored, protected build file.
      const debugToken = String.fromEnvironment(
        'SMARTBUDGET_APP_CHECK_DEBUG_TOKEN',
      );
      if (kDebugMode && debugToken.isNotEmpty) {
        await FirebaseAppCheck.instanceFor(app: app).activate(
          providerAndroid: const AndroidDebugProvider(debugToken: debugToken),
        );
      } else {
        await FirebaseAppCheck.instanceFor(
          app: app,
        ).activate(providerAndroid: const AndroidPlayIntegrityProvider());
      }
    }
    final auth = FirebaseAuth.instanceFor(app: app);
    final functions = FirebaseFunctions.instanceFor(
      app: app,
      region: environment.region,
    );
    if (environment.emulator) {
      await auth.useAuthEmulator(
        environment.host,
        9099,
        automaticHostMapping: false,
      );
      functions.useFunctionsEmulator(
        environment.host,
        5001,
        automaticHostMapping: false,
      );
    }
    final AuthorizationTransport transport;
    if (environment.emulator) {
      transport = FirebaseAuthorizationTransport(auth, functions, environment);
    } else if (environment.workerOrigin == null) {
      transport = _UnconfiguredAuthorizationTransport();
    } else {
      transport = WorkerAuthorizationTransport(
        endpoint: environment.authorizationEndpoint,
        keysEndpoint: environment.keysEndpoint,
        currentUid: () => auth.currentUser?.uid,
        credentials: () async {
          final user = auth.currentUser;
          if (user == null) {
            throw const SessionFailure(SessionFailureKind.denied);
          }
          final String? token;
          try {
            token = await user.getIdToken();
          } on FirebaseAuthException catch (e) {
            throw SessionFailure(
              e.code == 'network-request-failed'
                  ? SessionFailureKind.network
                  : SessionFailureKind.denied,
            );
          }
          final String attestation;
          try {
            attestation = await FirebaseAppCheck.instanceFor(
              app: app,
            ).getLimitedUseToken();
          } catch (_) {
            throw const SessionFailure(SessionFailureKind.attestation);
          }
          if (token == null || auth.currentUser?.uid != user.uid) {
            throw const SessionFailure(SessionFailureKind.denied);
          }
          return WorkerCredentials(user.uid, token, attestation);
        },
      );
    }
    return FirebaseSessionServices(
      FirebaseAuthGateway(auth),
      BackendAuthorizationGateway(transport),
    );
  }
}

class _UnconfiguredAuthorizationTransport implements AuthorizationTransport {
  @override
  Future<Object?> call(String installationId) async =>
      throw const SessionFailure(SessionFailureKind.configuration);
  @override
  Future<Map<String, dynamic>> publicKeys() async =>
      throw const SessionFailure(SessionFailureKind.configuration);
}
