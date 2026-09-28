import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/focus_session.dart';
import '../../models/task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/focus_timer.dart' show formatFocusDuration;

/// Focus sessions for a date range: total time, a per-task breakdown,
/// and the individual session list. When [rangeStart]/[rangeEnd] are
/// null, every session is included.
class SessionLog extends StatelessWidget {
  const SessionLog({
    super.key,
    required this.sessions,
    required this.tasks,
    this.rangeStart,
    this.rangeEnd,
  });

  final List<FocusSession> sessions;
  final List<Task> tasks;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  String _taskTitle(int? taskId) {
    if (taskId == null) return 'Unfocused';
    for (final task in tasks) {
      if (task.id == taskId) return task.title;
    }
    return 'Deleted task';
  }

  int get _totalSeconds {
    var total = 0;
    for (final session in sessions) {
      total += session.currentDurationSeconds;
    }
    return total;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isTodayOnly =>
      rangeStart != null &&
      rangeEnd != null &&
      _sameDay(rangeStart!, rangeEnd!) &&
      _sameDay(rangeStart!, DateTime.now());

  String get _title {
    final start = rangeStart;
    final end = rangeEnd;
    if (start == null || end == null) return 'All Sessions';
    if (_sameDay(start, end)) {
      return _isTodayOnly ? "Today's Focus" : DateFormat('MMM d, yyyy').format(start);
    }
    return '${DateFormat('MMM d').format(start)} – '
        '${DateFormat('MMM d, yyyy').format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    // Per-task totals, most time first.
    final byTask = <int?, int>{};
    for (final session in sessions) {
      byTask[session.taskId] =
          (byTask[session.taskId] ?? 0) + session.currentDurationSeconds;
    }
    final breakdown = byTask.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxTaskSeconds =
        breakdown.isEmpty ? 1 : breakdown.first.value.clamp(1, 1 << 31);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                formatFocusDuration(_totalSeconds),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.emerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${sessions.length} session${sessions.length == 1 ? '' : 's'}',
            style: TextStyle(fontSize: 12, color: colors.textTertiary),
          ),
          const SizedBox(height: 16),

          if (breakdown.isNotEmpty) ...[
            Text('By task', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final entry in breakdown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _taskTitle(entry.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: colors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: entry.value / maxTaskSeconds,
                          minHeight: 5,
                          backgroundColor: colors.surfaceVariant,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 56,
                      child: Text(
                        formatFocusDuration(entry.value),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 12),
          ],

          Text('Sessions', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  _isTodayOnly
                      ? 'No focus sessions yet today.\nStart a session to build your streak.'
                      : 'No focus sessions in this range.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: colors.textTertiary, height: 1.5),
                ),
              ),
            )
          else
            for (final session in sessions.reversed) ...[
              _SessionRow(
                session: session,
                taskTitle: _taskTitle(session.taskId),
              ),
              const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.taskTitle});

  final FocusSession session;
  final String taskTitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final timeFormat = DateFormat('h:mm a');
    final start = timeFormat.format(session.startedAt);
    final end = session.endedAt != null
        ? timeFormat.format(session.endedAt!)
        : (session.isPaused ? 'paused' : 'running');
    final isLive = session.endedAt == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isLive
                ? (session.isPaused
                    ? Icons.pause_circle_outline
                    : Icons.timer)
                : Icons.history,
            size: 16,
            color: isLive
                ? (session.isPaused ? AppTheme.amber : AppTheme.emerald)
                : colors.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                Text(
                  '$start – $end',
                  style:
                      TextStyle(fontSize: 11, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          Text(
            formatFocusDuration(session.currentDurationSeconds),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isLive ? AppTheme.emerald : colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
