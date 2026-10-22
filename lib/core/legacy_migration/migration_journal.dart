import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../user_storage/storage_access.dart';
import '../user_storage/user_storage_lock.dart';

enum MigrationFailureKind {
  source,
  ownership,
  conflicts,
  interrupted,
  destination,
  verification,
}

class LegacyMigrationFailure implements Exception {
  const LegacyMigrationFailure(this.kind);
  final MigrationFailureKind kind;
  @override
  String toString() => 'LegacyMigrationFailure(${kind.name})';
}

typedef MigrationSync = Future<void> Function(StorageGrant grant);

Future<void> nativeMigrationSync(StorageGrant grant) async {
  try {
    if (!Platform.isAndroid) throw const FormatException();
    final result =
        await const MethodChannel(
          'com.corehines.smartbudget/database_keys',
        ).invokeMethod<bool>('syncDirectory', {
          'projectId': grant.projectId,
          'uid': grant.uid,
        });
    if (result != true) throw const FormatException();
  } catch (_) {
    throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
  }
}

class MigrationJournal {
  static const name = '.legacy-migration.json';
  static const candidate = '.legacy-candidate.sqlite';
  static const previous = '.legacy-previous-empty.sqlite';
  static const phases = {
    'preparing',
    'verified',
    'activating',
    'active',
    'rolledBack',
  };
  static Map<String, dynamic>? read(Directory directory) {
    final path = '${directory.path}/$name';
    rejectStorageLink(path);
    rejectStorageLink('$path.next');
    // An interrupted first journal write must also block normal DB access.
    if (File('$path.next').existsSync()) {
      throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
    }
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      if (file.lengthSync() > 2048) throw const FormatException();
      final value = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      if ((value.keys.toList()..sort()).join(',') !=
              'databaseId,digest,phase,scope,sourceId,sourceVersion,version' ||
          value['version'] != 1 ||
          !{2, 3}.contains(value['sourceVersion']) ||
          !phases.contains(value['phase']) ||
          !RegExp(r'^[a-f0-9-]{36}$').hasMatch(value['databaseId'] as String) ||
          ['digest', 'scope', 'sourceId'].any(
            (k) => !RegExp(r'^[a-f0-9]{64}$').hasMatch(value[k] as String),
          )) {
        throw const FormatException();
      }
      return value;
    } catch (_) {
      throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
    }
  }

  static void requireNormalOpening(Directory directory) {
    try {
      final value = read(directory);
      final candidatePresent = File(
        '${directory.path}/$candidate',
      ).existsSync();
      final previousPresent = File('${directory.path}/$previous').existsSync();
      if (candidatePresent ||
          (value == null && previousPresent) ||
          (value?['phase'] == 'rolledBack' && previousPresent) ||
          (value?['phase'] == 'active' && !previousPresent)) {
        throw const FormatException();
      }
      if (value != null && !{'active', 'rolledBack'}.contains(value['phase'])) {
        throw const FormatException();
      }
    } catch (_) {
      throw const StorageFailure(StorageFailureKind.migrationPending);
    }
  }

  static Future<void> write(
    Directory directory,
    Map<String, dynamic> value,
    StorageGrant grant,
    MigrationSync sync,
  ) async {
    final path = '${directory.path}/$name';
    rejectStorageLink(path);
    rejectStorageLink('$path.next');
    final next = File('$path.next');
    if (next.existsSync()) {
      throw const LegacyMigrationFailure(MigrationFailureKind.interrupted);
    }
    await next.create(exclusive: true);
    await next.writeAsString(jsonEncode(value), flush: true);
    await sync(grant);
    await next.rename(path);
    await sync(grant);
  }
}
