import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../data/backup_repository.dart';
import 'bloc/backup_bloc.dart';
import 'bloc/backup_event.dart';
import 'bloc/backup_state.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  Future<File?> _pickJsonFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (res == null || res.files.isEmpty) return null;
    final path = res.files.single.path;
    if (path == null) return null;
    return File(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: BlocListener<BackupBloc, BackupState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.file != current.file ||
            current.toast != null,
        listener: (context, s) async {
          if (s.toast != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(s.toast!)));
            context.read<BackupBloc>().add(const ClearBackupToast());
          }

          if (s.status == BackupStatus.success && s.file != null) {
            // Share exported file automatically
            await SharePlus.instance.share(
              ShareParams(
                files: [XFile(s.file!.path)],
                text: 'Monthly Budget Backup',
              ),
            );
          }
        },
        child: BlocBuilder<BackupBloc, BackupState>(
          builder: (context, s) {
            final loading = s.status == BackupStatus.loading;

            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Export Backup',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Creates a JSON file with your data (transactions, budgets, categories, recurring).',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: loading
                                  ? null
                                  : () => context.read<BackupBloc>().add(
                                      const ExportBackupRequested(),
                                    ),
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Export & Share'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Restore Backup',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Merge adds missing records and keeps identical records. Conflicts require review.\nOverwrite replaces data after validating the complete backup.',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: loading
                                  ? null
                                  : () async {
                                      final file = await _pickJsonFile();
                                      if (file == null || !context.mounted) {
                                        return;
                                      }

                                      final mode = await showDialog<RestoreMode>(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: const Text('Restore mode'),
                                          content: const Text(
                                            'Merge: keeps existing data; conflicting records stop the restore.\n'
                                            'Overwrite: wipes DB then restores (danger).',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.pop(
                                                context,
                                                RestoreMode.merge,
                                              ),
                                              child: const Text('Merge'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(
                                                context,
                                                RestoreMode.overwrite,
                                              ),
                                              child: const Text('Overwrite'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (mode == null || !context.mounted) {
                                        return;
                                      }

                                      context.read<BackupBloc>().add(
                                        RestoreBackupRequested(
                                          file: file,
                                          mode: mode,
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.upload_outlined),
                              label: const Text('Pick JSON & Restore'),
                            ),
                          ),
                          if (s.status == BackupStatus.failure) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Error: ${s.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (loading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
