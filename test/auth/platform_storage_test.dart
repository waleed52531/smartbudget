import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/features/auth/data/firebase_session_services.dart';

void main() {
  test(
    'authorization storage uses nonresetting AES KeyStore and separate project namespaces',
    () {
      final production = PlatformProtectedStore('smartbudget-561d4').storage;
      final emulator = PlatformProtectedStore('demo-smartbudget-authz').storage;
      final options = production.aOptions.toMap();
      expect(options['resetOnError'], 'false');
      expect(options['migrateOnAlgorithmChange'], 'false');
      expect(options['keyCipherAlgorithm'], 'AES_GCM_NoPadding');
      expect(options['storageCipherAlgorithm'], 'AES_GCM_NoPadding');
      expect(
        options['storageNamespace'],
        isNot(emulator.aOptions.toMap()['storageNamespace']),
      );
      expect(production.iOptions.toMap()['synchronizable'], 'false');
    },
  );
}
