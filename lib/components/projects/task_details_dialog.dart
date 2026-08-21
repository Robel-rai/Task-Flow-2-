import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/subtask.dart';
import '../../models/task.dart';
import '../../providers/tasks_provider.dart';
import '../../repositories/subtask_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Popup opened by double-clicking a kanban task card: shows the task's
/// title, description and subtasks. Subtask rows are checkable — toggling
/// goes through [TasksProvider] so the service can auto-complete the task
/// when all subtasks are done (and reopen it when one is un-checked); the
/// dialog reflects the updated status live.
class TaskDetailsDialog extends StatefulWidget {
  const TaskDetailsDialog({super.key, required this.task});

  final Task task;

  @override
  State<TaskDetailsDialog> createState() => _TaskDetailsDialogState();
}

class _TaskDetailsDialogState extends State<TaskDetailsDialog> {
  late Task _task = widget.task;
  List<Subtask>? _subtasks;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSubtasks();
  }

  Future<void> _loadSubtasks() async {
    final id = _task.id;
    if (id == null) {
      if (mounted) setState(() => _subtasks = const []);
      return;
    }
    setState(() => _loading = true);
    final list = await SubtaskRepository().getForTask(id);
    if (mounted) {
      setState(() {
        _subtasks = list;
        _loading = false;
      });
    }
  }

  /// Toggles a subtask; the service auto-completes (or reopens) the task,
  /// and the dialog updates its local task + subtask state to match.
  Future<void> _toggleSubtask(Subtask subtask) async {
    final id = subtask.id;
    final taskId = _task.id;
    if (id == null || taskId == null) return;
    final updated =
        await context.read<TasksProvider>().toggleSubtask(_task, id);
    if (!mounted) return;
    setState(() {
      _task = updated;
      _subtasks = _subtasks
          ?.map((s) =>
              s.id == id ? s.copyWith(isCompleted: !s.isCompleted) : s)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final subtasks = _subtasks;
    final done = subtasks?.where((s) => s.isCompleted).length ?? 0;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _task.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _statusChip(_task.status),
                ],
              ),
              if (_task.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _task.description,
                  style: TextStyle(
                      fontSize: 13, color: colors.textSecondary),
                ),
              ],
              const SizedBox(height: 16),
              Divider(height: 1, color: colors.border),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Subtasks',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  if (subtasks != null && subtasks.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$done/${subtasks.length} done',
                      style: TextStyle(
                          fontSize: 11, color: colors.textTertiary),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (subtasks == null || subtasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No subtasks',
                    style:
                        TextStyle(fontSize: 12, color: colors.textTertiary),
                  ),
                )
              else
                for (final s in subtasks) _subtaskRow(s, colors),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subtaskRow(Subtask subtask, AppThemeColors colors) {
    return InkWell(
      onTap: subtask.id == null ? null : () => _toggleSubtask(subtask),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              subtask.isCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              size: 18,
              color: subtask.isCompleted
                  ? AppTheme.emerald
                  : colors.textTertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subtask.title,
                style: TextStyle(
                  fontSize: 13,
                  color: subtask.isCompleted
                      ? colors.textTertiary
                      : colors.textPrimary,
                  decoration: subtask.isCompleted
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = AppTheme.getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
