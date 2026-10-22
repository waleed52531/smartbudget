import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../domain/session_contracts.dart';
import 'authorization_gateway.dart';

class WorkerCredentials {
  const WorkerCredentials(this.uid, this.idToken, this.appCheckToken);
  final String uid, idToken, appCheckToken;
}

/// Only a compiled, validated HTTPS Worker origin is supplied by the composition
/// root. Redirects are refused so tokens cannot follow an endpoint redirect.
class WorkerAuthorizationTransport implements AuthorizationTransport {
  WorkerAuthorizationTransport({
    required this.endpoint,
    required this.keysEndpoint,
    required this.credentials,
    required this.currentUid,
  });
  final Uri endpoint, keysEndpoint;
  final Future<WorkerCredentials> Function() credentials;
  final String? Function() currentUid;

  @override
  Future<Object?> call(String installationId) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      final auth = await credentials();
      if (currentUid() != auth.uid ||
          auth.idToken.isEmpty ||
          auth.appCheckToken.isEmpty) {
        throw const SessionFailure(SessionFailureKind.denied);
      }
      final request = await client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${auth.idToken}',
      );
      request.headers.set('X-Firebase-AppCheck', auth.appCheckToken);
      request.write(jsonEncode({'installationId': installationId}));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (currentUid() != auth.uid) {
        throw const SessionFailure(SessionFailureKind.denied);
      }
      if (response.statusCode == 403) {
        final bytes = <int>[];
        await for (final chunk in response.timeout(
          const Duration(seconds: 15),
        )) {
          bytes.addAll(chunk);
          if (bytes.length > 8192) {
            throw const SessionFailure(SessionFailureKind.invalidLease);
          }
        }
        final error = jsonDecode(utf8.decode(bytes));
        if (error is Map &&
            error['error'] is Map &&
            error['error']['code'] == 'app-check-failed') {
          throw const SessionFailure(SessionFailureKind.attestation);
        }
        throw const SessionFailure(SessionFailureKind.denied);
      }
      if (response.statusCode == 401) {
        throw const SessionFailure(SessionFailureKind.denied);
      }
      if (response.statusCode == 404 ||
          (response.statusCode >= 300 && response.statusCode < 400)) {
        throw const SessionFailure(SessionFailureKind.configuration);
      }
      if (response.statusCode == 429 || response.statusCode >= 500) {
        throw const SessionFailure(SessionFailureKind.unavailable);
      }
      if (response.statusCode != 200) {
        throw const SessionFailure(SessionFailureKind.invalidLease);
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        bytes.addAll(chunk);
        if (bytes.length > 8192) {
          throw const SessionFailure(SessionFailureKind.invalidLease);
        }
      }
      if (currentUid() != auth.uid) {
        throw const SessionFailure(SessionFailureKind.denied);
      }
      return jsonDecode(utf8.decode(bytes));
    } on SessionFailure {
      rethrow;
    } on SocketException {
      throw const SessionFailure(SessionFailureKind.network);
    } on TimeoutException {
      throw const SessionFailure(SessionFailureKind.network);
    } on HandshakeException {
      throw const SessionFailure(SessionFailureKind.invalidLease);
    } on FormatException {
      throw const SessionFailure(SessionFailureKind.invalidLease);
    } catch (_) {
      throw const SessionFailure(SessionFailureKind.unavailable);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<Map<String, dynamic>> publicKeys() =>
      fetchVerificationKeys(keysEndpoint);
}
