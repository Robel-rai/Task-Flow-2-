import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'widgets/splash_page.dart';
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
import 'services/auto_backup_service.dart';
import 'theme/app_theme.dart';


// -- Single-instance enforcement via Win32 named mutex --
final ffi.DynamicLibrary _kernel32 = ffi.DynamicLibrary.open('kernel32.dll');

typedef CreateMutexNative = ffi.Pointer<ffi.NativeType> Function(
    ffi.Pointer<ffi.NativeType>, ffi.Bool, ffi.Pointer<Utf16>);
typedef CreateMutexDart = ffi.Pointer<ffi.NativeType> Function(
    ffi.Pointer<ffi.NativeType>, bool, ffi.Pointer<Utf16>);

typedef GetLastErrorNative = ffi.Int32 Function();
typedef GetLastErrorDart = int Function();

typedef CloseHandleNative = ffi.Bool Function(ffi.Pointer<ffi.NativeType>);
typedef CloseHandleDart = bool Function(ffi.Pointer<ffi.NativeType>);

final CreateMutexDart _createMutex =
    _kernel32.lookupFunction<CreateMutexNative, CreateMutexDart>('CreateMutexW');
final GetLastErrorDart _getLastError =
    _kernel32.lookupFunction<GetLastErrorNative, GetLastErrorDart>('GetLastError');
final CloseHandleDart _closeHandle =
    _kernel32.lookupFunction<CloseHandleNative, CloseHandleDart>('CloseHandle');

const int _errorAlreadyExists = 183;

bool _isAlreadyRunning() {
  final name = 'TaskFlow_SingleInstance'.toNativeUtf16();
  final mutex = _createMutex(ffi.nullptr, false, name);
  final error = _getLastError();
  calloc.free(name);
  if (mutex != ffi.nullptr) _closeHandle(mutex);
  return error == _errorAlreadyExists;
}

void main() async {
  if (_isAlreadyRunning()) exit(0);

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for Windows desktop SQLite support.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Open (and create if needed) the database so taskflow.db exists
  // on first launch.
  await AppDatabase.database;

  // One-time migration of v1 (task_recorder_pro.db) data, if present.
  await V1Importer().run();

  // Remove known ghost/test data that may have been imported from v1.
  await AppDatabase.cleanupGhostData();

  // Custom in-app title bar: hide the native one before the window is shown
  // (drag-to-move, snap, double-click maximize are handled by the app).
  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      titleBarStyle: TitleBarStyle.hidden,
    ),
    () async {
      await windowManager.setMinimumSize(const Size(960, 600));
      await windowManager.show();
      await windowManager.focus();
    },
  );

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
        ChangeNotifierProvider(
            create: (_) => AutoBackupService()..initialize()),
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
          home: const SplashPage(),
        );
      },
    );
  }
}


