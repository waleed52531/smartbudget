import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import 'storage_access.dart';

String storageScope(String projectId, String uid) {
  if (!RegExp(r'^[a-z][a-z0-9-]{4,62}$').hasMatch(projectId) ||
      uid.isEmpty ||
      uid.length > 128 ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(uid)) {
    throw const StorageFailure(StorageFailureKind.ownership);
  }
  return sha256.convert(utf8.encode('$projectId\u0000$uid')).toString();
}

class DatabaseKey {
  // Platform message buffers may be immutable. Always own a writable copy so
  // erasure cannot throw after a successful database open or skip cleanup.
  DatabaseKey(Uint8List source, this.databaseId)
    : bytes = Uint8List.fromList(source) {
    if (bytes.length != 32 ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(databaseId)) {
      erase();
      throw const StorageFailure(StorageFailureKind.keyUnavailable);
    }
  }
  final Uint8List bytes;
  final String databaseId;
  void erase() => bytes.fillRange(0, bytes.length, 0);
}

/// No delete, reset, rotate or overwrite API. Recovery requires a separate flow.
abstract interface class DatabaseKeyVault {
  Future<Directory> root();
  Future<bool> contains(String projectId, String uid);
  Future<DatabaseKey> create(String projectId, String uid);
  Future<DatabaseKey> load(String projectId, String uid);
}

class AndroidDatabaseKeyVault implements DatabaseKeyVault {
  static const channel = MethodChannel(
    'com.corehines.smartbudget/database_keys',
  );
  Future<T> _call<T>(String method, [Map<String, String>? args]) async {
    try {
      final value = await channel.invokeMethod<T>(method, args);
      if (value == null) throw const FormatException();
      return value;
    } catch (_) {
      throw const StorageFailure(StorageFailureKind.keyUnavailable);
    }
  }

  Map<String, String> _args(String projectId, String uid) {
    storageScope(projectId, uid);
    return {'projectId': projectId, 'uid': uid};
  }

  @override
  Future<Directory> root() async => Directory(await _call<String>('root'));
  @override
  Future<bool> contains(String projectId, String uid) =>
      _call<bool>('contains', _args(projectId, uid));
  Future<DatabaseKey> _key(String method, String projectId, String uid) async {
    try {
      final value = await _call<Map<Object?, Object?>>(
        method,
        _args(projectId, uid),
      );
      return DatabaseKey(
        value['key'] as Uint8List,
        value['databaseId'] as String,
      );
    } catch (_) {
      throw const StorageFailure(StorageFailureKind.keyUnavailable);
    }
  }

  @override
  Future<DatabaseKey> create(String projectId, String uid) =>
      _key('create', projectId, uid);
  @override
  Future<DatabaseKey> load(String projectId, String uid) =>
      _key('load', projectId, uid);
}

/// Keychain is separate from the auth lease namespace, non-synchronizing and
/// accessible only while unlocked on this device. Apple Firebase remains gated.
class AppleDatabaseKeyVault implements DatabaseKeyVault {
  static const iosOptions = IOSOptions(
    accountName: 'smartbudget.database.keys.v1',
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  );
  static const macosOptions = MacOsOptions(
    accountName: 'smartbudget.database.keys.v1',
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
  );
  AppleDatabaseKeyVault()
    : _storage = const FlutterSecureStorage(
        iOptions: iosOptions,
        mOptions: macosOptions,
      );
  final FlutterSecureStorage _storage;
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      throw const StorageFailure(StorageFailureKind.keyUnavailable);
    }
  }

  String _name(String projectId, String uid) =>
      'database.${storageScope(projectId, uid)}';
  @override
  Future<Directory> root() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw const StorageFailure(StorageFailureKind.unsupported);
    }
    // The native channel creates Application Support storage excluded from backup.
    return Directory(
      await _guard(() async {
        final value = await const MethodChannel(
          'com.corehines.smartbudget/database_keys',
        ).invokeMethod<String>('root');
        if (value == null) throw const FormatException();
        return value;
      }),
    );
  }

  @override
  Future<bool> contains(String projectId, String uid) => _guard(
    () async => await _storage.containsKey(key: _name(projectId, uid)),
  );
  @override
  Future<DatabaseKey> load(String projectId, String uid) => _guard(() async {
    final encoded = await _storage.read(key: _name(projectId, uid));
    if (encoded == null || encoded.length > 2048) throw const FormatException();
    final record = jsonDecode(encoded) as Map<String, dynamic>;
    if (record['version'] != 1 ||
        record['projectId'] != projectId ||
        record['uid'] != uid) {
      throw const FormatException();
    }
    return DatabaseKey(
      base64Decode(record['key'] as String),
      record['databaseId'] as String,
    );
  });
  @override
  Future<DatabaseKey> create(String projectId, String uid) => _guard(() async {
    // Manager holds the per-scope file lock. Never overwrite a surviving keychain item.
    if (await contains(projectId, uid)) throw const FormatException();
    final support = await root();
    final folder = Directory('${support.path}/${storageScope(projectId, uid)}');
    if (folder.existsSync() &&
        folder.listSync().any((f) => !f.path.endsWith('/.lock'))) {
      throw const FormatException();
    }
    final random = Random.secure();
    final key = DatabaseKey(
      Uint8List.fromList(List.generate(32, (_) => random.nextInt(256))),
      const Uuid().v4(),
    );
    try {
      await _storage.write(
        key: _name(projectId, uid),
        value: jsonEncode({
          'version': 1,
          'projectId': projectId,
          'uid': uid,
          'databaseId': key.databaseId,
          'key': base64Encode(key.bytes),
        }),
      );
      return key;
    } catch (_) {
      key.erase();
      rethrow;
    }
  });
}

DatabaseKeyVault platformDatabaseKeyVault() {
  if (Platform.isAndroid) return AndroidDatabaseKeyVault();
  if (Platform.isIOS || Platform.isMacOS) return AppleDatabaseKeyVault();
  throw const StorageFailure(StorageFailureKind.unsupported);
}
