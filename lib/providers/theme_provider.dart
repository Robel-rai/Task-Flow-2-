import 'package:flutter/material.dart';
import '../core/app_change_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the active theme mode (and, in a later phase, accent color).
class ThemeProvider extends AppChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  /// Default accent color key; accent selection arrives with Settings.
  String _accentColor = 'primary';
  String get accentColor => _accentColor;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('themeMode');
    if (themeStr != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeStr,
        orElse: () => ThemeMode.system,
      );
    } else {
      // Legacy v1 preference: isDarkMode bool.
      final oldIsDark = prefs.getBool('isDarkMode');
      if (oldIsDark != null) {
        _themeMode = oldIsDark ? ThemeMode.dark : ThemeMode.light;
      }
    }
    _accentColor = prefs.getString('accentColor') ?? 'primary';
    safeNotify();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  Future<void> setAccentColor(String colorKey) async {
    _accentColor = colorKey;
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accentColor', colorKey);
  }
}
