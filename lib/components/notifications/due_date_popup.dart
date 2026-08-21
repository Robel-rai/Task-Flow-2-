import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_navigator.dart';
import '../../models/task.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// In-app popup dialog shown when one or more tasks are past their due date.
///
/// Displays each overdue task with its title, due date, priority indicator,
/// and action buttons (dismiss / mark complete / start focus).
class DueDatePopup extends StatelessWidget {
  const DueDatePopup({super.key, required this.tasks});

  final List<Task> tasks;

  /// Shows the due-date popup as a modal dialog. Returns when dismissed.
  static Future<void> show(BuildContext context, List<Task> tasks) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Due date alert',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),          pageBuilder: (_, __, ___) => DueDatePopup(tasks: tasks),
          transitionBuilder: (_, anim, __, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppTheme.rose.withValues(alpha: 0.4), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              decoration: BoxDecoration(
                color: AppTheme.rose.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.rose.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notification_important_outlined,
                      color: AppTheme.rose,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Task${tasks.length == 1 ? '' : 's'} Due',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tasks.length} task${tasks.length == 1 ? '' : 's'} past their due date',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Task list ──
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final categoryList =
                      context.read<SettingsProvider>().categoryList;
                  final category = task.categoryId != null
                      ? categoryList
                          .where((c) => c.id == task.categoryId)
                          .firstOrNull
                      : null;
                  final categoryColor = category != null
                      ? AppTheme.getRoutineColor(category.color)
                      : AppTheme.primary;
                  final priorityColor =
                      AppTheme.getPriorityColor(task.priority);

                  return Container(
                    decoration: BoxDecoration(
                      color: colors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        // Color strip (category)
                        Container(
                          width: 4,
                          height: 56,
                          decoration: BoxDecoration(
                            color: categoryColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Priority indicator dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Task info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                task.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _dueLabel(task),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.rose,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        IconButton(
                          tooltip: 'Mark complete',
                          icon: const Icon(Icons.check_circle_outline,
                              size: 20, color: AppTheme.emerald),
                          onPressed: () {
                            Navigator.of(context).pop({'action': 'complete', 'task': task});
                          },
                        ),
                        IconButton(
                          tooltip: 'Dismiss',
                          icon: Icon(Icons.close,
                              size: 18, color: colors.textTertiary),
                          onPressed: () {
                            Navigator.of(context).pop({'action': 'dismiss', 'task': task});
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Footer ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      // Navigate to Tasks screen
                      Navigator.of(context).pop();
                      AppNavigator.instance.goTo(1); // Tasks = index 1
                    },
                    child: const Text('View All Tasks'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.rose,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Dismiss All'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dueLabel(Task task) {
    final now = DateTime.now();
    final due = task.dueDate!;
    final diff = due.difference(now);
    if (diff.isNegative) {
      final absDiff = diff.abs();
      if (absDiff.inDays > 0) return '${absDiff.inDays} day${absDiff.inDays == 1 ? '' : 's'} overdue';
      if (absDiff.inHours > 0) return '${absDiff.inHours} hour${absDiff.inHours == 1 ? '' : 's'} overdue';
      return '${absDiff.inMinutes} min overdue';
    }
    return 'Due now';
  }
}
