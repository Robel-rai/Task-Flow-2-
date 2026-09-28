import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_navigator.dart';
import '../providers/focus_provider.dart';
import '../providers/tasks_provider.dart';
import '../theme/app_colors.dart';

/// FocusScreen position in `AppShell._screens`
/// (0 Dashboard, 1 Tasks, 2 Calendar, 3 Projects, 4 Focus, ...).
const int _focusPageIndex = 4;

/// Handles the play/stop button on a task card.
///
/// - No session active → start a focus session on [taskId] (which also
///   starts the task's own timer) and switch the shell to the Focus page.
/// - Session active on [taskId] → stop it (banks its time into the task);
///   no page switch.
/// - Session active on *another* task → warn first and let the user either
///   keep the current session or switch to this task.
Future<void> toggleFocusFromTask(
  BuildContext context, {
  required int? taskId,
  required String taskTitle,
}) async {
  final focus = context.read<FocusProvider>();
  final active = focus.activeSession;

  // Stop the session already running on this task.
  if (active != null && active.taskId == taskId) {
    await focus.stop();
    return;
  }

  // Another task's session is running — ask before switching.
  if (active != null && active.taskId != taskId) {
    final otherTitle = _taskTitleFor(context, active.taskId);
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final switchTo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Focus session already running'),
        content: Text(
          'A focus session on "${otherTitle ?? 'another task'}" is still '
          'running.\n\nSwitch to "$taskTitle"? The current session will '
          'be stopped and its time recorded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep it running',
                style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (switchTo != true || !context.mounted) return;
    await focus.stop();
    if (!context.mounted) return;
  }

  await focus.start(taskId: taskId);
  if (!context.mounted) return;
  AppNavigator.instance.goTo(_focusPageIndex);
}

String? _taskTitleFor(BuildContext context, int? taskId) {
  if (taskId == null) return null;
  for (final task in context.read<TasksProvider>().tasks) {
    if (task.id == taskId) return task.title;
  }
  return null;
}
