import 'package:flutter/foundation.dart';

class SessionEnvironment {
  const SessionEnvironment({
    required this.emulator,
    required this.host,
    this.region = 'asia-south1',
    this.policyVersion = 1,
    this.workerOrigin,
  });
  factory SessionEnvironment.fromBuild() => SessionEnvironment.validated(
    emulator: const bool.fromEnvironment('SMARTBUDGET_USE_EMULATORS'),
    debugBuild: kDebugMode,
    host: const String.fromEnvironment(
      'SMARTBUDGET_EMULATOR_HOST',
      defaultValue: '10.0.2.2',
    ),
    region: const String.fromEnvironment(
      'SMARTBUDGET_AUTH_REGION',
      defaultValue: 'asia-south1',
    ),
    policyVersion: const int.fromEnvironment(
      'SMARTBUDGET_AUTH_POLICY',
      defaultValue: 1,
    ),
    workerOrigin: const String.fromEnvironment('SMARTBUDGET_AUTH_ORIGIN'),
  );
  factory SessionEnvironment.validated({
    required bool emulator,
    required bool debugBuild,
    required String host,
    String region = 'asia-south1',
    int policyVersion = 1,
    String workerOrigin = '',
  }) {
    final origin = workerOrigin.isEmpty ? null : Uri.tryParse(workerOrigin);
    if ((emulator &&
            (!debugBuild ||
                !{'10.0.2.2', '127.0.0.1', 'localhost'}.contains(host))) ||
        !RegExp(r'^[a-z]+-[a-z]+[1-9]$').hasMatch(region) ||
        policyVersion < 1 ||
        (workerOrigin.isNotEmpty &&
            (emulator ||
                origin == null ||
                origin.scheme != 'https' ||
                !RegExp(
                  r'^smartbudget-authorization\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.workers\.dev$',
                ).hasMatch(origin.host) ||
                origin.userInfo.isNotEmpty ||
                origin.hasPort ||
                (origin.path.isNotEmpty && origin.path != '/') ||
                origin.hasQuery ||
                origin.hasFragment))) {
      throw const FormatException('Invalid authorization environment.');
    }
    return SessionEnvironment(
      emulator: emulator,
      host: host,
      region: region,
      policyVersion: policyVersion,
      workerOrigin: origin,
    );
  }
  final bool emulator;
  final String host;
  final String region;
  final int policyVersion;
  final Uri? workerOrigin;
  String get projectId =>
      emulator ? 'demo-smartbudget-authz' : 'smartbudget-561d4';
  Uri get keysEndpoint => emulator
      ? Uri.parse('http://$host:5001/$projectId/$region/leaseVerificationKeys')
      : (workerOrigin ??
                (throw const FormatException(
                  'Authorization backend is not configured.',
                )))
            .resolve('/leaseVerificationKeys');
  Uri get authorizationEndpoint =>
      (workerOrigin ??
              (throw const FormatException(
                'Authorization backend is not configured.',
              )))
          .resolve('/authorizeSession');
}
