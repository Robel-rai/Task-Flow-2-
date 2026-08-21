import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Compact list showing the last 5 recently created or updated tasks
/// with relative timestamps.
class RecentActivity extends StatelessWidget {
  const RecentActivity({super.key, required this.tasks});

  final List<Task> tasks;

  String _relativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, size: 18, color: AppTheme.sky),
              const SizedBox(width: 8),
              Text('Recent Activity',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Last ${tasks.length} tasks',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: colors.textTertiary),
                ),
              ),
            )
          else
            for (var i = 0; i < tasks.length; i++) ...[
              _ActivityRow(
                task: tasks[i],
                relativeTime: _relativeTime(tasks[i].updatedAt ?? tasks[i].createdAt),
                colors: colors,
              ),
              if (i < tasks.length - 1)
                Divider(height: 1, color: colors.border.withValues(alpha: 0.5)),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.task,
    required this.relativeTime,
    required this.colors,
  });

  final Task task;
  final String relativeTime;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == 'Completed';
    final icon = isCompleted ? Icons.check_circle : Icons.add_circle_outline;
    final iconColor = isCompleted ? AppTheme.emerald : AppTheme.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  task.status,
                  style: TextStyle(fontSize: 10, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            relativeTime,
            style: TextStyle(fontSize: 10, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}
