import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/user_storage/database_key_vault.dart';
import 'package:smartbudget/core/user_storage/storage_access.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(
      AndroidDatabaseKeyVault.channel,
      null,
    ),
  );
  test(
    'platform-owned read-only keys are copied before use and safe erasure',
    () {
      final source = Uint8List.fromList(
        List.filled(32, 42),
      ).asUnmodifiableView();
      final key = DatabaseKey(source, 'f2a8a07a-8660-4a9b-9e20-c841f5ddcb29');
      key.bytes[0] = 9;
      expect(source[0], 42);
      key.erase();
      expect(key.bytes.every((byte) => byte == 0), true);
      expect(source[0], 42);
    },
  );
  test(
    'Android channel transports binary keys bound to project/UID and clears local copies',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(AndroidDatabaseKeyVault.channel, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'root') {
          return '/disposable/no_backup/user_storage_v1';
        }
        if (call.method == 'contains') return true;
        return {
          'key': Uint8List.fromList(List.filled(32, 7)),
          'databaseId': 'f2a8a07a-8660-4a9b-9e20-c841f5ddcb29',
        };
      });
      final vault = AndroidDatabaseKeyVault();
      expect((await vault.root()).path, contains('no_backup'));
      expect(await vault.contains('smartbudget-test', 'a'), true);
      final key = await vault.load('smartbudget-test', 'a');
      expect(key.bytes.length, 32);
      key.erase();
      expect(key.bytes.every((b) => b == 0), true);
      expect(calls.last.arguments, {
        'projectId': 'smartbudget-test',
        'uid': 'a',
      });
    },
  );
  test(
    'Apple key options are device-only, unlocked, non-syncing and separate from auth',
    () {
      for (final options in [
        AppleDatabaseKeyVault.iosOptions.toMap(),
        AppleDatabaseKeyVault.macosOptions.toMap(),
      ]) {
        expect(options['accessibility'], 'unlocked_this_device');
        expect(options['synchronizable'], 'false');
        expect(options['accountName'], 'smartbudget.database.keys.v1');
      }
    },
  );
  for (final fault in [
    'missing',
    'invalidated',
    'corrupt',
    'invalid-response',
  ]) {
    test(
      'Android $fault error cannot leak native details or create a replacement',
      () async {
        final methods = <String>[];
        messenger.setMockMethodCallHandler(AndroidDatabaseKeyVault.channel, (
          call,
        ) async {
          methods.add(call.method);
          if (fault == 'invalid-response') {
            return {'key': Uint8List(0), 'databaseId': 'invalid'};
          }
          throw PlatformException(
            code: fault,
            message: 'Synthetic provider details must not escape',
          );
        });
        final vault = AndroidDatabaseKeyVault();
        try {
          await vault.load('smartbudget-test', 'a');
          fail('Should reject');
        } on StorageFailure catch (error) {
          expect(error.kind, StorageFailureKind.keyUnavailable);
          expect(error.toString(), isNot(contains('provider details')));
        }
        expect(methods, ['load']);
      },
    );
  }
}
