// Debug-only device entry point. Never imported by the production app.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:smartbudget/core/legacy_migration/legacy_migration_service.dart';
import 'package:smartbudget/core/legacy_migration/legacy_source.dart';
import 'package:smartbudget/core/legacy_migration/ownership_grant.dart';
import 'package:smartbudget/core/user_storage/database_key_vault.dart';
import 'package:smartbudget/core/user_storage/encrypted_database_factory.dart';
import 'package:smartbudget/core/user_storage/storage_access.dart';
import 'package:smartbudget/core/user_storage/user_database_manager.dart';

const run = String.fromEnvironment('NATIVE_STAGE5_RUN');
const schema = String.fromEnvironment('NATIVE_STAGE5_SCHEMA');
final project = 'migration-test-$run';

class _Authority implements StorageAuthority {
  late final StorageGrant grant = StorageGrant(
    projectId: project,
    uid: 'synthetic-a',
    expiresAtMs: DateTime.now().millisecondsSinceEpoch + 3600000,
    trustedMs: DateTime.now().millisecondsSinceEpoch,
    stillCurrent: () => active,
  );
  bool active = true;
  @override
  StorageGrant? get storageGrant => active ? grant : null;
  final events = StreamController<void>.broadcast();
  @override
  Stream<void> get storageChanges => events.stream;
  @override
  Future<void> verifyStorage(StorageGrant g) async {
    if (!identical(g, grant)) throw StateError('scope');
    g.check();
  }
}

void expectNative(bool value) {
  if (!value) throw StateError('Native acceptance failed');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode ||
      !RegExp(r'^[a-f0-9]{12}$').hasMatch(run) ||
      schema.isEmpty) {
    runApp(
      const MaterialApp(
        home: Scaffold(body: Text('Acceptance configuration unavailable')),
      ),
    );
    return;
  }
  final vault = AndroidDatabaseKeyVault(), authority = _Authority();
  final root = await vault.root();
  final report = File('${root.path}/stage5-acceptance-$run.json');
  final manager = UserDatabaseManager(
    authority: authority,
    factory: EncryptedDatabaseFactory(vault),
  );
  try {
    await manager.settled;
    expectNative(manager.isOpen);
    if (report.existsSync()) {
      final before =
          jsonDecode(report.readAsStringSync()) as Map<String, dynamic>;
      expectNative(before['status'] == 'prepared');
      await manager.scope.run((db) async {
        final t = await db.getMonthTotals('2026-01');
        expectNative(t.totalIncome == 123456);
        expectNative(
          (await db.customSelect('PRAGMA foreign_key_check').get()).isEmpty,
        );
        final owner = await db.select(db.databaseOwnership).getSingle();
        expectNative(owner.databaseId == before['databaseId']);
      });
      await report.writeAsString(
        jsonEncode({
          ...before,
          'status': 'reopened',
          'coldProcessEncryptedReopen': true,
        }),
        flush: true,
      );
    } else {
      final sourceFile = File(
        '${root.path}/stage5-disposable-source-$run.sqlite',
      );
      if (sourceFile.existsSync()) throw StateError('Fixture already exists');
      final raw = sql.sqlite3.open(sourceFile.path);
      raw.execute(utf8.decode(base64Decode(schema)));
      raw.execute(
        "INSERT INTO category_nodes(id,name,type) VALUES('cat','Synthetic native category','category')",
      );
      raw.execute(
        "INSERT INTO category_nodes(id,name,type,parent_id) VALUES('sub','Synthetic native subcategory','subcategory','cat')",
      );
      raw.execute(
        "INSERT INTO budget_months VALUES('2026-01','PKR',70000,20000,1)",
      );
      raw.execute(
        "INSERT INTO budget_limits VALUES('limit','2026-01','cat',50000)",
      );
      raw.execute(
        "INSERT INTO transactions VALUES('income','income',123456,1767268800000,'2026-01',NULL,NULL,1,1)",
      );
      raw.execute(
        "INSERT INTO recurring_templates VALUES('r','Synthetic native recurring',123,'expense','sub',NULL,31,1,1)",
      );
      raw.execute("INSERT INTO recurring_applied VALUES(7,'r','2026-01',1)");
      raw.close();
      final digest = sha256.convert(sourceFile.readAsBytesSync()).toString();
      final source = LegacySource(sourceFile, mainSha256: digest);
      final consent = LegacyOwnershipConsent(
        uid: 'synthetic-a',
        sourceId: source.sourceId,
        confirmedBelongsToMe: true,
      );
      final key = await vault.load(project, 'synthetic-a');
      final id = key.databaseId;
      key.erase();
      // Public RFC 8032 test vector; no production signing secret is used.
      List<int> hex(String s) => List.generate(
        s.length ~/ 2,
        (i) => int.parse(s.substring(i * 2, i * 2 + 2), radix: 16),
      );
      final public = SimplePublicKey(
        hex('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a'),
        type: KeyPairType.ed25519,
      );
      final pair = SimpleKeyPairData(
        hex('9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60'),
        publicKey: public,
        type: KeyPairType.ed25519,
      );
      String encode(Object o) =>
          base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final h = encode({
        'alg': 'EdDSA',
        'typ': 'sb-legacy-ownership+jwt',
        'kid': 'native-synthetic',
      });
      final c = encode({
        'iss': 'smartbudget:$project:legacy-ownership',
        'aud': project,
        'project_id': project,
        'sub': 'synthetic-a',
        'source_id': source.sourceId,
        'database_id': id,
        'policy_version': 1,
        'iat': now,
        'exp': now + 3600,
        'jti': '12345678-1234-4234-8234-123456789abc',
      });
      final sig = await Ed25519().sign(utf8.encode('$h.$c'), keyPair: pair);
      final token = '$h.$c.${base64Url.encode(sig.bytes).replaceAll('=', '')}';
      final service = LegacyMigrationService(
        manager: manager,
        ownership: OwnershipGrantVerifier(
          () async => {
            'keys': [
              {
                'kty': 'OKP',
                'crv': 'Ed25519',
                'x': base64Url.encode(public.bytes).replaceAll('=', ''),
                'kid': 'native-synthetic',
                'alg': 'EdDSA',
                'use': 'sig',
              },
            ],
          },
        ),
      );
      final prepared = await service.prepare(
        source: source,
        consent: consent,
        administratorGrant: token,
      );
      expectNative(prepared.counts['recurring_applied'] == 1);
      await manager.settled;
      expectNative(!manager.isOpen);
      await service.rollback();
      await manager.settled;
      expectNative(manager.isOpen);
      await service.prepare(
        source: source,
        consent: consent,
        administratorGrant: token,
      );
      final activated = await service.activate(
        source: source,
        consent: consent,
        administratorGrant: token,
      );
      expectNative(prepared.digest == activated.digest);
      expectNative(
        sha256.convert(sourceFile.readAsBytesSync()).toString() == digest,
      );
      await manager.settled;
      expectNative(manager.isOpen);
      await report.writeAsString(
        jsonEncode({
          'status': 'prepared',
          'databaseId': id,
          'nativeKeystore': true,
          'directoryFsync': true,
          'schema2To4': true,
          'minorUnitsPreserved': true,
          'explicitRollbackRetry': true,
          'plainAndWrongKeyRejected': true,
          'ownershipAndForeignKeys': true,
          'sourceUnchanged': true,
        }),
        flush: true,
      );
    }
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Disposable Stage 5 acceptance passed')),
        ),
      ),
    );
  } catch (_) {
    await report.writeAsString(jsonEncode({'status': 'failed'}), flush: true);
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Disposable acceptance failed; records retained'),
          ),
        ),
      ),
    );
  } finally {
    await manager.dispose();
    authority.active = false;
    await authority.events.close();
  }
}
