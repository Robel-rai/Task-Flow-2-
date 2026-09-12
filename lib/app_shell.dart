import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'components/notifications/due_date_popup.dart';
import 'components/notifications/pending_tasks_popup.dart';
import 'core/app_navigator.dart';
import 'providers/tasks_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/projects_provider.dart';
import 'providers/routines_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/analytics_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/focus_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tasks_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/sidebar.dart';
import 'providers/shortcuts_provider.dart';
import 'widgets/task_dialog.dart';
import 'widgets/global_search.dart';
import 'components/projects/project_dialog.dart';
import 'components/routines/routine_dialog.dart';
import 'models/project.dart';
import 'models/routine.dart';

/// The application shell: fixed sidebar (or drawer when narrow) with an
/// [IndexedStack] of the eight screens so each keeps its state.
///
/// Also manages a periodic timer that checks for due-date and pending-task
/// notifications and triggers in-app popups + Windows toasts.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final NotificationService _notificationService = NotificationService();
  Timer? _notificationTimer;
  bool _popupShowing = false;

  static const List<Widget> _screens = [
    DashboardScreen(),
    TasksScreen(),
    CalendarScreen(),
    ProjectsScreen(),
    FocusScreen(),
    RoutinesScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _startNotificationTimer();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationTimer() {
    // Check immediately after first frame, then every 60 seconds.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNotifications());
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkNotifications(),
    );
  }

  Future<void> _checkNotifications() async {
    if (_popupShowing) return; // Don't stack popups
    if (!mounted) return;

    try {
      final tasksProvider = context.read<TasksProvider>();
      final tasks = tasksProvider.tasks;
      if (tasks.isEmpty) return;

      // ── Check for due tasks ──
      final dueTasks = await _notificationService.checkDueTasks(tasks);
      if (dueTasks.isNotEmpty && mounted && !_popupShowing) {
        _popupShowing = true;
        // Fire Windows toasts for each due task
        for (final task in dueTasks) {
          await _notificationService.showDueDateToast(task);
        }
        // Show in-app popup
        if (mounted) {
          await DueDatePopup.show(context, dueTasks);
        }
        _popupShowing = false;
      }

      // ── Check for pending tasks (only if due-date didn't just fire) ──
      if (dueTasks.isEmpty && await _notificationService.pendingTasksEnabled) {
        final slotIndex =
            await _notificationService.pendingScheduleSlotNow();
        if (slotIndex >= 0) {
          final pendingTasks =
              tasks.where((t) => t.status == 'Pending').toList();
          if (pendingTasks.isNotEmpty && mounted && !_popupShowing) {
            _popupShowing = true;
            // Fire Windows toast summary
            await _notificationService.showPendingTasksToast(pendingTasks.length);
            // Show in-app popup
            if (mounted) {
              await PendingTasksPopup.show(context, pendingTasks);
            }
            _popupShowing = false;
          }
        }
      }
      // Reset fired slots at midnight
      _notificationService.resetSlotsIfNeeded(DateTime.now());
    } catch (e, st) {
      debugPrint('Notification check error: $e $st');
    }
  }

  void _onNavigate(int index) {
    AppNavigator.instance.goTo(index);
    _closeDrawer();
  }

  void _closeDrawer() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCollapsed = AppTheme.isScreenCollapsed(context);

    return ListenableBuilder(
      listenable: AppNavigator.instance,
      builder: (context, _) {
        final currentIndex = AppNavigator.instance.index;
        return ListenableBuilder(
        listenable: context.watch<ShortcutsProvider>(),
        builder: (ctx, _) {
          final sc = ctx.read<ShortcutsProvider>();
          return Shortcuts(
            shortcuts: { for (final e in sc.bindings.entries) e.value: _ActionIntent(e.key) },
            child: Actions(
              actions: { for (final _ in ShortcutAction.values) _ActionIntent: CallbackAction<_ActionIntent>(onInvoke: (i) => _handleShortcut(ctx, i.action)) },
              child: Focus(autofocus: true, child: Scaffold(
          key: _scaffoldKey,
          drawer: isCollapsed
              ? Drawer(
                  child: Sidebar(
                      currentIndex: currentIndex,
                      onNavigate: _onNavigate,
                      onCloseDrawer: _closeDrawer))
              : null,
          body: Row(
            children: [
              if (!isCollapsed)
                Sidebar(currentIndex: currentIndex, onNavigate: _onNavigate),
              Expanded(
                child: IndexedStack(index: currentIndex, children: _screens),
              ),
            ],
          ),
        ),
              ),
            ),
          );
        },
      );
      },
    );
  }

  void _handleShortcut(BuildContext ctx, ShortcutAction action) {
    switch (action) {
      case ShortcutAction.commandPalette: showGlobalSearch(ctx);
      case ShortcutAction.newTask: _openNewTask(ctx);
      case ShortcutAction.newProject: _openNewProject(ctx);
      case ShortcutAction.newRoutine: _openNewRoutine(ctx);
      case ShortcutAction.toggleFocus:
        final f = ctx.read<FocusProvider>();
        if (f.activeSession != null) { f.stop(); } else { AppNavigator.instance.goTo(4); }
      case ShortcutAction.goToDashboard: AppNavigator.instance.goTo(0);
      case ShortcutAction.goToTasks: AppNavigator.instance.goTo(1);
      case ShortcutAction.goToCalendar: AppNavigator.instance.goTo(2);
      case ShortcutAction.goToProjects: AppNavigator.instance.goTo(3);
      case ShortcutAction.goToFocus: AppNavigator.instance.goTo(4);
      case ShortcutAction.goToRoutines: AppNavigator.instance.goTo(5);
      case ShortcutAction.goToAnalytics: AppNavigator.instance.goTo(6);
      case ShortcutAction.goToSettings: AppNavigator.instance.goTo(7);
      case ShortcutAction.toggleTheme:
        ctx.read<ThemeProvider>().setThemeMode(Theme.of(ctx).brightness == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
      case ShortcutAction.saveDialog:
        final nav = Navigator.of(ctx, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      case ShortcutAction.closeDialog:
        final nav = Navigator.of(ctx, rootNavigator: true);
        if (nav.canPop()) nav.pop();
    }
  }

  void _openNewTask(BuildContext ctx) async {
    final tasks = ctx.read<TasksProvider>();
    final result = await showDialog<TaskDialogResult>(context: ctx, builder: (_) => const TaskDialog());
    if (result == null) return;
    await tasks.createTask(result.task, subtasks: result.subtasks);
  }

  void _openNewProject(BuildContext ctx) async {
    final projects = ctx.read<ProjectsProvider>();
    final result = await showDialog<ProjectDialogResult>(context: ctx, builder: (_) => ProjectDialog(project: Project(title: '')));
    if (result == null) return;
    await projects.create(result.project);
  }

  void _openNewRoutine(BuildContext ctx) async {
    final routines = ctx.read<RoutinesProvider>();
    final result = await showDialog<RoutineDialogResult>(context: ctx, builder: (_) => RoutineDialog(routine: Routine(title: '', scheduledTime: '08:00')));
    if (result == null) return;
    await routines.create(result.routine);
  }
}

class _ActionIntent extends Intent {
  const _ActionIntent(this.action);
  final ShortcutAction action;
}
