import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../auth/presentation/session_cubit.dart';
import '../../../core/db/app_db.dart';
import '../../../core/legacy_migration/legacy_migration_service.dart';
import '../../../core/legacy_migration/legacy_source.dart';
import '../../../core/legacy_migration/migration_journal.dart';
import '../../../core/legacy_migration/ownership_grant.dart';

class LegacyMigrationState {
  const LegacyMigrationState({this.busy = false, this.report, this.message});
  final bool busy;
  final MigrationReview? report;
  final String? message;
}

class LegacyMigrationCubit extends Cubit<LegacyMigrationState> {
  LegacyMigrationCubit(this.service) : super(const LegacyMigrationState());
  final LegacyMigrationService service;
  Future<void> execute(Future<MigrationReview?> Function() operation) async {
    if (state.busy) return;
    emit(const LegacyMigrationState(busy: true));
    try {
      final review = await operation();
      if (!isClosed) {
        emit(
          LegacyMigrationState(
            report: review,
            message: review == null
                ? 'Rollback completed; staging files were retained.'
                : null,
          ),
        );
      }
    } on DataIntegrityException catch (e) {
      if (!isClosed) emit(LegacyMigrationState(message: e.toString()));
    } on LegacyMigrationFailure catch (e) {
      if (!isClosed) {
        emit(
          LegacyMigrationState(
            message: switch (e.kind) {
              MigrationFailureKind.ownership =>
                'Ownership approval is missing, expired or does not match this user, backup and destination.',
              MigrationFailureKind.source =>
                'Use the complete verified SQLite snapshot and its matching SHA-256. A copied WAL-mode main file is insufficient.',
              MigrationFailureKind.destination =>
                'The destination already contains records. Nothing was overwritten.',
              MigrationFailureKind.conflicts =>
                'Conflicting data requires administrator review. No records were discarded.',
              MigrationFailureKind.interrupted =>
                'An interrupted migration was detected. Reprovide the same backup and approval to resume activation, or explicitly roll back staging.',
              MigrationFailureKind.verification =>
                'Migration verification failed. Files were retained; contact your administrator.',
            },
          ),
        );
      }
    } catch (_) {
      if (!isClosed) {
        emit(
          const LegacyMigrationState(
            message:
                'Migration is locked or unavailable. Verify your session before retrying.',
          ),
        );
      }
    }
  }
}

/// Administrator-assisted beta workflow. It never mounts financial providers or
/// reads a legacy source automatically. The paths are supplied by the operator;
/// no file picker creates an unencrypted cache copy of a financial database.
class LegacyMigrationPage extends StatelessWidget {
  const LegacyMigrationPage({
    super.key,
    required this.service,
    required this.uid,
  });
  final LegacyMigrationService service;
  final String uid;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LegacyMigrationCubit(service),
    child: _MigrationForm(uid: uid),
  );
}

class _MigrationForm extends StatefulWidget {
  const _MigrationForm({required this.uid});
  final String uid;
  @override
  State<_MigrationForm> createState() => _MigrationFormState();
}

class _MigrationFormState extends State<_MigrationForm> {
  final path = TextEditingController(),
      checksum = TextEditingController(),
      approval = TextEditingController();
  bool confirmed = false;
  @override
  void dispose() {
    path.dispose();
    checksum.dispose();
    approval.dispose();
    super.dispose();
  }

  LegacySource get source => LegacySource(
    File(path.text.trim()),
    mainSha256: checksum.text.trim().toLowerCase(),
  );
  LegacyOwnershipConsent consent(LegacySource s) => LegacyOwnershipConsent(
    uid: widget.uid,
    sourceId: s.sourceId,
    confirmedBelongsToMe: confirmed,
  );
  Future<String> grant() async {
    final file = File(approval.text.trim());
    if (await file.length() > 8192) throw const FormatException();
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    if (json.keys.length != 1 || json['grant'] is! String) {
      throw const FormatException();
    }
    return json['grant'];
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<SessionCubit, SessionState>(
    builder: (context, session) {
      if (session.status != SessionStatus.authorized ||
          session.identity?.uid != widget.uid) {
        return Scaffold(
          appBar: AppBar(title: const Text('Legacy migration')),
          body: const Center(
            child: Text('Migration locked. Return and verify your session.'),
          ),
        );
      }
      return BlocBuilder<LegacyMigrationCubit, LegacyMigrationState>(
        builder: (context, state) {
          final cubit = context.read<LegacyMigrationCubit>();
          final canRun =
              !state.busy &&
              confirmed &&
              path.text.trim().isNotEmpty &&
              RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(checksum.text.trim());
          final approved = canRun && approval.text.trim().isNotEmpty;
          return Scaffold(
            appBar: AppBar(title: const Text('Legacy migration')),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Administrator-assisted import of a verified standalone SQLite backup. The original backup is retained. Your budgeting workspace remains locked.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Signed-in account: ${session.identity?.email ?? widget.uid}',
                ),
                TextField(
                  controller: path,
                  enabled: !state.busy,
                  decoration: const InputDecoration(
                    labelText: 'Verified backup file path',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: checksum,
                  enabled: !state.busy,
                  decoration: const InputDecoration(
                    labelText: 'Backup SHA-256 from its verified manifest',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: approval,
                  enabled: !state.busy,
                  decoration: const InputDecoration(
                    labelText: 'Administrator ownership-grant file path',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                CheckboxListTile(
                  value: confirmed,
                  onChanged: state.busy
                      ? null
                      : (v) => setState(() => confirmed = v ?? false),
                  title: const Text(
                    'I explicitly confirm this legacy data belongs to my currently signed-in account.',
                  ),
                ),
                if (state.busy) const LinearProgressIndicator(),
                if (state.message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(state.message!),
                  ),
                if (state.report case final report?) ...[
                  const SizedBox(height: 16),
                  Text('Status: ${report.phase}'),
                  SelectableText('Source fingerprint: ${report.sourceId}'),
                  SelectableText('Destination ID: ${report.databaseId}'),
                  Text(
                    'Source schema: ${report.sourceVersion}; destination schema: 4',
                  ),
                  for (final e in report.counts.entries)
                    Text('${e.key}: ${e.value} records'),
                  for (final e in report.totals.entries)
                    Text('${e.key}: ${e.value} minor units'),
                ],
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: canRun
                      ? () => cubit.execute(() {
                          final s = source;
                          return cubit.service.review(s, consent(s));
                        })
                      : null,
                  child: const Text('Review backup only'),
                ),
                FilledButton(
                  onPressed: approved
                      ? () => cubit.execute(() async {
                          final s = source;
                          return cubit.service.prepare(
                            source: s,
                            consent: consent(s),
                            administratorGrant: await grant(),
                          );
                        })
                      : null,
                  child: const Text('Prepare encrypted copy'),
                ),
                OutlinedButton(
                  onPressed: approved
                      ? () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Activate this migration?'),
                              content: const Text(
                                'Only an empty, verified destination can be replaced. The backup and previous empty database will be retained. This does not unlock the budgeting dashboard.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Activate / resume'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true && mounted) {
                            await cubit.execute(() async {
                              final s = source;
                              return cubit.service.activate(
                                source: s,
                                consent: consent(s),
                                administratorGrant: await grant(),
                              );
                            });
                          }
                        }
                      : null,
                  child: const Text('Activate / resume verified migration'),
                ),
                TextButton(
                  onPressed: state.busy
                      ? null
                      : () async {
                          final yes = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Roll back staging?'),
                              content: const Text(
                                'Staged files will be retained for recovery. An active migration cannot be rolled back automatically.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Roll back'),
                                ),
                              ],
                            ),
                          );
                          if (yes == true && mounted) {
                            await cubit.execute(() async {
                              await cubit.service.rollback();
                              return null;
                            });
                          }
                        },
                  child: const Text('Roll back incomplete staging'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
