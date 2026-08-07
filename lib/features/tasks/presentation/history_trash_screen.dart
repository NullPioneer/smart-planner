import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:smart_reminder/core/providers/app_providers.dart';

class HistoryTrashScreen extends ConsumerWidget {
  const HistoryTrashScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('History & Trash'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'History', icon: Icon(Icons.history)),
            Tab(text: 'Trash', icon: Icon(Icons.delete_outline)),
          ],
        ),
      ),
      body: TabBarView(children: [_history(ref), _trash(context, ref)]),
    ),
  );

  Widget _history(WidgetRef ref) => ref
      .watch(taskHistoryProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No history yet.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return ListTile(
                    leading: Icon(_icon(item.action)),
                    title: Text(_label(item.action)),
                    subtitle: Text(
                      DateFormat('d MMM y • h:mm a').format(item.createdAt),
                    ),
                  );
                },
              ),
      );

  Widget _trash(BuildContext context, WidgetRef ref) => ref
      .watch(trashTasksProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (tasks) {
          if (tasks.isEmpty)
            return const Center(
              child: Text(
                'Trash is empty. Deleted tasks are kept for 30 days.',
              ),
            );
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (_, i) {
              final task = tasks[i];
              return Card(
                child: ListTile(
                  title: Text(task.title),
                  subtitle: Text(
                    'Deleted ${DateFormat('d MMM y').format(task.deletedAt!)}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'restore') {
                        await ref
                            .read(taskRepositoryProvider)
                            .restoreFromTrash(task.id);
                        await ref
                            .read(taskNotificationCoordinatorProvider)
                            .syncTask(task.id);
                        return;
                      }
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Delete permanently?'),
                          content: const Text('This cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (yes == true)
                        await ref
                            .read(taskRepositoryProvider)
                            .permanentlyDelete(task.id);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'restore', child: Text('Restore')),
                      PopupMenuItem(
                        value: 'permanent',
                        child: Text('Delete permanently'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
  IconData _icon(String action) => switch (action) {
    'completed' => Icons.check_circle,
    'deleted' => Icons.delete_outline,
    'restored' => Icons.restore,
    'edited' => Icons.edit,
    _ => Icons.add_circle_outline,
  };
  String _label(String action) => action
      .split('_')
      .map((s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1))
      .join(' ');
}
