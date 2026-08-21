import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/calendar/agenda_view.dart';
import '../components/calendar/calendar_header.dart';
import '../components/calendar/day_view.dart';
import '../components/calendar/month_view.dart';
import '../components/calendar/week_view.dart';
import '../models/task.dart';
import '../providers/calendar_provider.dart';
import '../providers/tasks_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/task_dialog.dart';

/// Calendar: month / week / day / agenda views with drag-to-reschedule,
/// per-day reorder, quick complete, and add-task-per-day.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  Future<void> _openDialog(
      BuildContext context, Task? task, DateTime? presetDate) async {
    final result = await showDialog<TaskDialogResult>(
      context: context,
      builder: (_) => TaskDialog(
        task: task ??
            Task(title: '', scheduledDate: presetDate),
      ),
    );
    if (result == null || !context.mounted) return;
    final tasks = context.read<TasksProvider>();
    if (task == null) {
      await tasks.createTask(result.task, subtasks: result.subtasks);
    } else {
      await tasks.updateTask(result.task, subtasks: result.subtasks);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CalendarProvider>();
    final isCollapsed = AppTheme.isScreenCollapsed(context);

    return Column(
      children: [
        CalendarHeader(
          provider: provider,
          onMenu: isCollapsed
              ? () => Scaffold.of(context).openDrawer()
              : null,
        ),
        Expanded(
          child: switch (provider.viewMode) {
            CalendarViewMode.month => MonthView(
                provider: provider,
                onReschedule: (task, date) => context
                    .read<TasksProvider>()
                    .rescheduleTask(task, date),
                onSelectDay: (date) {
                  provider.selectDate(date);
                  provider.setViewMode(CalendarViewMode.day);
                },
                onEditTask: (task) => _openDialog(context, task, null),
              ),
            CalendarViewMode.week => WeekView(
                provider: provider,
                onReschedule: (task, date) => context
                    .read<TasksProvider>()
                    .rescheduleTask(task, date),
                onEditTask: (task) => _openDialog(context, task, null),
              ),
            CalendarViewMode.day => DayView(
                date: provider.selectedDate,
                tasks: provider.selectedDayTasks,
                onReorder: (ids) =>
                    context.read<TasksProvider>().reorderTasks(ids),
                onToggleComplete: (task) {
                  final tasks = context.read<TasksProvider>();
                  if (task.status == 'Completed') {
                    tasks.reopenTask(task);
                  } else {
                    tasks.completeTask(task);
                  }
                },
                onEditTask: (task) => _openDialog(context, task, null),
                onAddTask: () =>
                    _openDialog(context, null, provider.selectedDate),
              ),
            CalendarViewMode.agenda => AgendaView(
                provider: provider,
                onEditTask: (task) => _openDialog(context, task, null),
              ),
          },
        ),
      ],
    );
  }
}
