import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../components/focus/session_log.dart';
import '../providers/focus_provider.dart';
import '../providers/tasks_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/date_range_selector.dart';
import '../widgets/focus_timer.dart';

/// Focus: a circular timer with an attached task plus today's session
/// log (total time, per-task breakdown, session list).
class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isCollapsed = AppTheme.isScreenCollapsed(context);
    final focus = context.watch<FocusProvider>();

    final content = Column(
      children: [
        _buildHeader(context, colors, isCollapsed, focus),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final timer = const FocusTimer();
              final log = SessionLog(
                sessions: focus.visibleSessions,
                tasks: context.watch<TasksProvider>().tasks,
                rangeStart: focus.rangeStart,
                rangeEnd: focus.rangeEnd,
              );
              if (constraints.maxWidth > 900) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: timer),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SingleChildScrollView(child: log),
                      ),
                    ],
                  ),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    timer,
                    const SizedBox(height: 16),
                    log,
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );

    return content;
  }

  Widget _buildHeader(BuildContext context, AppThemeColors colors,
      bool isCollapsed, FocusProvider focus) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (isCollapsed) ...[
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Focus', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  _rangeSubtitle(focus),
                  style:
                      TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear all focus sessions',
            icon: Icon(Icons.delete_sweep_outlined,
                color: colors.textSecondary),
            onPressed: () => _confirmClearAll(context, focus),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 210,
            child: DateRangeSelector(
              start: focus.rangeStart,
              end: focus.rangeEnd,
              onRangeSelected: focus.setDateRange,
            ),
          ),
        ],
      ),
    );
  }

  /// Asks for confirmation before wiping every recorded focus session.
  Future<void> _confirmClearAll(
      BuildContext context, FocusProvider focus) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final running = focus.activeSession != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Clear all focus sessions?'),
        content: Text(
          running
              ? 'This permanently deletes every recorded focus session. '
                  'A session is currently running and will be stopped as '
                  'well. This cannot be undone.'
              : 'This permanently deletes every recorded focus session. '
                  'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await focus.clearAllSessions();
    }
  }

  /// Header subtitle: total for the selected range plus its description,
  /// e.g. "1:23:45 focused today" or "2:10:00 focused · Aug 17 – Aug 23".
  String _rangeSubtitle(FocusProvider focus) {
    final total = formatFocusDuration(focus.visibleSeconds);
    final start = focus.rangeStart;
    final end = focus.rangeEnd;
    if (start == null || end == null) return '$total focused · all sessions';
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      final now = DateTime.now();
      if (start.year == now.year &&
          start.month == now.month &&
          start.day == now.day) {
        return '$total focused today';
      }
      return '$total focused · ${DateFormat('MMM d, yyyy').format(start)}';
    }
    if (start.year == end.year) {
      return '$total focused · ${DateFormat('MMM d').format(start)} – '
          '${DateFormat('MMM d, yyyy').format(end)}';
    }
    return '$total focused · ${DateFormat('MMM d, yyyy').format(start)} – '
        '${DateFormat('MMM d, yyyy').format(end)}';
  }
}
