import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartbudget/core/app_shell.dart';
import 'package:smartbudget/features/auth/presentation/session_app.dart';
import 'support.dart';

void main() {
  testWidgets(
    'login validates input, obscures passwords and presents reset success',
    (tester) async {
      final h = Harness();
      await tester.pumpWidget(AuthSessionApp(createSession: h.create));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(h.auth.logins, 0);
      final fields = tester
          .widgetList<TextField>(find.byType(TextField))
          .toList();
      expect(fields.last.obscureText, true);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'synthetic@example.test',
      );
      await tester.tap(find.text('Send reset instructions'));
      await tester.pumpAndSettle();
      expect(h.auth.resets, 1);
      expect(
        find.textContaining('If this account is eligible'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'authenticated user stays loading until backend grants access, then only sees temporary screen',
    (tester) async {
      final h = Harness(initial: alice);
      h.gateway.pending = Completer();
      await tester.pumpWidget(AuthSessionApp(createSession: h.create));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('Verifying your session…'), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      h.gateway.pending!.complete(fixtureBundle());
      await tester.pumpAndSettle();
      expect(find.text('Your session is authorized'), findsOneWidget);
      expect(
        find.textContaining('financial workspace is locked'),
        findsOneWidget,
      );
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'active authorization is locked at expiry without a network fallback',
    (tester) async {
      final h = Harness(initial: alice);
      await tester.pumpWidget(AuthSessionApp(createSession: h.create));
      await tester.pumpAndSettle();
      expect(find.text('Your session is authorized'), findsOneWidget);
      h.clock.advance(86400000);
      await tester.pump(const Duration(hours: 24));
      await tester.pumpAndSettle();
      expect(find.text('Session locked'), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test('production entry point has no financial bootstrap dependency', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source, isNot(contains('AppDatabase')));
    expect(source, isNot(contains('financial_app.dart')));
    expect(source, isNot(contains('seedDefaults')));
    expect(source, contains('AuthSessionApp'));
  });
}
