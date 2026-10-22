import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'session_contracts.dart';

class VerifiedLease {
  const VerifiedLease({
    required this.uid,
    required this.issuedAt,
    required this.expiresAt,
  });
  final String uid;
  final int issuedAt;
  final int expiresAt;
}

/// Implements the Stage 2 compact JWS contract over the original signed bytes.
class LeaseVerifier {
  const LeaseVerifier({required this.projectId, this.policyVersion = 1});
  final String projectId;
  final int policyVersion;
  static final _kid = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final _base64 = RegExp(r'^[A-Za-z0-9_-]+$');
  static final installationPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  List<int> _decode(String part) {
    if (!_base64.hasMatch(part)) throw const FormatException();
    final bytes = base64Url.decode(base64Url.normalize(part));
    if (base64Url.encode(bytes).replaceAll('=', '') != part) {
      throw const FormatException();
    }
    return bytes;
  }

  bool _fields(Map<String, dynamic> value, String names) =>
      (value.keys.toList()..sort()).join(',') == names;

  Map<String, List<int>> parseKeys(Map<String, dynamic> value) {
    try {
      if (!_fields(value, 'keys') || value['keys'] is! List) {
        throw const FormatException();
      }
      final entries = value['keys'] as List;
      if (entries.isEmpty || entries.length > 5) throw const FormatException();
      final keys = <String, List<int>>{};
      for (final entry in entries) {
        final k = entry as Map<String, dynamic>;
        if (!_fields(k, 'alg,crv,kid,kty,use,x') ||
            k['kty'] != 'OKP' ||
            k['crv'] != 'Ed25519' ||
            k['alg'] != 'EdDSA' ||
            k['use'] != 'sig' ||
            k['kid'] is! String ||
            !_kid.hasMatch(k['kid']) ||
            keys.containsKey(k['kid']) ||
            k['x'] is! String) {
          throw const FormatException();
        }
        final bytes = _decode(k['x']);
        if (bytes.length != 32) throw const FormatException();
        keys[k['kid']] = bytes;
      }
      return keys;
    } catch (_) {
      throw const SessionFailure(SessionFailureKind.invalidLease);
    }
  }

  Future<VerifiedLease> verify(
    AuthorizationBundle bundle, {
    required String uid,
    required String installationId,
    required int nowSeconds,
  }) async {
    try {
      if (bundle.lease.length > 4096 ||
          !installationPattern.hasMatch(installationId) ||
          uid.isEmpty ||
          nowSeconds < 0) {
        throw const FormatException();
      }
      final parts = bundle.lease.split('.');
      if (parts.length != 3) throw const FormatException();
      final header =
          jsonDecode(utf8.decode(_decode(parts[0]))) as Map<String, dynamic>;
      if (!_fields(header, 'alg,kid,typ') ||
          header['alg'] != 'EdDSA' ||
          header['typ'] != 'sb-auth-lease+jwt' ||
          header['kid'] is! String ||
          !_kid.hasMatch(header['kid'])) {
        throw const FormatException();
      }
      final keys = parseKeys(bundle.keys);
      final key = keys[header['kid']];
      final signature = _decode(parts[2]);
      if (key == null ||
          signature.length != 64 ||
          !await Ed25519().verify(
            utf8.encode('${parts[0]}.${parts[1]}'),
            signature: Signature(
              signature,
              publicKey: SimplePublicKey(key, type: KeyPairType.ed25519),
            ),
          )) {
        throw const FormatException();
      }
      final c =
          jsonDecode(utf8.decode(_decode(parts[1]))) as Map<String, dynamic>;
      if (!_fields(
            c,
            'aud,exp,iat,installation_id,iss,jti,policy_version,project_id,sub',
          ) ||
          c['iss'] != 'smartbudget:$projectId:authorization' ||
          c['aud'] != projectId ||
          c['project_id'] != projectId ||
          c['sub'] != uid ||
          c['installation_id'] != installationId ||
          c['policy_version'] is! int ||
          c['policy_version'] != policyVersion ||
          c['jti'] is! String ||
          (c['jti'] as String).isEmpty ||
          c['iat'] is! int ||
          c['exp'] is! int ||
          c['iat'] < 0 ||
          c['iat'] > nowSeconds ||
          c['exp'] <= nowSeconds ||
          c['exp'] <= c['iat'] ||
          c['exp'] - c['iat'] > 86400 ||
          c['exp'] > 9007199254740991) {
        throw const FormatException();
      }
      return VerifiedLease(uid: uid, issuedAt: c['iat'], expiresAt: c['exp']);
    } catch (_) {
      throw const SessionFailure(SessionFailureKind.invalidLease);
    }
  }
}
