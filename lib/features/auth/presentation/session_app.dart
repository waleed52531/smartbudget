import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'session_cubit.dart';
import '../../../core/legacy_migration/legacy_migration_service.dart';
import '../../legacy_migration/presentation/legacy_migration_page.dart';

class AuthSessionApp extends StatelessWidget {
  const AuthSessionApp({
    super.key,
    required this.createSession,
    this.createLegacyMigration,
  });
  final SessionCubit Function() createSession;
  final LegacyMigrationService Function()? createLegacyMigration;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createSession(),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff225c46)),
      ),
      home: _SessionScreen(createLegacyMigration: createLegacyMigration),
    ),
  );
}

class SessionUnavailableApp extends StatelessWidget {
  const SessionUnavailableApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Smart Budget could not start securely. Check the app configuration and restart.',
            ),
          ),
        ),
      ),
    ),
  );
}

class _SessionScreen extends StatefulWidget {
  const _SessionScreen({this.createLegacyMigration});
  final LegacyMigrationService Function()? createLegacyMigration;
  @override
  State<_SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<_SessionScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final session = context.read<SessionCubit>();
    if (state == AppLifecycleState.resumed) {
      unawaited(session.resume());
    } else {
      session.background();
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<SessionCubit, SessionState>(
    builder: (context, state) {
      final session = context.read<SessionCubit>();
      return Scaffold(
        appBar: AppBar(title: const Text('Smart Budget')),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: switch (state.status) {
                  SessionStatus.signedOut => _SignInPanel(state: state),
                  SessionStatus.restoring ||
                  SessionStatus.authorizing => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('Verifying your session…'),
                    ],
                  ),
                  SessionStatus.authorized => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_outlined, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Your session is authorized',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(state.identity?.email ?? 'Signed-in account'),
                      const SizedBox(height: 12),
                      Chip(
                        label: Text(
                          state.offline
                              ? 'Offline authorization'
                              : 'Verified online',
                        ),
                      ),
                      if (state.expiresAt != null)
                        Text(
                          'Valid until ${DateFormat.yMMMd().add_jm().format(DateTime.fromMillisecondsSinceEpoch(state.expiresAt! * 1000))}',
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 24),
                      const Text(
                        'Your financial workspace is locked while secure account storage is prepared.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: session.refresh,
                        child: const Text('Verify access'),
                      ),
                      if (widget.createLegacyMigration != null)
                        TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => LegacyMigrationPage(
                                service: widget.createLegacyMigration!(),
                                uid: state.identity!.uid,
                              ),
                            ),
                          ),
                          child: const Text('Legacy migration'),
                        ),
                      TextButton(
                        onPressed: session.signOut,
                        child: const Text('Sign out'),
                      ),
                      TextButton(
                        onPressed: session.signOut,
                        child: const Text('Use another account'),
                      ),
                    ],
                  ),
                  SessionStatus.locked => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Session locked',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message ?? 'Connect to verify access.',
                        textAlign: TextAlign.center,
                      ),
                      if (state.identity?.email != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(state.identity!.email!),
                        ),
                      const SizedBox(height: 24),
                      if (state.busy)
                        const CircularProgressIndicator()
                      else ...[
                        if (state.identity != null)
                          FilledButton(
                            onPressed: session.refresh,
                            child: const Text('Verify access'),
                          ),
                        TextButton(
                          onPressed: session.signOut,
                          child: const Text('Sign out / use another account'),
                        ),
                      ],
                    ],
                  ),
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SignInPanel extends StatefulWidget {
  const _SignInPanel({required this.state});
  final SessionState state;
  @override
  State<_SignInPanel> createState() => _SignInPanelState();
}

class _SignInPanelState extends State<_SignInPanel> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  bool _reset = false, _obscured = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.state.busy || !_form.currentState!.validate()) return;
    final session = context.read<SessionCubit>();
    if (_reset) {
      await session.resetPassword(_email.text.trim());
    } else {
      final password = _password.text;
      _password.clear();
      await session.signIn(_email.text.trim(), password);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _reset ? 'Reset your password' : 'Welcome back',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _reset
                ? 'Enter the email address for your account.'
                : 'Sign in with your invited beta account.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _email,
            enabled: !widget.state.busy,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: _reset
                ? TextInputAction.done
                : TextInputAction.next,
            onFieldSubmitted: (_) {
              if (_reset) unawaited(_submit());
            },
            validator: (value) =>
                value != null &&
                    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())
                ? null
                : 'Enter a valid email address.',
          ),
          if (!_reset) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              enabled: !widget.state.busy,
              obscureText: _obscured,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.password],
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => unawaited(_submit()),
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscured ? 'Show password' : 'Hide password',
                  onPressed: widget.state.busy
                      ? null
                      : () => setState(() => _obscured = !_obscured),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) => value == null || value.isEmpty
                  ? 'Enter your password.'
                  : null,
            ),
          ],
          if (widget.state.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(widget.state.message!),
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.state.busy ? null : _submit,
            child: widget.state.busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_reset ? 'Send reset instructions' : 'Sign in'),
          ),
          TextButton(
            onPressed: widget.state.busy
                ? null
                : () => setState(() {
                    _reset = !_reset;
                    _password.clear();
                  }),
            child: Text(_reset ? 'Back to sign in' : 'Forgot password?'),
          ),
        ],
      ),
    ),
  );
}
