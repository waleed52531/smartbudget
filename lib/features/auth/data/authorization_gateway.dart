import 'dart:convert';
import 'dart:io';
import '../domain/session_contracts.dart';

abstract interface class AuthorizationTransport {
  Future<Object?> call(String installationId);
  Future<Map<String, dynamic>> publicKeys();
}

class BackendAuthorizationGateway implements AuthorizationGateway {
  BackendAuthorizationGateway(this.transport);
  final AuthorizationTransport transport;
  @override
  Future<AuthorizationBundle> authorize(
    String uid,
    String installationId,
  ) async {
    final result = await transport.call(installationId);
    if (result is! Map ||
        result.length != 1 ||
        result['lease'] is! String ||
        (result['lease'] as String).length > 4096) {
      throw const SessionFailure(SessionFailureKind.invalidLease);
    }
    return AuthorizationBundle(result['lease'], await transport.publicKeys());
  }
}

Future<Map<String, dynamic>> fetchVerificationKeys(Uri endpoint) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final request = await client
        .getUrl(endpoint)
        .timeout(const Duration(seconds: 15));
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw const SessionFailure(SessionFailureKind.unavailable);
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      bytes.addAll(chunk);
      if (bytes.length > 16384) {
        throw const SessionFailure(SessionFailureKind.invalidLease);
      }
    }
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  } on SessionFailure {
    rethrow;
  } on SocketException {
    throw const SessionFailure(SessionFailureKind.unavailable);
  } on HandshakeException {
    throw const SessionFailure(SessionFailureKind.invalidLease);
  } on HttpException {
    throw const SessionFailure(SessionFailureKind.unavailable);
  } on FormatException {
    throw const SessionFailure(SessionFailureKind.invalidLease);
  } on TypeError {
    throw const SessionFailure(SessionFailureKind.invalidLease);
  } catch (_) {
    throw const SessionFailure(SessionFailureKind.unavailable);
  } finally {
    client.close(force: true);
  }
}
