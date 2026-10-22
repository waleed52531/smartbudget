import 'dart:io';
import 'database_key_vault.dart';
import 'storage_access.dart';

void rejectStorageLink(String path) {
  if (FileSystemEntity.typeSync(path, followLinks: false) ==
      FileSystemEntityType.link) {
    throw const StorageFailure(StorageFailureKind.damaged);
  }
}

/// Shared by normal opening and maintenance, including within the same process.
class UserStorageLock {
  UserStorageLock._(this.directory, this._file, this._canonical);
  static final _held = <String>{};
  final Directory directory;
  final RandomAccessFile _file;
  final String _canonical;
  bool _released = false;
  static Future<UserStorageLock> acquire(
    DatabaseKeyVault vault,
    StorageGrant grant,
    void Function() check,
  ) async {
    check();
    final root = await vault.root();
    check();
    rejectStorageLink(root.path);
    final directory = Directory(
      '${root.path}/${storageScope(grant.projectId, grant.uid)}',
    );
    rejectStorageLink(directory.path);
    await directory.create(recursive: true);
    final canonical = directory.resolveSymbolicLinksSync();
    if (!_held.add(canonical)) {
      throw const StorageFailure(StorageFailureKind.busy);
    }
    RandomAccessFile? file;
    try {
      final path = '${directory.path}/.lock';
      rejectStorageLink(path);
      file = await File(path).open(mode: FileMode.append);
      await file.lock(FileLock.exclusive);
      check();
      return UserStorageLock._(directory, file, canonical);
    } catch (_) {
      await file?.close();
      _held.remove(canonical);
      rethrow;
    }
  }

  Future<void> release() async {
    if (_released) return;
    _released = true;
    try {
      await _file.unlock();
    } finally {
      try {
        await _file.close();
      } finally {
        _held.remove(_canonical);
      }
    }
  }
}
