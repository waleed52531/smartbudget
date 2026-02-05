import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/category_repository.dart';
import '../../../core/db/app_db.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  bool includeArchived = false;

  Future<void> _addCategory() async {
    final name = await _nameDialog(title: 'Add Category');
    if (name == null) return;

    try {
      await context.read<CategoryRepository>().addCategory(name);
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }


  Future<void> _addSubcategory(String categoryId) async {
    final name = await _nameDialog(title: 'Add Subcategory');
    if (name == null || name.trim().isEmpty) return;
    await context.read<CategoryRepository>().addSubcategory(categoryId: categoryId, name: name);
    setState(() {});
  }

  Future<void> _rename(String id, String currentName) async {
    final name = await _nameDialog(title: 'Rename', initial: currentName);
    if (name == null || name.trim().isEmpty) return;
    await context.read<CategoryRepository>().renameNode(id, name);
    setState(() {});
  }

  Future<void> _archive(String id) async {
    await context.read<CategoryRepository>().archiveNode(id);
    setState(() {});
  }

  Future<String?> _nameDialog({required String title, String? initial}) async {
    final ctrl = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CategoryRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          Row(
            children: [
              const Text('Archived'),
              Switch(
                value: includeArchived,
                onChanged: (v) => setState(() => includeArchived = v),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<CategoryNode>>(
        future: repo.getAllCategories(includeArchived: includeArchived),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

          final cats = snap.data ?? [];
          if (cats.isEmpty) return const Center(child: Text('No categories'));

          return ListView.builder(
            itemCount: cats.length,
            itemBuilder: (_, i) {
              final c = cats[i];
              return ExpansionTile(
                title: Text(c.name),
                subtitle: c.archived ? const Text('Archived') : null,
                children: [
                  FutureBuilder<List<CategoryNode>>(
                    future: repo.getAllSubcategories(c.id, includeArchived: includeArchived),
                    builder: (context, subsSnap) {
                      if (subsSnap.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        );
                      }
                      final subs = subsSnap.data ?? [];
                      return Column(
                        children: [
                          for (final s in subs)
                            ListTile(
                              title: Text('• ${s.name}'),
                              subtitle: s.archived ? const Text('Archived') : null,
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'rename') await _rename(s.id, s.name);
                                  if (v == 'archive') await _archive(s.id);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                                ],
                              ),
                            ),
                          ListTile(
                            leading: const Icon(Icons.add),
                            title: const Text('Add subcategory'),
                            onTap: () => _addSubcategory(c.id),
                          ),
                        ],
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Rename category'),
                    onTap: () => _rename(c.id, c.name),
                  ),
                  ListTile(
                    leading: const Icon(Icons.archive_outlined),
                    title: const Text('Archive category'),
                    onTap: () => _archive(c.id),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
