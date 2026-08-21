import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../core/app_navigator.dart';
import '../core/app_version.dart';
import '../models/routine.dart';
import '../models/task.dart';
import '../providers/focus_provider.dart';
import '../providers/routines_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shortcuts_provider.dart';
import '../providers/tasks_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'global_search.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.currentIndex,
    required this.onNavigate,
    this.onCloseDrawer,
  });

  final int currentIndex;
  final ValueChanged<int> onNavigate;

  /// Called before actions that should dismiss the drawer (e.g. search,
  /// notification taps) so the slide-in nav bar closes first.
  final VoidCallback? onCloseDrawer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Consumer<TasksProvider>(
      builder: (context, tasks, _) {
        // Sidebar order is user-configurable (Settings → Sidebar order);
        // each page still maps to its fixed screen index.
        final navOrder = context.watch<SettingsProvider>().navOrder;
        return Container(
          width: 256,
          decoration: BoxDecoration(
            color: colors.sidebarBackground,
            border: Border(right: BorderSide(color: colors.border)),
          ),
          child: Column(
            children: [
              // Logo + title
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: SvgPicture.asset(
                        'assets/icon/app_logo.svg',
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppVersion.appName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          'v${AppVersion.version}',
                          style: TextStyle(
                            fontSize: 10,
                            color: colors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Global search (available from every screen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Material(
                  color: colors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    key: const Key('sidebar_search_button'),
                    onTap: () {
                      onCloseDrawer?.call();
                      showGlobalSearch(context);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                      children: [
                        Icon(Icons.search,
                            size: 18, color: colors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search…',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                            overflow: TextOverflow.clip,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _ShortcutPill(
                          shortcut: ShortcutsProvider.keySetToString(
                            context.read<ShortcutsProvider>().bindings[ShortcutAction.commandPalette]!,
                          ),
                        ),
                      ],
                    ),
                    ),
                  ),
                ),
              ),

              // Navigation items (user-reorderable order)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final page in navOrder)
                        _NavItem(
                          icon: page.icon,
                          activeIcon: page.activeIcon,
                          label: page.label,
                          index: page.screenIndex,
                          currentIndex: currentIndex,
                          onTap: () => onNavigate(page.screenIndex),
                        ),
                    ],
                  ),
                ),
              ),

              // Notification center: overdue, scheduled, active timers, focus, routine alerts.
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: NotificationMenu(
                  allTasks: tasks.tasks,
                  runningTasks: tasks.runningTasks,
                  focusActive:
                      context.watch<FocusProvider>().activeSession != null,
                  routinesDue: context
                      .watch<RoutinesProvider>()
                      .routines
                      .where((r) =>
                          r.isActiveOn(DateTime.now()) && !r.isCompletedToday)
                      .toList(),
                  onNavigate: onNavigate,
                  onTaskHighlighted: (taskId) {
                    onCloseDrawer?.call();
                    AppNavigator.instance.highlightTaskOnTasksPage(taskId);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isActive = currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isActive ? colors.navItemActive : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  size: 20,
                  color: isActive
                      ? colors.navItemActiveText
                      : colors.navItemInactiveText,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? colors.navItemActiveText
                        : colors.navItemInactiveText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill showing a keyboard shortcut (e.g. Ctrl+K).
class _ShortcutPill extends StatelessWidget {
  const _ShortcutPill({required this.shortcut});

  final String shortcut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colors.border.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Text(
        shortcut,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: colors.textTertiary,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// Bell with a dropdown listing overdue tasks, scheduled-for-today tasks,
/// active task timers, the running focus session, and routines due today.
/// Clicking an entry navigates to the relevant screen.
class NotificationMenu extends StatefulWidget {
  const NotificationMenu({
    super.key,
    required this.allTasks,
    required this.runningTasks,
    required this.focusActive,
    required this.routinesDue,
    required this.onNavigate,
    this.onTaskHighlighted,
  });

  final List<Task> allTasks;
  final List<Task> runningTasks;
  final bool focusActive;
  final List<Routine> routinesDue;
  final ValueChanged<int> onNavigate;

  /// Called with a task id when a task-based notification row is tapped.
  /// Navigates to the Tasks screen and highlights (scroll + glow) the task.
  final ValueChanged<int>? onTaskHighlighted;

  @override
  State<NotificationMenu> createState() => _NotificationMenuState();
}

class _NotificationMenuState extends State<NotificationMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  /// When true the badge count is hidden until new data arrives.
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ─── Derived data ───

  bool get _hasOverdue => _overdueTasks.isNotEmpty;
  bool get _hasScheduled => _scheduledTodayTasks.isNotEmpty;
  bool get _hasRunning => widget.runningTasks.isNotEmpty;
  bool get _hasFocus => widget.focusActive;
  bool get _hasRoutines => widget.routinesDue.isNotEmpty;

  List<Task> get _overdueTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return widget.allTasks.where((t) {
      if (t.status == 'Completed' || t.dueDate == null) return false;
      final dueDay = DateTime(
          t.dueDate!.year, t.dueDate!.month, t.dueDate!.day);
      return dueDay.isBefore(today);
    }).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  }

  List<Task> get _scheduledTodayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return widget.allTasks.where((t) {
      if (t.status == 'Completed') return false;
      if (t.scheduledDate == null) return false;
      final schedDay = DateTime(
          t.scheduledDate!.year, t.scheduledDate!.month, t.scheduledDate!.day);
      return schedDay.isAtSameMomentAs(today);
    }).toList()
      ..sort((a, b) {
        // Tasks with a scheduled time first, then by sort order.
        if (a.scheduledTime != null && b.scheduledTime == null) return -1;
        if (a.scheduledTime == null && b.scheduledTime != null) return 1;
        return a.sortOrder.compareTo(b.sortOrder);
      });
  }

  int get _completedTodayCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return widget.allTasks.where((t) {
      if (t.status != 'Completed' || t.completedAt == null) return false;
      final completedDay = DateTime(t.completedAt!.year,
          t.completedAt!.month, t.completedAt!.day);
      return completedDay.isAtSameMomentAs(today);
    }).length;
  }

  int get _totalCount =>
      _overdueTasks.length +
      _scheduledTodayTasks.length +
      widget.runningTasks.length +
      (widget.focusActive ? 1 : 0) +
      widget.routinesDue.length;

  int get _displayCount => _dismissed ? 0 : _totalCount;

  bool get _anyNotifications =>
      _hasOverdue || _hasScheduled || _hasRunning || _hasFocus || _hasRoutines;

  // ─── Overdue label ───

  String _overdueLabel(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
        task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    final days = today.difference(dueDay).inDays;
    if (days == 0) return 'Due today';
    if (days == 1) return '1 day overdue';
    return '$days days overdue';
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    // Drive the pulse animation based on display count.
    if (_displayCount > 0 && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (_displayCount == 0 && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }

    final items = <PopupMenuEntry<String>>[];

    if (!_anyNotifications) {
      // ─── Empty state ───
      items.add(const PopupMenuItem<String>(
        enabled: false,
        child: _EmptyState(),
      ));
    } else {
      // ─── Overdue ───
      if (_hasOverdue) {
        items.add(_SectionHeader(label: '⚠️  OVERDUE'));
        for (final task in _overdueTasks.take(5)) {
          items.add(PopupMenuItem<String>(
            value: 'task_${task.id}',
            child: _MenuRow(
              icon: Icons.warning_amber_rounded,
              color: AppTheme.rose,
              label: task.title,
              hint: _overdueLabel(task),
              highPriority: task.priority == 'High',
            ),
          ));
        }
        if (_overdueTasks.length > 5) {
          items.add(PopupMenuItem<String>(
            enabled: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '+${_overdueTasks.length - 5} more overdue',
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
            ),
          ));
        }
      }

      // ─── Scheduled today ───
      if (_hasScheduled) {
        items.add(_SectionHeader(label: '📅  SCHEDULED TODAY'));
        for (final task in _scheduledTodayTasks.take(5)) {
          final hint = task.scheduledTime != null
              ? 'Scheduled at ${task.scheduledTime}'
              : 'Scheduled today';
          items.add(PopupMenuItem<String>(
            value: 'task_${task.id}',
            child: _MenuRow(
              icon: Icons.event_outlined,
              color: AppTheme.blue,
              label: task.title,
              hint: hint,
              highPriority: task.priority == 'High',
            ),
          ));
        }
        if (_scheduledTodayTasks.length > 5) {
          items.add(PopupMenuItem<String>(
            enabled: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '+${_scheduledTodayTasks.length - 5} more scheduled',
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
            ),
          ));
        }
      }

      // ─── Running timers ───
      if (_hasRunning) {
        items.add(_SectionHeader(label: '⏰  RUNNING TIMERS'));
        for (final task in widget.runningTasks.take(5)) {
          items.add(PopupMenuItem<String>(
            value: 'task_${task.id}',
            child: _MenuRow(
              icon: Icons.timer_outlined,
              color: AppTheme.blue,
              label: task.title,
              hint: 'Timer running · ${task.formattedTimeFriendly}',
              highPriority: task.priority == 'High',
            ),
          ));
        }
        if (widget.runningTasks.length > 5) {
          items.add(PopupMenuItem<String>(
            enabled: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '+${widget.runningTasks.length - 5} more timers',
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
            ),
          ));
        }
      }

      // ─── Focus session ───
      if (_hasFocus) {
        items.add(_SectionHeader(label: '🎯  FOCUS SESSION'));
        items.add(const PopupMenuItem<String>(
          value: 'focus',
          child: _MenuRow(
            icon: Icons.timer,
            color: AppTheme.emerald,
            label: 'Active focus session',
            hint: 'Focus page',
          ),
        ));
      }

      // ─── Routines due ───
      if (_hasRoutines) {
        items.add(_SectionHeader(label: '🔁  ROUTINES DUE'));
        for (final routine in widget.routinesDue.take(5)) {
          items.add(PopupMenuItem<String>(
            value: 'routines',
            child: _MenuRow(
              icon: Icons.repeat,
              color: AppTheme.amber,
              label: routine.title,
              hint: 'Due today',
            ),
          ));
        }
        if (widget.routinesDue.length > 5) {
          items.add(PopupMenuItem<String>(
            enabled: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '+${widget.routinesDue.length - 5} more routines',
                style: TextStyle(fontSize: 11, color: colors.textTertiary),
              ),
            ),
          ));
        }
      }

      // ─── Dismiss all + completed summary footer ───
      items.add(const PopupMenuDivider(height: 1));
      items.add(PopupMenuItem<String>(
        value: 'dismiss',
        child: Row(
          children: [
            Icon(Icons.done_all, size: 14, color: colors.textTertiary),
            const SizedBox(width: 8),
            Text(
              'Dismiss all',
              style: TextStyle(fontSize: 12, color: colors.textTertiary),
            ),
          ],
        ),
      ));
      final completed = _completedTodayCount;
      if (completed > 0) {
        items.add(PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 14, color: AppTheme.emerald),
              const SizedBox(width: 8),
              Text(
                '$completed task${completed == 1 ? '' : 's'} completed today',
                style: TextStyle(
                    fontSize: 12,
                    color: colors.textTertiary,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PopupMenuButton<String>(
        tooltip: _displayCount > 0
            ? '$_displayCount notification${_displayCount == 1 ? '' : 's'}'
            : 'No notifications',
        onSelected: (value) {
          if (value.startsWith('task_')) {
            final taskId = int.tryParse(value.substring(5));
            if (taskId != null && widget.onTaskHighlighted != null) {
              widget.onTaskHighlighted!(taskId);
            } else {
              widget.onNavigate(1);
            }
          } else {
            switch (value) {
              case 'focus':
                widget.onNavigate(4);
              case 'routines':
                widget.onNavigate(5);
              case 'dismiss':
                setState(() => _dismissed = true);
            }
          }
        },
        itemBuilder: (_) => items,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated bell badge
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  final scale = _displayCount > 0 ? _pulseAnimation.value : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Badge(
                      isLabelVisible: _displayCount > 0,
                      label: Text('$_displayCount'),
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: colors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Notifications',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Section header ───

class _SectionHeader extends PopupMenuEntry<String> {
  const _SectionHeader({required this.label});

  final String label;

  @override
  double get height => 36;

  @override
  bool represents(String? value) => false;

  @override
  _SectionHeaderState createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        widget.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.textTertiary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ─── Empty state ───

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 28, color: AppTheme.emerald),
          const SizedBox(height: 8),
          Text(
            'All caught up! 🎉',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'No pending items',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── Menu row ───

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.hint,
    this.highPriority = false,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String hint;
  final bool highPriority;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: highPriority
                            ? AppTheme.rose
                            : colors.textPrimary,
                      ),
                    ),
                  ),
                  if (highPriority) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppTheme.rose,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                hint,
                style: TextStyle(fontSize: 10, color: colors.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
