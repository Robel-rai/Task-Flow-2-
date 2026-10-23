import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'windows_registry.dart';

/// Registry key Windows reads at sign-in to launch per-user programs.
///
/// This is the per-user (`HKCU`) location, so registering needs no
/// administrator rights and the app shows up in Task Manager → Startup apps.
const String kWindowsRunSubKey =
    r'Software\Microsoft\Windows\CurrentVersion\Run';

/// Raised when the startup entry could not be registered or removed.
class StartupRegistrationException implements Exception {
  StartupRegistrationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The slice of the registry the startup feature needs, behind an interface
/// so the service can be tested without touching the real machine.
abstract class StartupRegistry {
  /// The command registered under [valueName], or null when absent.
  String? readCommand(String valueName);

  void writeCommand(String valueName, String command);

  /// Removes [valueName]; a no-op when it is already absent.
  void removeCommand(String valueName);
}

/// [StartupRegistry] backed by `HKCU\...\CurrentVersion\Run`.
class WindowsStartupRegistry implements StartupRegistry {
  WindowsStartupRegistry({WindowsRegistry? registry, String? subKey})
      : _registry = registry ?? WindowsRegistry(),
        _subKey = subKey ?? kWindowsRunSubKey;

  final WindowsRegistry _registry;
  final String _subKey;

  @override
  String? readCommand(String valueName) =>
      _guard(() => _registry.readString(_subKey, valueName));

  @override
  void writeCommand(String valueName, String command) =>
      _guard(() => _registry.writeString(_subKey, valueName, command));

  @override
  void removeCommand(String valueName) =>
      _guard(() => _registry.deleteValue(_subKey, valueName));

  /// Translates low-level registry failures into a message the UI can show.
  T _guard<T>(T Function() action) {
    try {
      return action();
    } on WindowsRegistryException catch (e) {
      throw StartupRegistrationException(e.message);
    }
  }
}

/// Launches TaskFlow automatically when the user signs in to Windows.
///
/// The user's choice lives in SharedPreferences and is mirrored into the
/// per-user `Run` key ([kWindowsRunSubKey]), so no elevation is ever needed.
///
/// Debug builds register under a distinct value name ("TaskFlow Dev") and a
/// release install uses "TaskFlow", so a `flutter run` build can never hijack
/// the installed app's startup entry — the same split that keeps the two
/// apps' data apart.
class StartupService {
  StartupService({
    StartupRegistry? registry,
    String? executablePath,
    String? valueName,
  })  : _registry = registry ?? WindowsStartupRegistry(),
        _executablePath = executablePath,
        _valueName = valueName;

  /// Preference holding the user's choice. Absent or false means "off".
  static const String prefLaunchAtStartup = 'startup_launch_at_startup';

  /// Run-key value names, split by build mode.
  static const String valueNameRelease = 'TaskFlow';
  static const String valueNameDebug = 'TaskFlow Dev';

  final StartupRegistry _registry;
  final String? _executablePath;
  final String? _valueName;

  /// Whether this platform supports registering a startup entry.
  bool get isSupported => Platform.isWindows;

  /// Full path of the running executable.
  String get executablePath => _executablePath ?? Platform.resolvedExecutable;

  /// The value name this build registers under.
  String get valueName =>
      _valueName ?? (kDebugMode ? valueNameDebug : valueNameRelease);

  /// The command Windows runs at sign-in — the exe path, quoted so that
  /// paths containing spaces survive the round-trip intact.
  String get command => '"$executablePath"';

  /// Whether the app is currently set to start with Windows.
  ///
  /// True only when the preference is on *and* the registry agrees, so the
  /// switch never claims a startup entry that is not really there. A
  /// registry that cannot be read counts as "not registered".
  Future<bool> isEnabled() async {
    if (!isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(prefLaunchAtStartup) ?? false)) return false;
    try {
      return _registry.readCommand(valueName) == command;
    } catch (e) {
      debugPrint('StartupService.isEnabled read failed: $e');
      return false;
    }
  }

  /// Turns the startup entry on or off.
  ///
  /// The registry is written first and the preference only afterwards, so a
  /// failed registration never leaves the app believing it will start with
  /// Windows. Throws [StartupRegistrationException] on failure.
  Future<void> setEnabled(bool enabled) async {
    if (!isSupported) {
      throw StartupRegistrationException(
          'Launch at startup is only available on Windows.');
    }

    if (enabled) {
      _registry.writeCommand(valueName, command);
    } else {
      _registry.removeCommand(valueName);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefLaunchAtStartup, enabled);
  }

  /// Brings the registry in line with the stored preference on launch.
  ///
  /// - Preference on: (re)writes the entry when it is missing or points at an
  ///   old path — after an update or reinstall the exe moves, and without
  ///   this the entry would silently stop working.
  /// - Preference off: removes a leftover entry that points at *this* exe,
  ///   so the app does not keep starting after the user turned it off or
  ///   reset its preferences. Entries belonging to other programs (or to the
  ///   other build's value name) are left untouched.
  ///
  /// Never throws: a registry problem must not stop the app from starting.
  Future<void> reconcile() async {
    if (!isSupported) return;

    final prefs = await SharedPreferences.getInstance();
    final wanted = prefs.getBool(prefLaunchAtStartup) ?? false;

    try {
      final current = _registry.readCommand(valueName);
      if (wanted) {
        if (current != command) _registry.writeCommand(valueName, command);
      } else if (current == command) {
        _registry.removeCommand(valueName);
      }
    } catch (e) {
      debugPrint('StartupService.reconcile skipped: $e');
    }
  }
}
