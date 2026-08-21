import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static const Color primary = Color(0xFF2e2ef4);
  static const Color backgroundDark = Color(0xFF101022);
  static const Color surfaceDark = Color(0xFF0F172A); // slate-900
  static const Color borderDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF1F5F9); // slate-100
  static const Color textSecondaryDark = Color(0xFF94A3B8); // slate-400
  static const Color textTertiaryDark = Color(0xFF64748B); // slate-500

  // Status colors
  static const Color emerald = Color(0xFF10B981);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFF43F5E);
  static const Color blue = Color(0xFF3B82F6);
  static const Color indigo = Color(0xFF6366F1);
  static const Color purple = Color(0xFFA855F7);
  static const Color sky = Color(0xFF38BDF8);
  static const Color orange = Color(0xFFF97316);

  // Routine colors
  static const Map<String, Color> routineColors = {
    'primary': primary,
    'indigo': indigo,
    'sky': sky,
    'purple': purple,
    'amber': amber,
    'emerald': emerald,
    'rose': rose,
    'blue': blue,
    'orange': orange,
    'slate': textSecondaryDark,
  };

  /// Resolves a stored color string to a [Color]. Accepts either a
  /// [routineColors] preset key or a `#RRGGBB`/`#RRGGBBAA` hex value
  /// (custom colors picked from the color wheel). Falls back to [primary].
  static Color getRoutineColor(String name) {
    final preset = routineColors[name];
    if (preset != null) return preset;
    final parsed = _parseHexColor(name);
    if (parsed != null) return parsed;
    return primary;
  }

  static Color? _parseHexColor(String value) {
    var hex = value.trim();
    if (hex.startsWith('#')) hex = hex.substring(1);
    if (hex.length != 6 && hex.length != 8) return null;
    final intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) return null;
    return Color(hex.length == 8 ? intValue : (0xFF000000 | intValue));
  }

  /// Parses a hex color string (#RRGGBB or #RRGGBBAA) into a [Color].
  static Color? parseColor(String hex) => _parseHexColor(hex);

  /// Formats a [Color] as an uppercase `#RRGGBB` string for storage.
  static String colorToHex(Color color) {
    final argb = color.toARGB32();
    return '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  // Priority colors
  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return rose;
      case 'medium':
        return amber;
      case 'low':
        return emerald;
      default:
        return textSecondaryDark;
    }
  }

  // Status colors
  static Color getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return emerald;
      case 'In Progress':
        return blue;
      case 'Pending':
        return textSecondaryDark;
      default:
        return textSecondaryDark;
    }
  }

  /// Returns the dark [ThemeData], optionally with custom color overrides.
  static ThemeData darkTheme({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primaryColor,
    Color? sidebarBackground,
    Color? navActive,
    Color? navActiveText,
    Color? navInactiveText,
    String fontFamily = 'Montserrat',
  }) {
    final bg = background ?? backgroundDark;
    final sf = surface ?? surfaceDark;
    final sfv = surfaceVariant ?? borderDark;
    final bd = border ?? borderDark;
    final tp = textPrimary ?? textPrimaryDark;
    final ts = textSecondary ?? textSecondaryDark;
    final tt = textTertiary ?? textTertiaryDark;
    final pc = primaryColor ?? primary;

    return ThemeData(
      extensions: [
        AppThemeColors(
          background: bg,
          surface: sf,
          surfaceVariant: sfv,
          border: bd,
          textPrimary: tp,
          textSecondary: ts,
          textTertiary: tt,
          sidebarBackground: sidebarBackground ?? const Color(0x80101022),
          navItemActive: navActive ?? const Color(0xFF1f1fba),
          navItemActiveText: navActiveText ?? Colors.white,
          navItemInactiveText: navInactiveText ?? ts,
        ),
      ],
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: bg,
      primaryColor: pc,
      colorScheme: ColorScheme.dark(
        primary: pc,
        surface: bg,
        onSurface: tp,
        onPrimary: Colors.white,
        outline: bd,
      ),
      cardTheme: CardThemeData(
        color: sf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: bd),
        ),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg.withValues(alpha: 0.8),
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: tp,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: sf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pc, width: 2),
        ),
        hintStyle: TextStyle(color: ts, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pc,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: bd,
        thickness: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: tp),
        headlineMedium: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: tp),
        titleLarge: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: tp),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: tp),
        bodyLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400, color: tp),
        bodyMedium: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w400, color: ts),
        bodySmall: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w400, color: tt),
        labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tt,
            letterSpacing: 1.2),
      ),
    );
  }

  // ─── Light Theme ───
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF1F5F9);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF1E293B);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  /// Returns the light [ThemeData], optionally with custom color overrides.
  static ThemeData lightTheme({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? primaryColor,
    Color? sidebarBackground,
    Color? navActive,
    Color? navActiveText,
    Color? navInactiveText,
    String fontFamily = 'Montserrat',
  }) {
    final bg = background ?? backgroundLight;
    final sf = surface ?? surfaceLight;
    final sfv = surfaceVariant ?? surfaceVariantLight;
    final bd = border ?? borderLight;
    final tp = textPrimary ?? textPrimaryLight;
    final ts = textSecondary ?? textSecondaryLight;
    final tt = textTertiary ?? textTertiaryLight;
    final pc = primaryColor ?? primary;

    return ThemeData(
      extensions: [
        AppThemeColors(
          background: bg,
          surface: sf,
          surfaceVariant: sfv,
          border: bd,
          textPrimary: tp,
          textSecondary: ts,
          textTertiary: tt,
          sidebarBackground: sidebarBackground ?? Colors.white,
          navItemActive: navActive ?? const Color(0xFF1f1fba),
          navItemActiveText: navActiveText ?? Colors.white,
          navItemInactiveText: navInactiveText ?? textSecondaryLight,
        ),
      ],
      brightness: Brightness.light,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: bg,
      primaryColor: pc,
      colorScheme: ColorScheme.light(
        primary: pc,
        surface: bg,
        onSurface: tp,
        onPrimary: Colors.white,
        outline: bd,
      ),
      cardTheme: CardThemeData(
        color: sf,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: bd),
        ),
        elevation: 0,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg.withValues(alpha: 0.95),
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          color: tp,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: sfv,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: pc, width: 2),
        ),
        hintStyle: TextStyle(color: ts, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: pc,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: bd,
        thickness: 1,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: tp),
        headlineMedium: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: tp),
        titleLarge: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w700, color: tp),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: tp),
        bodyLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w400, color: tp),
        bodyMedium: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w400, color: ts),
        bodySmall: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w400, color: tt),
        labelSmall: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: tt,
            letterSpacing: 1.2),
      ),
    );
  }

  static bool isScreenCollapsed(BuildContext context) {
    final windowWidth = MediaQuery.of(context).size.width;
    double screenWidth = 1920.0;
    try {
      final displays = WidgetsBinding.instance.platformDispatcher.displays;
      if (displays.isNotEmpty) {
        screenWidth =
            displays.first.size.width / displays.first.devicePixelRatio;
      }
    } catch (_) {}
    return windowWidth <= screenWidth * 0.6;
  }
}
