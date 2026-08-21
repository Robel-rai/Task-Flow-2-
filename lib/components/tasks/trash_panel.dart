import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/tasks_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Slide-in panel that shows trashed tasks with restore / permanent-delete
/// / empty-trash actions.  Rendered as an overlay inside the Tasks screen.
class TrashPanel extends StatefulWidget {
  const TrashPanel({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<TrashPanel> createState() => _TrashPanelState();
}

class _TrashPanelState extends State<TrashPanel> {
  List<Task> _trashed = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tasks = context.read<TasksProvider>();
    final items = await tasks.getTrashed();
    if (mounted) setState(() { _trashed = items; _loading = false; });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _restore(Task task) async {
    await context.read<TasksProvider>().restoreTask(task);
    _snack('"${task.title}" restored');
    await _load();
  }

  Future<void> _permanentDelete(Task task) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Delete Forever'),
        content: Text('Permanently delete "${task.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await context.read<TasksProvider>().permanentDelete(task.id!);
      _snack('"${task.title}" permanently deleted');
      await _load();
    }
  }

  Future<void> _emptyTrash() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    if (_trashed.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Empty Trash'),
        content: Text(
            'Permanently delete all ${_trashed.length} item${_trashed.length == 1 ? '' : 's'}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await context.read<TasksProvider>().emptyTrash();
      _snack('Trash emptied');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Material(
      color: colors.surface,
      child: Column(
        children: [
          // Header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.background.withValues(alpha: 0.5),
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back to tasks',
                  icon: Icon(Icons.arrow_back, color: colors.textSecondary),
                  onPressed: widget.onClose,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Trash',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        '${_trashed.length} item${_trashed.length == 1 ? '' : 's'}',
                        style: TextStyle(
                            fontSize: 12, color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (_trashed.isNotEmpty)
                  TextButton.icon(
                    onPressed: _emptyTrash,
                    icon: const Icon(Icons.delete_sweep_outlined,
                        size: 18, color: AppTheme.rose),
                    label: const Text('Empty Trash',
                        style: TextStyle(color: AppTheme.rose)),
                  ),
              ],
            ),
          ),

          // Body
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _trashed.isEmpty
                    ? _emptyState(colors)
                    : ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: _trashed.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final task = _trashed[index];
                          return _TrashRow(
                            task: task,
                            onRestore: () => _restore(task),
                            onDelete: () => _permanentDelete(task),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(AppThemeColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline,
              size: 64,
              color: colors.textTertiary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('Trash is empty',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textTertiary)),
          const SizedBox(height: 8),
          Text('Deleted tasks will appear here',
              style: TextStyle(fontSize: 13, color: colors.textTertiary)),
        ],
      ),
    );
  }
}

class _TrashRow extends StatelessWidget {
  const _TrashRow({
    required this.task,
    required this.onRestore,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.delete_outline, size: 18, color: colors.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                if (task.description.isNotEmpty)
                  Text(
                    task.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: colors.textTertiary),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Restore',
            icon: const Icon(Icons.restore_from_trash_outlined,
                color: AppTheme.emerald, size: 20),
            onPressed: onRestore,
          ),
          IconButton(
            tooltip: 'Delete forever',
            icon: const Icon(Icons.close, color: AppTheme.rose, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
