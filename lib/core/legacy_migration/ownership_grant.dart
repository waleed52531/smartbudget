import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import '../../features/auth/domain/lease_verifier.dart';
import '../user_storage/storage_access.dart';
import 'migration_journal.dart';

class LegacyOwnershipConsent {
  const LegacyOwnershipConsent({
    required this.uid,
    required this.sourceId,
    required this.confirmedBelongsToMe,
  });
  final String uid, sourceId;
  final bool confirmedBelongsToMe;
}

/// Keys must be obtained from the already trusted authorization service, never
/// from the selected source file, grant file or an import form's URL.
class OwnershipGrantVerifier {
  const OwnershipGrantVerifier(this.loadTrustedKeys);
  final Future<Map<String, dynamic>> Function() loadTrustedKeys;
  Future<void> verify(
    String grant,
    StorageGrant session,
    String sourceId,
    String databaseId,
    int nowSeconds,
  ) async {
    try {
      session.check();
      if (grant.length > 4096) throw const FormatException();
      final parts = grant.split('.');
      if (parts.length != 3) throw const FormatException();
      List<int> decode(String part) {
        if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(part)) {
          throw const FormatException();
        }
        final bytes = base64Url.decode(base64Url.normalize(part));
        if (base64Url.encode(bytes).replaceAll('=', '') != part) {
          throw const FormatException();
        }
        return bytes;
      }

      final header =
          jsonDecode(utf8.decode(decode(parts[0]))) as Map<String, dynamic>;
      if ((header.keys.toList()..sort()).join(',') != 'alg,kid,typ' ||
          header['alg'] != 'EdDSA' ||
          header['typ'] != 'sb-legacy-ownership+jwt') {
        throw const FormatException();
      }
      final keys = LeaseVerifier(
        projectId: session.projectId,
      ).parseKeys(await loadTrustedKeys());
      final public = keys[header['kid']];
      final signature = decode(parts[2]);
      if (public == null ||
          signature.length != 64 ||
          !await Ed25519().verify(
            utf8.encode('${parts[0]}.${parts[1]}'),
            signature: Signature(
              signature,
              publicKey: SimplePublicKey(public, type: KeyPairType.ed25519),
            ),
          )) {
        throw const FormatException();
      }
      final c =
          jsonDecode(utf8.decode(decode(parts[1]))) as Map<String, dynamic>;
      if ((c.keys.toList()..sort()).join(',') !=
              'aud,database_id,exp,iat,iss,jti,policy_version,project_id,source_id,sub' ||
          c['iss'] != 'smartbudget:${session.projectId}:legacy-ownership' ||
          c['aud'] != session.projectId ||
          c['project_id'] != session.projectId ||
          c['sub'] != session.uid ||
          c['source_id'] != sourceId ||
          c['database_id'] != databaseId ||
          c['policy_version'] != 1 ||
          c['jti'] is! String ||
          !LeaseVerifier.installationPattern.hasMatch(c['jti']) ||
          c['iat'] is! int ||
          c['exp'] is! int ||
          c['iat'] < 0 ||
          c['iat'] > nowSeconds ||
          c['exp'] <= nowSeconds ||
          c['exp'] <= c['iat'] ||
          c['exp'] - c['iat'] > 86400) {
        throw const FormatException();
      }
      session.check();
    } catch (_) {
      throw const LegacyMigrationFailure(MigrationFailureKind.ownership);
    }
  }
}
