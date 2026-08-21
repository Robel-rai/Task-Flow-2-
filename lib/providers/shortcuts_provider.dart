import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ShortcutAction {
  commandPalette, newTask, newProject, newRoutine, toggleFocus,
  goToDashboard, goToTasks, goToCalendar, goToProjects, goToFocus,
  goToRoutines, goToAnalytics, goToSettings, toggleTheme, saveDialog, closeDialog,
}

class ShortcutMeta {
  const ShortcutMeta({required this.label, required this.description, required this.category});
  final String label;
  final String description;
  final String category;

  static const Map<ShortcutAction, ShortcutMeta> all = {
    ShortcutAction.commandPalette: ShortcutMeta(label: 'Command Palette', description: 'Open global search and quick actions', category: 'General'),
    ShortcutAction.newTask: ShortcutMeta(label: 'New Task', description: 'Create a new task from any screen', category: 'Quick Actions'),
    ShortcutAction.newProject: ShortcutMeta(label: 'New Project', description: 'Create a new project', category: 'Quick Actions'),
    ShortcutAction.newRoutine: ShortcutMeta(label: 'New Routine', description: 'Create a new routine', category: 'Quick Actions'),
    ShortcutAction.toggleFocus: ShortcutMeta(label: 'Start/Stop Focus', description: 'Toggle focus timer session', category: 'Quick Actions'),
    ShortcutAction.goToDashboard: ShortcutMeta(label: 'Go to Dashboard', description: 'Navigate to Dashboard', category: 'Navigation'),
    ShortcutAction.goToTasks: ShortcutMeta(label: 'Go to Tasks', description: 'Navigate to Tasks', category: 'Navigation'),
    ShortcutAction.goToCalendar: ShortcutMeta(label: 'Go to Calendar', description: 'Navigate to Calendar', category: 'Navigation'),
    ShortcutAction.goToProjects: ShortcutMeta(label: 'Go to Projects', description: 'Navigate to Projects', category: 'Navigation'),
    ShortcutAction.goToFocus: ShortcutMeta(label: 'Go to Focus', description: 'Navigate to Focus', category: 'Navigation'),
    ShortcutAction.goToRoutines: ShortcutMeta(label: 'Go to Routines', description: 'Navigate to Routines', category: 'Navigation'),
    ShortcutAction.goToAnalytics: ShortcutMeta(label: 'Go to Analytics', description: 'Navigate to Analytics', category: 'Navigation'),
    ShortcutAction.goToSettings: ShortcutMeta(label: 'Go to Settings', description: 'Navigate to Settings', category: 'Navigation'),
    ShortcutAction.toggleTheme: ShortcutMeta(label: 'Toggle Theme', description: 'Switch between light and dark mode', category: 'System'),
    ShortcutAction.saveDialog: ShortcutMeta(label: 'Save Dialog', description: 'Save the current open dialog', category: 'General'),
    ShortcutAction.closeDialog: ShortcutMeta(label: 'Close', description: 'Close any open dialog or overlay', category: 'General'),
  };
}

final Map<LogicalKeyboardKey, String> _keyNames = {
  LogicalKeyboardKey.control: 'Ctrl',
  LogicalKeyboardKey.shift: 'Shift',
  LogicalKeyboardKey.alt: 'Alt',
  LogicalKeyboardKey.meta: 'Win',
  LogicalKeyboardKey.keyA: 'A', LogicalKeyboardKey.keyB: 'B', LogicalKeyboardKey.keyC: 'C',
  LogicalKeyboardKey.keyD: 'D', LogicalKeyboardKey.keyE: 'E', LogicalKeyboardKey.keyF: 'F',
  LogicalKeyboardKey.keyG: 'G', LogicalKeyboardKey.keyH: 'H', LogicalKeyboardKey.keyI: 'I',
  LogicalKeyboardKey.keyJ: 'J', LogicalKeyboardKey.keyK: 'K', LogicalKeyboardKey.keyL: 'L',
  LogicalKeyboardKey.keyM: 'M', LogicalKeyboardKey.keyN: 'N', LogicalKeyboardKey.keyO: 'O',
  LogicalKeyboardKey.keyP: 'P', LogicalKeyboardKey.keyQ: 'Q', LogicalKeyboardKey.keyR: 'R',
  LogicalKeyboardKey.keyS: 'S', LogicalKeyboardKey.keyT: 'T', LogicalKeyboardKey.keyU: 'U',
  LogicalKeyboardKey.keyV: 'V', LogicalKeyboardKey.keyW: 'W', LogicalKeyboardKey.keyX: 'X',
  LogicalKeyboardKey.keyY: 'Y', LogicalKeyboardKey.keyZ: 'Z',
  LogicalKeyboardKey.digit0: '0', LogicalKeyboardKey.digit1: '1', LogicalKeyboardKey.digit2: '2',
  LogicalKeyboardKey.digit3: '3', LogicalKeyboardKey.digit4: '4', LogicalKeyboardKey.digit5: '5',
  LogicalKeyboardKey.digit6: '6', LogicalKeyboardKey.digit7: '7', LogicalKeyboardKey.digit8: '8',
  LogicalKeyboardKey.digit9: '9',
  LogicalKeyboardKey.escape: 'Esc', LogicalKeyboardKey.space: 'Space',
  LogicalKeyboardKey.enter: 'Enter', LogicalKeyboardKey.backspace: 'Backspace',
  LogicalKeyboardKey.tab: 'Tab', LogicalKeyboardKey.delete: 'Delete',
};

final Map<String, LogicalKeyboardKey> _nameToKey = {
  for (final e in _keyNames.entries) e.value: e.key,
};

LogicalKeySet _defaultFor(ShortcutAction action) => defaultBindings[action]!;

final Map<ShortcutAction, LogicalKeySet> defaultBindings = {
  ShortcutAction.commandPalette: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK),
  ShortcutAction.newTask: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN),
  ShortcutAction.newProject: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyN),
  ShortcutAction.newRoutine: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyR),
  ShortcutAction.toggleFocus: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF),
  ShortcutAction.goToDashboard: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1),
  ShortcutAction.goToTasks: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2),
  ShortcutAction.goToCalendar: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit3),
  ShortcutAction.goToProjects: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit4),
  ShortcutAction.goToFocus: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit5),
  ShortcutAction.goToRoutines: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit6),
  ShortcutAction.goToAnalytics: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit7),
  ShortcutAction.goToSettings: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit8),
  ShortcutAction.toggleTheme: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.keyT),
  ShortcutAction.saveDialog: LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS),
  ShortcutAction.closeDialog: LogicalKeySet(LogicalKeyboardKey.escape),
};

class ShortcutsProvider extends ChangeNotifier {
  Map<ShortcutAction, LogicalKeySet> _bindings = {};
  Map<ShortcutAction, LogicalKeySet> get bindings => _bindings;

  Future<void> initialize() async {
    _bindings = {for (final a in ShortcutAction.values) a: _defaultFor(a)};
    final prefs = await SharedPreferences.getInstance();
    for (final action in ShortcutAction.values) {
      final stored = prefs.getStringList('shortcut_${action.name}');
      if (stored != null && stored.isNotEmpty) {
        final keys = stored.map((name) => _nameToKey[name]).whereType<LogicalKeyboardKey>().toSet();
        if (keys.isNotEmpty) {
          _bindings[action] = LogicalKeySet.fromSet(keys);
        }
      }
    }
    notifyListeners();
  }

  Future<void> setBinding(ShortcutAction action, LogicalKeySet? keys) async {
    _bindings[action] = keys ?? _defaultFor(action);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (keys == null) {
      await prefs.remove('shortcut_${action.name}');
    } else {
      final names = keys.keys.map((k) => _keyNames[k] ?? k.keyLabel).toList();
      await prefs.setStringList('shortcut_${action.name}', names);
    }
  }

  Future<void> resetAll() async {
    _bindings = {for (final a in ShortcutAction.values) a: _defaultFor(a)};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    for (final action in ShortcutAction.values) {
      await prefs.remove('shortcut_${action.name}');
    }
  }

  static String keySetToString(LogicalKeySet keys) {
    final parts = <String>[];
    final sorted = keys.keys.toList()
      ..sort((a, b) {
        final mods = {LogicalKeyboardKey.control, LogicalKeyboardKey.shift, LogicalKeyboardKey.alt, LogicalKeyboardKey.meta};
        final aMod = mods.contains(a);
        final bMod = mods.contains(b);
        if (aMod && !bMod) return -1;
        if (!aMod && bMod) return 1;
        return 0;
      });
    for (final key in sorted) {
      parts.add(_keyNames[key] ?? key.keyLabel.toUpperCase());
    }
    return parts.join(' + ');
  }
}
