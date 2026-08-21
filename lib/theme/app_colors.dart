import 'package:flutter/material.dart';

/// Centralized color palette for dark & light themes.
///
/// To modify the look of any element, simply change the color value
/// in the corresponding factory constructor below.
///
/// Usage in widgets:
///   `final colors = Theme.of(context).extension<AppThemeColors>()!;`
///   `Container(color: colors.surface)`
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  // ─── Core surfaces ───
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;

  // ─── Text ───
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // ─── Sidebar ───
  final Color sidebarBackground;
  final Color navItemActive;
  final Color navItemActiveText;
  final Color navItemInactiveText;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.sidebarBackground,
    required this.navItemActive,
    required this.navItemActiveText,
    required this.navItemInactiveText,
  });

  // ════════════════════════════════════════════
  //  DARK THEME — edit values here
  // ════════════════════════════════════════════
  factory AppThemeColors.dark() => const AppThemeColors(
        background: Color(0xFF101022),
        surface: Color(0xFF0F172A),
        surfaceVariant: Color(0xFF1E293B),
        border: Color(0xFF1E293B),
        textPrimary: Color(0xFFF1F5F9),
        textSecondary: Color(0xFF94A3B8),
        textTertiary: Color(0xFF64748B),
        sidebarBackground: Color(0x80101022), // 50% opacity
        navItemActive: Color(0xFF1f1fba),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFF94A3B8),
      );

  // ════════════════════════════════════════════
  //  LIGHT THEME — edit values here
  // ════════════════════════════════════════════
  factory AppThemeColors.light() => const AppThemeColors(
        background: Color(0xFFF8FAFC),
        surface: Color(0xFFFFFFFF),
        surfaceVariant: Color(0xFFF1F5F9),
        border: Color(0xFFE2E8F0),
        textPrimary: Color(0xFF1E293B),
        textSecondary: Color(0xFF64748B),
        textTertiary: Color(0xFF94A3B8),
        sidebarBackground: Color(0xFFFFFFFF),
        navItemActive: Color(0xFF1f1fba),
        navItemActiveText: Colors.white,
        navItemInactiveText: Color(0xFF64748B),
      );

  @override
  AppThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? sidebarBackground,
    Color? navItemActive,
    Color? navItemActiveText,
    Color? navItemInactiveText,
  }) {
    return AppThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      navItemActive: navItemActive ?? this.navItemActive,
      navItemActiveText: navItemActiveText ?? this.navItemActiveText,
      navItemInactiveText: navItemInactiveText ?? this.navItemInactiveText,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      sidebarBackground:
          Color.lerp(sidebarBackground, other.sidebarBackground, t)!,
      navItemActive: Color.lerp(navItemActive, other.navItemActive, t)!,
      navItemActiveText:
          Color.lerp(navItemActiveText, other.navItemActiveText, t)!,
      navItemInactiveText:
          Color.lerp(navItemInactiveText, other.navItemInactiveText, t)!,
    );
  }
}
