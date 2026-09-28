import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_change_notifier.dart';
import '../core/event_bus.dart';
import '../database/app_database.dart';
import '../models/category.dart';
import '../models/nav_page.dart';
import '../repositories/category_repository.dart';
import '../services/ui_sound_service.dart';
import '../theme/app_theme.dart';

/// Owns app-level configuration: categories, sidebar navigation order,
/// data reset, custom colors, and custom font selection.
class SettingsProvider extends AppChangeNotifier {
  SettingsProvider({CategoryRepository? categories})
      : _categories = categories ?? CategoryRepository();

  final CategoryRepository _categories;

  List<Category> _categoryList = [];
  List<Category> get categoryList => _categoryList;

  /// Sidebar page order, persisted in SharedPreferences.
  List<NavPage> _navOrder = List.of(NavPage.defaults);
  List<NavPage> get navOrder => _navOrder;

  // ─── Custom font ───
  String _fontFamily = 'Montserrat';
  String get fontFamily => _fontFamily;

  // ─── Focus preferences ───
  int _pomodoroWorkMinutes = 25;
  int get pomodoroWorkMinutes => _pomodoroWorkMinutes;

  int _pomodoroBreakMinutes = 5;
  int get pomodoroBreakMinutes => _pomodoroBreakMinutes;

  int _pomodoroLongBreakMinutes = 15;
  int get pomodoroLongBreakMinutes => _pomodoroLongBreakMinutes;

  bool _autoStartTaskTimer = true;
  bool get autoStartTaskTimer => _autoStartTaskTimer;

  // ─── UI sound preferences ───
  bool _uiSoundEnabled = true;
  bool get uiSoundEnabled => _uiSoundEnabled;

  double _uiSoundVolume = 0.7;
  double get uiSoundVolume => _uiSoundVolume;

  UiSoundPack _uiSoundPack = UiSoundPack.minimal;
  UiSoundPack get uiSoundPack => _uiSoundPack;

  bool _uiSoundFocusEnabled = true;
  bool get uiSoundFocusEnabled => _uiSoundFocusEnabled;

  bool _uiSoundTasksEnabled = true;
  bool get uiSoundTasksEnabled => _uiSoundTasksEnabled;

  bool _uiSoundNotificationsEnabled = true;
  bool get uiSoundNotificationsEnabled => _uiSoundNotificationsEnabled;

  bool _uiSoundLoopEnabled = false;
  bool get uiSoundLoopEnabled => _uiSoundLoopEnabled;

  // ─── Custom colors for dark mode ───
  Color? _darkBackground;
  Color? _darkSurface;
  Color? _darkSurfaceVariant;
  Color? _darkBorder;
  Color? _darkTextPrimary;
  Color? _darkTextSecondary;
  Color? _darkTextTertiary;
  Color? _darkPrimary;
  Color? _darkSidebarBackground;
  Color? _darkNavActive;
  Color? _darkNavActiveText;
  Color? _darkNavInactiveText;

  Color? get darkBackground => _darkBackground;
  Color? get darkSurface => _darkSurface;
  Color? get darkSurfaceVariant => _darkSurfaceVariant;
  Color? get darkBorder => _darkBorder;
  Color? get darkTextPrimary => _darkTextPrimary;
  Color? get darkTextSecondary => _darkTextSecondary;
  Color? get darkTextTertiary => _darkTextTertiary;
  Color? get darkPrimary => _darkPrimary;
  Color? get darkSidebarBackground => _darkSidebarBackground;
  Color? get darkNavActive => _darkNavActive;
  Color? get darkNavActiveText => _darkNavActiveText;
  Color? get darkNavInactiveText => _darkNavInactiveText;

  // ─── Custom colors for light mode ───
  Color? _lightBackground;
  Color? _lightSurface;
  Color? _lightSurfaceVariant;
  Color? _lightBorder;
  Color? _lightTextPrimary;
  Color? _lightTextSecondary;
  Color? _lightTextTertiary;
  Color? _lightPrimary;
  Color? _lightSidebarBackground;
  Color? _lightNavActive;
  Color? _lightNavActiveText;
  Color? _lightNavInactiveText;

  Color? get lightBackground => _lightBackground;
  Color? get lightSurface => _lightSurface;
  Color? get lightSurfaceVariant => _lightSurfaceVariant;
  Color? get lightBorder => _lightBorder;
  Color? get lightTextPrimary => _lightTextPrimary;
  Color? get lightTextSecondary => _lightTextSecondary;
  Color? get lightTextTertiary => _lightTextTertiary;
  Color? get lightPrimary => _lightPrimary;
  Color? get lightSidebarBackground => _lightSidebarBackground;
  Color? get lightNavActive => _lightNavActive;
  Color? get lightNavActiveText => _lightNavActiveText;
  Color? get lightNavInactiveText => _lightNavInactiveText;

  bool get hasCustomDarkColors =>
      _darkBackground != null ||
      _darkSurface != null ||
      _darkPrimary != null ||
      _darkTextPrimary != null;

  bool get hasCustomLightColors =>
      _lightBackground != null ||
      _lightSurface != null ||
      _lightPrimary != null ||
      _lightTextPrimary != null;

  // ─── Personal themes (user-saved snapshots, one per mode) ───
  // role key (e.g. 'bg', 'primary') → serialized color.
  Map<String, String> _personalDark = const {};
  Map<String, String> _personalLight = const {};

  bool get hasPersonalDarkTheme => _personalDark.isNotEmpty;
  bool get hasPersonalLightTheme => _personalLight.isNotEmpty;

  /// Saved personal-theme color for [role] in dark mode, or null.
  Color? personalDarkColor(String role) => _decodeColor(_personalDark[role]);

  /// Saved personal-theme color for [role] in light mode, or null.
  Color? personalLightColor(String role) => _decodeColor(_personalLight[role]);

  /// All color role keys managed by the custom-color system.
  static const List<String> colorRoles = [
    'bg', 'surface', 'surfaceVariant', 'border',
    'textPrimary', 'textSecondary', 'textTertiary', 'primary',
    'sidebarBg', 'navActive', 'navActiveText', 'navInactiveText',
  ];

  /// The color currently in effect for [role] in the given mode
  /// (custom value if set, otherwise the built-in default).
  Color currentRoleColor(String role, bool dark) =>
      (dark ? _darkRole(role) : _lightRole(role)) ??
      defaultForRole(role, dark);

  /// Built-in default color for [role] in the given mode.
  static Color defaultForRole(String role, bool dark) {
    if (dark) {
      return switch (role) {
        'bg' => const Color(0xFF101022),
        'surface' => const Color(0xFF0F172A),
        'surfaceVariant' => const Color(0xFF1E293B),
        'border' => const Color(0xFF1E293B),
        'textPrimary' => const Color(0xFFF1F5F9),
        'textSecondary' => const Color(0xFF94A3B8),
        'textTertiary' => const Color(0xFF64748B),
        'primary' => const Color(0xFF2e2ef4),
        'sidebarBg' => const Color(0x80101022),
        'navActive' => const Color(0xFF1f1fba),
        'navActiveText' => Colors.white,
        'navInactiveText' => const Color(0xFF94A3B8),
        _ => const Color(0xFF999999),
      };
    }
    return switch (role) {
      'bg' => const Color(0xFFF8FAFC),
      'surface' => const Color(0xFFFFFFFF),
      'surfaceVariant' => const Color(0xFFF1F5F9),
      'border' => const Color(0xFFE2E8F0),
      'textPrimary' => const Color(0xFF1E293B),
      'textSecondary' => const Color(0xFF64748B),
      'textTertiary' => const Color(0xFF94A3B8),
      'primary' => const Color(0xFF2e2ef4),
      'sidebarBg' => Colors.white,
      'navActive' => const Color(0xFF1f1fba),
      'navActiveText' => Colors.white,
      'navInactiveText' => const Color(0xFF64748B),
      _ => const Color(0xFF999999),
    };
  }

  Color? _darkRole(String role) => switch (role) {
        'bg' => _darkBackground,
        'surface' => _darkSurface,
        'surfaceVariant' => _darkSurfaceVariant,
        'border' => _darkBorder,
        'textPrimary' => _darkTextPrimary,
        'textSecondary' => _darkTextSecondary,
        'textTertiary' => _darkTextTertiary,
        'primary' => _darkPrimary,
        'sidebarBg' => _darkSidebarBackground,
        'navActive' => _darkNavActive,
        'navActiveText' => _darkNavActiveText,
        'navInactiveText' => _darkNavInactiveText,
        _ => null,
      };

  Color? _lightRole(String role) => switch (role) {
        'bg' => _lightBackground,
        'surface' => _lightSurface,
        'surfaceVariant' => _lightSurfaceVariant,
        'border' => _lightBorder,
        'textPrimary' => _lightTextPrimary,
        'textSecondary' => _lightTextSecondary,
        'textTertiary' => _lightTextTertiary,
        'primary' => _lightPrimary,
        'sidebarBg' => _lightSidebarBackground,
        'navActive' => _lightNavActive,
        'navActiveText' => _lightNavActiveText,
        'navInactiveText' => _lightNavInactiveText,
        _ => null,
      };

  void _setDarkRole(String role, Color? color) {
    switch (role) {
      case 'bg':
        _darkBackground = color;
      case 'surface':
        _darkSurface = color;
      case 'surfaceVariant':
        _darkSurfaceVariant = color;
      case 'border':
        _darkBorder = color;
      case 'textPrimary':
        _darkTextPrimary = color;
      case 'textSecondary':
        _darkTextSecondary = color;
      case 'textTertiary':
        _darkTextTertiary = color;
      case 'primary':
        _darkPrimary = color;
      case 'sidebarBg':
        _darkSidebarBackground = color;
      case 'navActive':
        _darkNavActive = color;
      case 'navActiveText':
        _darkNavActiveText = color;
      case 'navInactiveText':
        _darkNavInactiveText = color;
    }
  }

  void _setLightRole(String role, Color? color) {
    switch (role) {
      case 'bg':
        _lightBackground = color;
      case 'surface':
        _lightSurface = color;
      case 'surfaceVariant':
        _lightSurfaceVariant = color;
      case 'border':
        _lightBorder = color;
      case 'textPrimary':
        _lightTextPrimary = color;
      case 'textSecondary':
        _lightTextSecondary = color;
      case 'textTertiary':
        _lightTextTertiary = color;
      case 'primary':
        _lightPrimary = color;
      case 'sidebarBg':
        _lightSidebarBackground = color;
      case 'navActive':
        _lightNavActive = color;
      case 'navActiveText':
        _lightNavActiveText = color;
      case 'navInactiveText':
        _lightNavInactiveText = color;
    }
  }

  static String _encodeColor(Color c) {
    final argb = c.toARGB32();
    // Keep alpha when it isn't fully opaque (e.g. translucent sidebar).
    if ((argb >> 24) == 0xFF) return AppTheme.colorToHex(c);
    return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  static Color? _decodeColor(String? hex) {
    if (hex == null) return null;
    return AppTheme.parseColor(hex);
  }

  /// Snapshots the colors currently in effect for [darkMode] (custom values
  /// if set, otherwise the built-in defaults) into the personal theme.
  Future<void> savePersonalTheme({required bool darkMode}) async {
    final map = <String, String>{};
    for (final role in colorRoles) {
      final c = (darkMode ? _darkRole(role) : _lightRole(role)) ??
          defaultForRole(role, darkMode);
      map[role] = _encodeColor(c);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        darkMode ? 'personalThemeDark' : 'personalThemeLight',
        jsonEncode(map));
    if (darkMode) {
      _personalDark = map;
    } else {
      _personalLight = map;
    }
    safeNotify();
  }

  /// Applies the saved personal theme for [darkMode] to the active custom
  /// colors (roles missing from the snapshot revert to defaults).
  Future<void> applyPersonalTheme({required bool darkMode}) async {
    final map = darkMode ? _personalDark : _personalLight;
    if (map.isEmpty) return;
    for (final role in colorRoles) {
      final value = _decodeColor(map[role]);
      if (darkMode) {
        _setDarkRole(role, value);
      } else {
        _setLightRole(role, value);
      }
      await _saveColor('${darkMode ? 'dark' : 'light'}_$role', value);
    }
    safeNotify();
  }

  /// Removes the saved personal theme for [darkMode] (does not change the
  /// currently applied colors).
  Future<void> deletePersonalTheme({required bool darkMode}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(darkMode ? 'personalThemeDark' : 'personalThemeLight');
    if (darkMode) {
      _personalDark = const {};
    } else {
      _personalLight = const {};
    }
    safeNotify();
  }

  Future<void> initialize() async {
    _categoryList = await _categories.getAll();
    await _loadNavOrder();
    final prefs = await SharedPreferences.getInstance();
    _fontFamily = prefs.getString('fontFamily') ?? 'Montserrat';
    _pomodoroWorkMinutes = prefs.getInt('pomodoroWorkMinutes') ?? 25;
    _pomodoroBreakMinutes = prefs.getInt('pomodoroBreakMinutes') ?? 5;
    _pomodoroLongBreakMinutes = prefs.getInt('pomodoroLongBreakMinutes') ?? 15;
    _autoStartTaskTimer = prefs.getBool('autoStartTaskTimer') ?? true;

    // ─── UI sound preferences (mirrored into UiSoundService) ───
    _uiSoundEnabled = prefs.getBool('uiSoundEnabled') ?? true;
    _uiSoundVolume = (prefs.getDouble('uiSoundVolume') ?? 0.7).clamp(0.0, 1.0);
    _uiSoundPack = UiSoundPack.fromId(prefs.getString('uiSoundPack'));
    _uiSoundFocusEnabled = prefs.getBool('uiSoundFocusEnabled') ?? true;
    _uiSoundTasksEnabled = prefs.getBool('uiSoundTasksEnabled') ?? true;
    _uiSoundNotificationsEnabled =
        prefs.getBool('uiSoundNotificationsEnabled') ?? true;
    _uiSoundLoopEnabled = prefs.getBool('uiSoundLoopEnabled') ?? false;
    await UiSoundService.instance.loadPreferences(
      enabled: _uiSoundEnabled,
      volume: _uiSoundVolume,
      pack: _uiSoundPack,
      focusEnabled: _uiSoundFocusEnabled,
      tasksEnabled: _uiSoundTasksEnabled,
      notificationsEnabled: _uiSoundNotificationsEnabled,
      loopEnabled: _uiSoundLoopEnabled,
    );

    await _loadCustomColors();
    await _loadPersonalThemes();
    safeNotify(); // Single notification after all data is loaded
    EventBus.instance.subscribe(AppEvent.categoriesChanged, refreshCategories);
  }

  // ─── Custom font persistence ───

  Future<void> setCustomFont(String fontFamily) async {
    _fontFamily = fontFamily;
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fontFamily', fontFamily);
  }

  // ─── Focus preferences persistence ───

  Future<void> setPomodoroWorkMinutes(int minutes) async {
    _pomodoroWorkMinutes = minutes;
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomodoroWorkMinutes', minutes);
  }

  Future<void> setPomodoroBreakMinutes(int minutes) async {
    _pomodoroBreakMinutes = minutes;
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomodoroBreakMinutes', minutes);
  }

  Future<void> setPomodoroLongBreakMinutes(int minutes) async {
    _pomodoroLongBreakMinutes = minutes;
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pomodoroLongBreakMinutes', minutes);
  }

  Future<void> setAutoStartTaskTimer(bool enabled) async {
    _autoStartTaskTimer = enabled;
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoStartTaskTimer', enabled);
  }

  // ─── UI sound persistence (single source: UiSoundService state) ───

  Future<void> setUiSoundEnabled(bool value) async {
    _uiSoundEnabled = value;
    UiSoundService.instance.setEnabled(value);
    if (!value) UiSoundService.instance.stopAll();
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('uiSoundEnabled', value);
  }

  Future<void> setUiSoundVolume(double value) async {
    _uiSoundVolume = value.clamp(0.0, 1.0);
    UiSoundService.instance.setVolume(_uiSoundVolume);
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('uiSoundVolume', _uiSoundVolume);
  }

  Future<void> setUiSoundPack(UiSoundPack value) async {
    _uiSoundPack = value;
    UiSoundService.instance.setPack(value);
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('uiSoundPack', value.id);
  }

  Future<void> setUiSoundCategoryEnabled(UiSoundCategory c, bool v) async {
    switch (c) {
      case UiSoundCategory.focus:
        _uiSoundFocusEnabled = v;
      case UiSoundCategory.tasks:
        _uiSoundTasksEnabled = v;
      case UiSoundCategory.notifications:
        _uiSoundNotificationsEnabled = v;
    }
    UiSoundService.instance.setCategoryEnabled(c, v);
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('uiSound${c.name[0].toUpperCase()}${c.name.substring(1)}Enabled', v);
  }

  Future<void> setUiSoundLoopEnabled(bool value) async {
    _uiSoundLoopEnabled = value;
    UiSoundService.instance.setLoopEnabled(value);
    safeNotify();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('uiSoundLoopEnabled', value);
  }

  // ─── Custom colors persistence ───

  Future<void> _loadCustomColors() async {
    final prefs = await SharedPreferences.getInstance();

    // Dark mode colors
    _darkBackground = _loadColor(prefs, 'dark_bg');
    _darkSurface = _loadColor(prefs, 'dark_surface');
    _darkSurfaceVariant = _loadColor(prefs, 'dark_surfaceVariant');
    _darkBorder = _loadColor(prefs, 'dark_border');
    _darkTextPrimary = _loadColor(prefs, 'dark_textPrimary');
    _darkTextSecondary = _loadColor(prefs, 'dark_textSecondary');
    _darkTextTertiary = _loadColor(prefs, 'dark_textTertiary');
    _darkPrimary = _loadColor(prefs, 'dark_primary');
    _darkSidebarBackground = _loadColor(prefs, 'dark_sidebarBg');
    _darkNavActive = _loadColor(prefs, 'dark_navActive');
    _darkNavActiveText = _loadColor(prefs, 'dark_navActiveText');
    _darkNavInactiveText = _loadColor(prefs, 'dark_navInactiveText');

    // Light mode colors
    _lightBackground = _loadColor(prefs, 'light_bg');
    _lightSurface = _loadColor(prefs, 'light_surface');
    _lightSurfaceVariant = _loadColor(prefs, 'light_surfaceVariant');
    _lightBorder = _loadColor(prefs, 'light_border');
    _lightTextPrimary = _loadColor(prefs, 'light_textPrimary');
    _lightTextSecondary = _loadColor(prefs, 'light_textSecondary');
    _lightTextTertiary = _loadColor(prefs, 'light_textTertiary');
    _lightPrimary = _loadColor(prefs, 'light_primary');
    _lightSidebarBackground = _loadColor(prefs, 'light_sidebarBg');
    _lightNavActive = _loadColor(prefs, 'light_navActive');
    _lightNavActiveText = _loadColor(prefs, 'light_navActiveText');
    _lightNavInactiveText = _loadColor(prefs, 'light_navInactiveText');

    safeNotify();
  }

  Color? _loadColor(SharedPreferences prefs, String key) {
    final hex = prefs.getString(key);
    if (hex == null) return null;
    return AppTheme.parseColor(hex);
  }

  Future<void> _loadPersonalThemes() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in [
      MapEntry(true, 'personalThemeDark'),
      MapEntry(false, 'personalThemeLight'),
    ]) {
      final raw = prefs.getString(entry.value);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
          if (entry.key) {
            _personalDark = map;
          } else {
            _personalLight = map;
          }
        }
      } catch (_) {
        // Corrupt snapshot — ignore; the personal tile simply shows unsaved.
      }
    }
  }

  Future<void> _saveColor(String key, Color? color) async {
    final prefs = await SharedPreferences.getInstance();
    if (color == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, AppTheme.colorToHex(color));
    }
  }

  // ─── Dark mode color setters ───

  Future<void> setDarkColor(String role, Color? color) async {
    _setDarkRole(role, color);
    await _saveColor('dark_$role', color);
    safeNotify();
  }

  // ─── Light mode color setters ───

  Future<void> setLightColor(String role, Color? color) async {
    _setLightRole(role, color);
    await _saveColor('light_$role', color);
    safeNotify();
  }

  /// Resets all dark mode colors to built-in defaults.
  Future<void> resetDarkColors() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'dark_bg', 'dark_surface', 'dark_surfaceVariant', 'dark_border',
      'dark_textPrimary', 'dark_textSecondary', 'dark_textTertiary',
      'dark_primary', 'dark_sidebarBg', 'dark_navActive',
      'dark_navActiveText', 'dark_navInactiveText',
    ]) {
      await prefs.remove(key);
    }
    _darkBackground = null;
    _darkSurface = null;
    _darkSurfaceVariant = null;
    _darkBorder = null;
    _darkTextPrimary = null;
    _darkTextSecondary = null;
    _darkTextTertiary = null;
    _darkPrimary = null;
    _darkSidebarBackground = null;
    _darkNavActive = null;
    _darkNavActiveText = null;
    _darkNavInactiveText = null;
    safeNotify();
  }

  /// Resets all light mode colors to built-in defaults.
  Future<void> resetLightColors() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      'light_bg', 'light_surface', 'light_surfaceVariant', 'light_border',
      'light_textPrimary', 'light_textSecondary', 'light_textTertiary',
      'light_primary', 'light_sidebarBg', 'light_navActive',
      'light_navActiveText', 'light_navInactiveText',
    ]) {
      await prefs.remove(key);
    }
    _lightBackground = null;
    _lightSurface = null;
    _lightSurfaceVariant = null;
    _lightBorder = null;
    _lightTextPrimary = null;
    _lightTextSecondary = null;
    _lightTextTertiary = null;
    _lightPrimary = null;
    _lightSidebarBackground = null;
    _lightNavActive = null;
    _lightNavActiveText = null;
    _lightNavInactiveText = null;
    safeNotify();
  }

  /// Applies a preset palette to dark mode colors.
  Future<void> applyDarkPreset(ColorPreset preset) async {
    final c = preset.darkColors;
    await setDarkColor('bg', c.background);
    await setDarkColor('surface', c.surface);
    await setDarkColor('surfaceVariant', c.surfaceVariant);
    await setDarkColor('border', c.border);
    await setDarkColor('textPrimary', c.textPrimary);
    await setDarkColor('textSecondary', c.textSecondary);
    await setDarkColor('textTertiary', c.textTertiary);
    await setDarkColor('primary', c.primary);
    await setDarkColor('sidebarBg', c.sidebarBackground);
    await setDarkColor('navActive', c.navItemActive);
    await setDarkColor('navActiveText', c.navItemActiveText);
    await setDarkColor('navInactiveText', c.navItemInactiveText);
  }

  /// Applies a preset palette to light mode colors.
  Future<void> applyLightPreset(ColorPreset preset) async {
    final c = preset.lightColors;
    await setLightColor('bg', c.background);
    await setLightColor('surface', c.surface);
    await setLightColor('surfaceVariant', c.surfaceVariant);
    await setLightColor('border', c.border);
    await setLightColor('textPrimary', c.textPrimary);
    await setLightColor('textSecondary', c.textSecondary);
    await setLightColor('textTertiary', c.textTertiary);
    await setLightColor('primary', c.primary);
    await setLightColor('sidebarBg', c.sidebarBackground);
    await setLightColor('navActive', c.navItemActive);
    await setLightColor('navActiveText', c.navItemActiveText);
    await setLightColor('navInactiveText', c.navItemInactiveText);
  }

  // ─── Nav order ───

  Future<void> _loadNavOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('navOrder');
    if (stored == null || stored.isEmpty) {
      _navOrder = List.of(NavPage.defaults);
      return;
    }
    final pages = <NavPage>[];
    for (final id in stored) {
      final page = NavPage.fromId(id);
      if (!pages.any((p) => p.id == page.id)) pages.add(page);
    }
    for (final page in NavPage.defaults) {
      if (!pages.any((p) => p.id == page.id)) pages.add(page);
    }
    _navOrder = pages;
  }

  Future<void> reorderNav(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= _navOrder.length) return;
    final page = _navOrder.removeAt(oldIndex);
    final clamped =
        newIndex < 0 ? 0 : (newIndex > _navOrder.length ? _navOrder.length : newIndex);
    _navOrder.insert(clamped, page);
    safeNotify();
    await _persistNavOrder();
  }

  Future<void> resetNavOrder() async {
    _navOrder = List.of(NavPage.defaults);
    safeNotify();
    await _persistNavOrder();
  }

  Future<void> _persistNavOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('navOrder', [for (final p in _navOrder) p.id]);
  }

  // ─── Categories ───

  Future<void> refreshCategories() async {
    _categoryList = await _categories.getAll();
    safeNotify();
  }

  Future<Category> addCategory(String name, {String color = 'primary'}) async {
    final id = await _categories.insert(Category(name: name, color: color));
    EventBus.instance.emit(AppEvent.categoriesChanged);
    await refreshCategories();
    return (await _categories.getById(id))!;
  }

  Future<Category> updateCategory(Category category) async {
    await _categories.update(category);
    EventBus.instance.emit(AppEvent.categoriesChanged);
    await refreshCategories();
    return (await _categories.getById(category.id!))!;
  }

  Future<void> deleteCategory(int id) async {
    await _categories.delete(id);
    EventBus.instance.emit(AppEvent.categoriesChanged);
    await refreshCategories();
  }

  Future<void> resetAllData() async {
    await AppDatabase.resetAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('startDateFilter');
    await prefs.remove('endDateFilter');
    await prefs.remove('user_name');
    await prefs.remove('v1_data_imported');
    await prefs.remove('recentSearches');
    EventBus.instance.emit(AppEvent.dataReset);
  }

  // ─── Preference helpers ───

  Future<bool> getNotificationEnabled(String key,
      {bool defaultValue = true}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? defaultValue;
  }

  Future<void> setNotificationEnabled(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    safeNotify();
  }
}

// ─── Color presets ───

/// A named color preset with both dark and light mode colors.
class ColorPreset {
  const ColorPreset({
    required this.name,
    required this.icon,
    required this.darkColors,
    required this.lightColors,
  });

  final String name;
  final IconData icon;
  final PresetColors darkColors;
  final PresetColors lightColors;

  static const List<ColorPreset> presets = [
    ColorPreset(
      name: 'Default',
      icon: Icons.palette_outlined,
      darkColors: PresetColors(
        background: Color(0xFF101022),
        surface: Color(0xFF0F172A),
        surfaceVariant: Color(0xFF1E293B),
        border: Color(0xFF1E293B),
        textPrimary: Color(0xFFF1F5F9),
        textSecondary: Color(0xFF94A3B8),
        textTertiary: Color(0xFF64748B),
        primary: Color(0xFF2e2ef4),
        sidebarBackground: Color(0x80101022),
        navItemActive: Color(0xFF1f1fba),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFF94A3B8),
      ),
      lightColors: PresetColors(
        background: Color(0xFFF8FAFC),
        surface: Color(0xFFFFFFFF),
        surfaceVariant: Color(0xFFF1F5F9),
        border: Color(0xFFE2E8F0),
        textPrimary: Color(0xFF1E293B),
        textSecondary: Color(0xFF64748B),
        textTertiary: Color(0xFF94A3B8),
        primary: Color(0xFF2e2ef4),
        sidebarBackground: Color(0xFFFFFFFF),
        navItemActive: Color(0xFF1f1fba),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFF64748B),
      ),
    ),
    ColorPreset(
      name: 'Ocean',
      icon: Icons.water_outlined,
      darkColors: PresetColors(
        background: Color(0xFF0A1929),
        surface: Color(0xFF0D2137),
        surfaceVariant: Color(0xFF132F4C),
        border: Color(0xFF1E4976),
        textPrimary: Color(0xFFE3F2FD),
        textSecondary: Color(0xFF90CAF9),
        textTertiary: Color(0xFF42A5F5),
        primary: Color(0xFF1976D2),
        sidebarBackground: Color(0x800A1929),
        navItemActive: Color(0xFF1565C0),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFF90CAF9),
      ),
      lightColors: PresetColors(
        background: Color(0xFFE3F2FD),
        surface: Color(0xFFFFFFFF),
        surfaceVariant: Color(0xFFBBDEFB),
        border: Color(0xFF90CAF9),
        textPrimary: Color(0xFF0D47A1),
        textSecondary: Color(0xFF1565C0),
        textTertiary: Color(0xFF42A5F5),
        primary: Color(0xFF1976D2),
        sidebarBackground: Color(0xFFFFFFFF),
        navItemActive: Color(0xFF1565C0),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFF1565C0),
      ),
    ),
    ColorPreset(
      name: 'Forest',
      icon: Icons.forest_outlined,
      darkColors: PresetColors(
        background: Color(0xFF1B2E1B),
        surface: Color(0xFF1E3A1E),
        surfaceVariant: Color(0xFF2D5A2D),
        border: Color(0xFF3E7A3E),
        textPrimary: Color(0xFFE8F5E9),
        textSecondary: Color(0xFFA5D6A7),
        textTertiary: Color(0xFF66BB6A),
        primary: Color(0xFF2E7D32),
        sidebarBackground: Color(0x801B2E1B),
        navItemActive: Color(0xFF388E3C),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFFA5D6A7),
      ),
      lightColors: PresetColors(
        background: Color(0xFFE8F5E9),
        surface: Color(0xFFFFFFFF),
        surfaceVariant: Color(0xFFC8E6C9),
        border: Color(0xFFA5D6A7),
        textPrimary: Color(0xFF1B5E20),
        textSecondary: Color(0xFF2E7D32),
        textTertiary: Color(0xFF66BB6A),
        primary: Color(0xFF2E7D32),
        sidebarBackground: Color(0xFFFFFFFF),
        navItemActive: Color(0xFF388E3C),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFF2E7D32),
      ),
    ),
    ColorPreset(
      name: 'Sunset',
      icon: Icons.wb_twilight_outlined,
      darkColors: PresetColors(
        background: Color(0xFF2D1B1B),
        surface: Color(0xFF3A2020),
        surfaceVariant: Color(0xFF5C3333),
        border: Color(0xFF8B4D4D),
        textPrimary: Color(0xFFFCE4EC),
        textSecondary: Color(0xFFEF9A9A),
        textTertiary: Color(0xFFE57373),
        primary: Color(0xFFE64A19),
        sidebarBackground: Color(0x802D1B1B),
        navItemActive: Color(0xFFD84315),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFFEF9A9A),
      ),
      lightColors: PresetColors(
        background: Color(0xFFFBE9E7),
        surface: Color(0xFFFFFFFF),
        surfaceVariant: Color(0xFFFFCCBC),
        border: Color(0xFFFFAB91),
        textPrimary: Color(0xFFBF360C),
        textSecondary: Color(0xFFD84315),
        textTertiary: Color(0xFFE57373),
        primary: Color(0xFFE64A19),
        sidebarBackground: Color(0xFFFFFFFF),
        navItemActive: Color(0xFFD84315),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFFD84315),
      ),
    ),
    ColorPreset(
      name: 'Purple',
      icon: Icons.auto_awesome_outlined,
      darkColors: PresetColors(
        background: Color(0xFF1A1025),
        surface: Color(0xFF221530),
        surfaceVariant: Color(0xFF35204A),
        border: Color(0xFF5A3D7A),
        textPrimary: Color(0xFFF3E5F5),
        textSecondary: Color(0xFFCE93D8),
        textTertiary: Color(0xFFAB47BC),
        primary: Color(0xFF7B1FA2),
        sidebarBackground: Color(0x801A1025),
        navItemActive: Color(0xFF6A1B9A),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFFCE93D8),
      ),
      lightColors: PresetColors(
        background: Color(0xFFF3E5F5),
        surface: Color(0xFFFFFFFF),
        surfaceVariant: Color(0xFFE1BEE7),
        border: Color(0xFFCE93D8),
        textPrimary: Color(0xFF4A148C),
        textSecondary: Color(0xFF6A1B9A),
        textTertiary: Color(0xFFAB47BC),
        primary: Color(0xFF7B1FA2),
        sidebarBackground: Color(0xFFFFFFFF),
        navItemActive: Color(0xFF6A1B9A),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFF6A1B9A),
      ),
    ),
    ColorPreset(
      name: 'Amber',
      icon: Icons.light_mode_outlined,
      darkColors: PresetColors(
        background: Color(0xFF2D2615),
        surface: Color(0xFF3A3018),
        surfaceVariant: Color(0xFF5C4A20),
        border: Color(0xFF8B7230),
        textPrimary: Color(0xFFFFF8E1),
        textSecondary: Color(0xFFFFE082),
        textTertiary: Color(0xFFFFD54F),
        primary: Color(0xFFF9A825),
        sidebarBackground: Color(0x802D2615),
        navItemActive: Color(0xFFF57F17),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFFFFE082),
      ),
      lightColors: PresetColors(
        background: Color(0xFFFFFDE7),
        surface: Color(0xFFFFFFFF),
        surfaceVariant: Color(0xFFFFF9C4),
        border: Color(0xFFFFF176),
        textPrimary: Color(0xFFF57F17),
        textSecondary: Color(0xFFF9A825),
        textTertiary: Color(0xFFFFD54F),
        primary: Color(0xFFF9A825),
        sidebarBackground: Color(0xFFFFFFFF),
        navItemActive: Color(0xFFF57F17),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFFF57F17),
      ),
    ),
    ColorPreset(
      name: 'KelamBis',
      icon: Icons.contrast,
      darkColors: PresetColors(
        background: Color(0xFF0A0A0A),
        surface: Color(0xFF141414),
        surfaceVariant: Color(0xFF1F1F1F),
        border: Color(0xFF2E2E2E),
        textPrimary: Color(0xFFF5F5F5),
        textSecondary: Color(0xFFA3A3A3),
        textTertiary: Color(0xFF6B6B6B),
        primary: Color(0xFF3F3F3F),
        sidebarBackground: Color(0x800A0A0A),
        navItemActive: Color(0xFF3F3F3F),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFFA3A3A3),
      ),
      lightColors: PresetColors(
        background: Color(0xFFFAFAFA),
        surface: Color(0xFFFFFFFF),
        surfaceVariant: Color(0xFFE5E5E5),
        border: Color(0xFFD4D4D4),
        textPrimary: Color(0xFF0A0A0A),
        textSecondary: Color(0xFF525252),
        textTertiary: Color(0xFF8A8A8A),
        primary: Color(0xFF171717),
        sidebarBackground: Color(0xFFFFFFFF),
        navItemActive: Color(0xFF171717),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFF525252),
      ),
    ),
  ];
}

/// Flat container for a preset's color values.
class PresetColors {
  const PresetColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.primary,
    required this.sidebarBackground,
    required this.navItemActive,
    required this.navItemActiveText,
    required this.navItemInactiveText,
  });

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color primary;
  final Color sidebarBackground;
  final Color navItemActive;
  final Color navItemActiveText;
  final Color navItemInactiveText;
}
