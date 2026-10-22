import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../domain/lease_verifier.dart';
import '../domain/session_contracts.dart';

class SessionVault {
  SessionVault(this.store);
  final ProtectedStore store;
  Future<void> _pending = Future<void>.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static const installationKey = 'auth.installation.v1';
  static const bindingKey = 'auth.binding.v1';
  String _entry(String uid) =>
      'auth.lease.v1.${base64Url.encode(utf8.encode(uid))}';

  Future<String> installation() => _serial(() async {
    final existing = await store.read(installationKey);
    if (existing != null) {
      if (!LeaseVerifier.installationPattern.hasMatch(existing)) {
        throw const SessionFailure(SessionFailureKind.storage);
      }
      return existing;
    }
    // This is an installation UUID, never a financial database encryption key.
    // A missing UUID makes every old grant unusable and requires online issuance.
    final value = const Uuid().v4();
    await store.write(installationKey, value);
    return value;
  });

  Future<CachedAuthorization?> cached(String uid) => _serial(() async {
    if (await store.read(bindingKey) != uid) return null;
    final value = await store.read(_entry(uid));
    return value == null ? null : CachedAuthorization.decode(value);
  });
  Future<void> save(
    String uid,
    CachedAuthorization authorization, {
    required bool Function() stillCurrent,
  }) => _serial(() async {
    if (!stillCurrent()) return;
    await store.write(_entry(uid), authorization.encode());
    if (!stillCurrent()) return;
    // Bind only after a complete, verified grant has been durably stored.
    await store.write(bindingKey, uid);
  });
  Future<void> lock() => _serial(() => store.write(bindingKey, ''));
  Future<void> invalidate(String uid) => _serial(() async {
    await store.write(bindingKey, '');
    await store.delete(_entry(uid));
  });
}
