import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/features/auth/data/session_vault.dart';
import 'package:smartbudget/features/auth/domain/session_contracts.dart';
import 'package:smartbudget/features/auth/presentation/session_cubit.dart';
import 'support.dart';

void main() {
  test(
    'successful login requires backend authorization before access',
    () async {
      final h = Harness();
      final cubit = h.create();
      addTearDown(cubit.close);
      await waitFor(() => cubit.state.status == SessionStatus.signedOut);
      h.gateway.pending = Completer<AuthorizationBundle>();
      final signingIn = cubit.signIn(
        'synthetic@example.test',
        'synthetic-password',
      );
      await waitFor(() => h.gateway.calls == 1);
      expect(cubit.state.status, SessionStatus.authorizing);
      h.gateway.pending!.complete(fixtureBundle());
      await signingIn;
      await waitFor(() => cubit.state.status == SessionStatus.authorized);
      expect(cubit.state.offline, false);
    },
  );
  test(
    'failed login and failed/successful password reset expose sanitized states',
    () async {
      final h = Harness();
      final c = h.create();
      addTearDown(c.close);
      await waitFor(() => c.state.status == SessionStatus.signedOut);
      h.auth.failLogin = true;
      await c.signIn('synthetic@example.test', 'synthetic-password');
      expect(c.state.status, SessionStatus.signedOut);
      expect(c.state.message, contains('Sign in failed'));
      await c.resetPassword('synthetic@example.test');
      expect(h.auth.resets, 1);
      expect(c.state.message, contains('If this account'));
      h.auth.failReset = true;
      await c.resetPassword('synthetic@example.test');
      expect(c.state.message, contains('could not be completed'));
    },
  );
  test(
    'a new login cannot use old cache when backend is unavailable',
    () async {
      final h = Harness(), c = h.create();
      addTearDown(c.close);
      await waitFor(() => c.state.status == SessionStatus.signedOut);
      h.gateway.failure = SessionFailureKind.unavailable;
      await c.signIn('synthetic@example.test', 'synthetic-password');
      await waitFor(() => c.state.status == SessionStatus.locked);
      expect(c.state.message, contains('No valid offline'));
    },
  );
  test(
    'restored identity can use its verified lease offline after application restart',
    () async {
      final h = Harness(initial: alice);
      final first = h.create();
      await waitFor(() => first.state.status == SessionStatus.authorized);
      await first.close();
      h.clock.advance(60000);
      h.gateway.failure = SessionFailureKind.unavailable;
      final restored = h.create();
      addTearDown(restored.close);
      await waitFor(() => restored.state.status == SessionStatus.authorized);
      expect(restored.state.offline, true);
    },
  );
  for (final scenario in [
    'expired',
    'rollback',
    'reboot',
    'wrong-user',
    'revoked',
    'bad-signature',
  ]) {
    test(
      '$scenario cannot restore or renew authorization from cached data',
      () async {
        final h = Harness(initial: alice);
        final first = h.create();
        await waitFor(() => first.state.status == SessionStatus.authorized);
        await first.close();
        h.gateway.failure = SessionFailureKind.unavailable;
        switch (scenario) {
          case 'expired':
            h.clock.advance(86400000);
          case 'rollback':
            h.clock.advance(10000);
            h.clock.wall -= 20000;
          case 'reboot':
            h.clock.boot = 'boot-two';
            h.clock.elapsed = 1;
          case 'wrong-user':
            await h.auth.signIn('second@example.test', 'synthetic-password');
          case 'revoked':
            h.gateway.failure = SessionFailureKind.denied;
          case 'bad-signature':
            final key = h.store.values.keys.firstWhere(
              (key) => key.startsWith('auth.lease.'),
            );
            h.store.values[key] = h.store.values[key]!.replaceFirst(
              fixtureBundle().lease,
              '${fixtureBundle().lease}!',
            );
        }
        final restored = h.create();
        addTearDown(restored.close);
        await waitFor(() => restored.state.status == SessionStatus.locked);
      },
    );
  }
  test(
    'logout clears grant binding and account switching requires a separate valid lease',
    () async {
      final h = Harness(initial: alice), c = h.create();
      addTearDown(c.close);
      await waitFor(() => c.state.status == SessionStatus.authorized);
      await c.signOut();
      expect(c.state.status, SessionStatus.signedOut);
      expect(h.store.values[SessionVault.bindingKey], '');
      expect(
        h.store.values.keys.where((key) => key.startsWith('auth.lease.')),
        isEmpty,
      );
      await c.signIn('second@example.test', 'synthetic-password');
      await waitFor(() => c.state.status == SessionStatus.authorized);
      expect(c.state.identity?.uid, bob.uid);
      expect(h.store.values[SessionVault.bindingKey], bob.uid);
    },
  );
  test('logout wins over a late backend response', () async {
    final h = Harness(initial: alice);
    h.gateway.pending = Completer<AuthorizationBundle>();
    final c = h.create();
    addTearDown(c.close);
    await waitFor(() => h.gateway.calls == 1);
    await c.signOut();
    h.gateway.pending!.complete(fixtureBundle());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.state.status, SessionStatus.signedOut);
    expect(h.store.values[SessionVault.bindingKey], '');
  });
  test(
    'an invalid online lease cannot fall back to an older valid grant',
    () async {
      final h = Harness(initial: alice), c = h.create();
      addTearDown(c.close);
      await waitFor(() => c.state.status == SessionStatus.authorized);
      h.gateway.overrideBundle = AuthorizationBundle(
        '${fixtureBundle().lease}!',
        fixtureBundle().keys,
      );
      await c.refresh();
      expect(c.state.status, SessionStatus.locked);
      expect(h.store.values[SessionVault.bindingKey], '');
      h.gateway.failure = SessionFailureKind.unavailable;
      await c.refresh();
      expect(c.state.status, SessionStatus.locked);
    },
  );
  test(
    'authentication stream errors require fresh online authorization',
    () async {
      final h = Harness(initial: alice), c = h.create();
      addTearDown(c.close);
      await waitFor(() => c.state.status == SessionStatus.authorized);
      h.auth.events.addError(StateError('synthetic authentication error'));
      await waitFor(() => c.state.status == SessionStatus.locked);
      h.gateway.failure = SessionFailureKind.unavailable;
      await c.refresh();
      expect(c.state.status, SessionStatus.locked);
    },
  );
  test(
    'logout also cancels the effect of an in-flight Firebase sign-in',
    () async {
      final h = Harness();
      h.auth.pendingLogin = Completer<void>();
      final c = h.create();
      addTearDown(c.close);
      await waitFor(() => c.state.status == SessionStatus.signedOut);
      final signingIn = c.signIn(
        'synthetic@example.test',
        'synthetic-password',
      );
      await waitFor(() => h.auth.logins == 1);
      await c.signOut();
      expect(c.state.busy, true);
      h.auth.pendingLogin!.complete();
      await signingIn;
      await waitFor(
        () => c.state.status == SessionStatus.signedOut && !c.state.busy,
      );
      expect(h.auth.current, isNull);
      expect(h.gateway.calls, 0);
      expect(h.store.values[SessionVault.bindingKey], '');
    },
  );
  test('logout wins while grant persistence is in flight', () async {
    final h = Harness(initial: alice);
    h.store.delayedWrite = Completer<void>();
    final c = h.create();
    addTearDown(c.close);
    await waitFor(() => h.store.writeWaiting);
    final signingOut = c.signOut();
    h.store.delayedWrite!.complete();
    await signingOut;
    expect(c.state.status, SessionStatus.signedOut);
    expect(h.store.values[SessionVault.bindingKey], '');
    expect(
      h.store.values.keys.where((key) => key.startsWith('auth.lease.')),
      isEmpty,
    );
  });
  test(
    'slow persistence never extends a lease past its signed expiry',
    () async {
      final h = Harness(initial: alice);
      h.store.delayedWrite = Completer<void>();
      final c = h.create();
      addTearDown(c.close);
      await waitFor(() => h.store.writeWaiting);
      h.clock.advance(86400000);
      h.store.delayedWrite!.complete();
      await waitFor(() => c.state.status == SessionStatus.locked);
      expect(h.store.values[SessionVault.bindingKey], '');
    },
  );
  test('storage and logout failures leave the application locked', () async {
    final h = Harness(initial: alice), c = h.create();
    addTearDown(c.close);
    await waitFor(() => c.state.status == SessionStatus.authorized);
    h.store.fail = true;
    h.auth.failLogout = true;
    await c.signOut();
    expect(c.state.status, SessionStatus.locked);
    expect(c.state.message, contains('securely'));
    h.store.fail = false;
    h.auth.failLogout = false;
    await c.signOut();
    expect(c.state.status, SessionStatus.signedOut);
  });
}
