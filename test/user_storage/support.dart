import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:smartbudget/core/user_storage/database_key_vault.dart';
import 'package:smartbudget/core/user_storage/storage_access.dart';
import 'package:uuid/uuid.dart';

/// Test double ONLY: real SQLite encryption is exercised with these keys, but
/// this is not an Android Keystore or Apple Keychain verification.
class TestKeyVault implements DatabaseKeyVault {
  TestKeyVault(this.directory);
  final Directory directory;
  final records = <String, DatabaseKey>{};
  final corrupt = <String>{};
  Completer<void>? delayedLoad;
  bool loadWaiting = false;
  int creates = 0;
  String scope(String project, String uid) => storageScope(project, uid);
  @override
  Future<Directory> root() async => directory;
  @override
  Future<bool> contains(String project, String uid) async =>
      records.containsKey(scope(project, uid));
  @override
  Future<DatabaseKey> create(String project, String uid) async {
    final name = scope(project, uid);
    if (records.containsKey(name)) {
      throw const StorageFailure(StorageFailureKind.keyUnavailable);
    }
    creates++;
    final random = Random.secure();
    final key = DatabaseKey(
      Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
      const Uuid().v4(),
    );
    records[name] = key;
    return DatabaseKey(Uint8List.fromList(key.bytes), key.databaseId);
  }

  @override
  Future<DatabaseKey> load(String project, String uid) async {
    loadWaiting = true;
    if (delayedLoad != null) await delayedLoad!.future;
    final name = scope(project, uid);
    final key = records[name];
    if (key == null || corrupt.contains(name)) {
      throw const StorageFailure(StorageFailureKind.keyUnavailable);
    }
    return DatabaseKey(Uint8List.fromList(key.bytes), key.databaseId);
  }

  File file(String project, String uid) =>
      File('${directory.path}/${scope(project, uid)}/financial.sqlite');
}

class TestAuthority implements StorageAuthority {
  StorageGrant? _current;
  final events = StreamController<void>.broadcast(sync: true);
  bool failVerify = false;
  static const project = 'smartbudget-test';
  void authorize(String uid, {int milliseconds = 60000}) {
    late final StorageGrant next;
    next = StorageGrant(
      projectId: project,
      uid: uid,
      expiresAtMs: milliseconds,
      trustedMs: 0,
      stillCurrent: () => identical(_current, next),
    );
    _current = next;
    events.add(null);
  }

  void revoke() {
    _current = null;
    events.add(null);
  }

  @override
  StorageGrant? get storageGrant => _current?.valid == true ? _current : null;
  @override
  Stream<void> get storageChanges => events.stream;
  @override
  Future<void> verifyStorage(StorageGrant grant) async {
    if (failVerify || !identical(grant, storageGrant)) {
      if (identical(_current, grant)) revoke();
      throw const StorageFailure(StorageFailureKind.locked);
    }
    grant.check();
  }
}
