import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_shell.dart';
import 'screens/splash_screen.dart';
import 'database/app_database.dart';
import 'database/v1_importer.dart';
import 'providers/analytics_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/projects_provider.dart';
import 'providers/routines_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/tasks_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/shortcuts_provider.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for Windows desktop SQLite support.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Open (and create if needed) the database so taskflow.db exists
  // on first launch.
  await AppDatabase.database;

  // One-time migration of v1 (task_recorder_pro.db) data, if present.
  await V1Importer().run();

  runApp(const TaskFlowApp());
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..initialize()),
        ChangeNotifierProvider(
            create: (_) => SettingsProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => TasksProvider()..initialize()),
        ChangeNotifierProvider(
            create: (_) => CalendarProvider()..initialize()),
        ChangeNotifierProvider(
            create: (_) => ProjectsProvider()..initialize()),
        ChangeNotifierProvider(
            create: (_) => RoutinesProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => FocusProvider()..initialize()),
        ChangeNotifierProvider(
            create: (_) => AnalyticsProvider()..initialize()),
        ChangeNotifierProvider(
            create: (_) => ShortcutsProvider()..initialize()),
      ],
      child: const _ThemeBuilder(),
    );
  }
}

/// A compact key capturing all properties that affect ThemeData.
class _ThemeKey {
  const _ThemeKey({
    required this.mode,
    required this.font,
    required this.darkColors,
    required this.lightColors,
  });

  final ThemeMode mode;
  final String font;
  final List<int?> darkColors;
  final List<int?> lightColors;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ThemeKey &&
          mode == other.mode &&
          font == other.font &&
          _listEquals(darkColors, other.darkColors) &&
          _listEquals(lightColors, other.lightColors);

  @override
  int get hashCode => Object.hash(mode, font, darkColors, lightColors);

  static bool _listEquals(List<int?> a, List<int?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Dedicated widget that only rebuilds MaterialApp when theme-relevant
/// properties change.  Unrelated SettingsProvider changes (sidebar order,
/// categories, notifications, etc.) are ignored here.
class _ThemeBuilder extends StatelessWidget {
  const _ThemeBuilder();

  @override
  Widget build(BuildContext context) {
    return Selector2<ThemeProvider, SettingsProvider, _ThemeKey>(
      selector: (_, theme, settings) => _ThemeKey(
        mode: theme.themeMode,
        font: settings.fontFamily,
        darkColors: [
          settings.darkBackground?.toARGB32(),
          settings.darkSurface?.toARGB32(),
          settings.darkSurfaceVariant?.toARGB32(),
          settings.darkBorder?.toARGB32(),
          settings.darkTextPrimary?.toARGB32(),
          settings.darkTextSecondary?.toARGB32(),
          settings.darkTextTertiary?.toARGB32(),
          settings.darkPrimary?.toARGB32(),
          settings.darkSidebarBackground?.toARGB32(),
          settings.darkNavActive?.toARGB32(),
          settings.darkNavActiveText?.toARGB32(),
          settings.darkNavInactiveText?.toARGB32(),
        ],
        lightColors: [
          settings.lightBackground?.toARGB32(),
          settings.lightSurface?.toARGB32(),
          settings.lightSurfaceVariant?.toARGB32(),
          settings.lightBorder?.toARGB32(),
          settings.lightTextPrimary?.toARGB32(),
          settings.lightTextSecondary?.toARGB32(),
          settings.lightTextTertiary?.toARGB32(),
          settings.lightPrimary?.toARGB32(),
          settings.lightSidebarBackground?.toARGB32(),
          settings.lightNavActive?.toARGB32(),
          settings.lightNavActiveText?.toARGB32(),
          settings.lightNavInactiveText?.toARGB32(),
        ],
      ),
      builder: (context, key, _) {
        final settings = context.read<SettingsProvider>();

        final darkTheme = AppTheme.darkTheme(
          background: settings.darkBackground,
          surface: settings.darkSurface,
          surfaceVariant: settings.darkSurfaceVariant,
          border: settings.darkBorder,
          textPrimary: settings.darkTextPrimary,
          textSecondary: settings.darkTextSecondary,
          textTertiary: settings.darkTextTertiary,
          primaryColor: settings.darkPrimary,
          sidebarBackground: settings.darkSidebarBackground,
          navActive: settings.darkNavActive,
          navActiveText: settings.darkNavActiveText,
          navInactiveText: settings.darkNavInactiveText,
          fontFamily: settings.fontFamily,
        );

        final lightTheme = AppTheme.lightTheme(
          background: settings.lightBackground,
          surface: settings.lightSurface,
          surfaceVariant: settings.lightSurfaceVariant,
          border: settings.lightBorder,
          textPrimary: settings.lightTextPrimary,
          textSecondary: settings.lightTextSecondary,
          textTertiary: settings.lightTextTertiary,
          primaryColor: settings.lightPrimary,
          sidebarBackground: settings.lightSidebarBackground,
          navActive: settings.lightNavActive,
          navActiveText: settings.lightNavActiveText,
          navInactiveText: settings.lightNavInactiveText,
          fontFamily: settings.fontFamily,
        );

        return MaterialApp(
          title: 'TaskFlow',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: key.mode,
          home: const _OnboardingGate(),
        );
      },
    );
  }
}

/// Checks SharedPreferences for the onboarding flag.
/// Shows SplashScreen on first launch, AppShell otherwise.
class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkOnboardingComplete(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // Loading: show a minimal splash while the DB initializes
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final complete = snapshot.data ?? false;
        if (!complete) {
          return const SplashScreen();
        }
        return const AppShell();
      },
    );
  }

  Future<bool> _checkOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_complete') ?? false;
  }
}
