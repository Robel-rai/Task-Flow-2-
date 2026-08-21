import 'package:flutter/material.dart';

/// A sidebar destination: a stable [id] (persisted in the nav order),
/// display metadata, and the [screenIndex] it opens in the shell's
/// fixed `IndexedStack`.
///
/// Reordering the sidebar only changes the display order of these pages —
/// each still maps to the same screen index, so navigation, the active
/// highlight, and global-search intents keep working.
enum NavPage {
  dashboard(
    id: 'dashboard',
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard,
    screenIndex: 0,
  ),
  tasks(
    id: 'tasks',
    label: 'Tasks',
    icon: Icons.check_circle_outline,
    activeIcon: Icons.check_circle,
    screenIndex: 1,
  ),
  calendar(
    id: 'calendar',
    label: 'Calendar',
    icon: Icons.calendar_today_outlined,
    activeIcon: Icons.calendar_today,
    screenIndex: 2,
  ),
  projects(
    id: 'projects',
    label: 'Projects',
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder,
    screenIndex: 3,
  ),
  focus(
    id: 'focus',
    label: 'Focus',
    icon: Icons.timer_outlined,
    activeIcon: Icons.timer,
    screenIndex: 4,
  ),
  routines(
    id: 'routines',
    label: 'Routines',
    icon: Icons.repeat_outlined,
    activeIcon: Icons.repeat,
    screenIndex: 5,
  ),
  analytics(
    id: 'analytics',
    label: 'Analytics',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart,
    screenIndex: 6,
  ),
  settings(
    id: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    screenIndex: 7,
  );

  const NavPage({
    required this.id,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.screenIndex,
  });

  final String id;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int screenIndex;

  /// The built-in order shown for fresh installs (and after a reset).
  static const List<NavPage> defaults = [
    NavPage.dashboard,
    NavPage.tasks,
    NavPage.calendar,
    NavPage.projects,
    NavPage.focus,
    NavPage.routines,
    NavPage.analytics,
    NavPage.settings,
  ];

  /// Resolves a persisted id to its page (falls back to dashboard for
  /// unknown/legacy ids).
  static NavPage fromId(String id) =>
      NavPage.values.where((p) => p.id == id).firstOrNull ?? NavPage.dashboard;
}
