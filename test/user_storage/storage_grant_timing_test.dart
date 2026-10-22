import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/user_storage/storage_access.dart';

void stall() {
  final elapsed = Stopwatch()..start();
  while (elapsed.elapsedMilliseconds < 2100) {
    // Deliberately model a cold synchronous callback or scheduling pause.
  }
}

void main() {
  test('a slow current-session callback cannot manufacture clock rollback', () {
    final grant = StorageGrant(
      projectId: 'native-test',
      uid: 'synthetic',
      trustedMs: 0,
      expiresAtMs: 60000,
      stillCurrent: () {
        stall();
        return true;
      },
    );
    expect(grant.valid, true);
  });
  test('expiry during a slow current-session callback still denies access', () {
    final grant = StorageGrant(
      projectId: 'native-test',
      uid: 'synthetic',
      trustedMs: 0,
      expiresAtMs: 100,
      stillCurrent: () {
        stall();
        return true;
      },
    );
    expect(grant.valid, false);
  });
}
