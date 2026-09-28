import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taskflow/models/tag.dart';
import 'package:taskflow/providers/settings_provider.dart';
import 'package:taskflow/theme/app_colors.dart';
import 'package:taskflow/theme/app_theme.dart';
import 'package:taskflow/widgets/tag_pill.dart';

Widget _host(Widget child, {Color? primary, bool dark = true}) {
  final theme = dark
      ? AppTheme.darkTheme(primaryColor: primary)
      : AppTheme.lightTheme(primaryColor: primary);
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('theme-follow primary accent', () {
    test('AppThemeColors exposes primary and follows the custom color', () {
      final dark = AppTheme.darkTheme(primaryColor: const Color(0xFFE91E63))
          .extension<AppThemeColors>()!;
      expect(dark.primary, const Color(0xFFE91E63));

      final light = AppTheme.lightTheme(primaryColor: const Color(0xFF00897B))
          .extension<AppThemeColors>()!;
      expect(light.primary, const Color(0xFF00897B));
    });

    test('default primary stays the original blue', () {
      expect(AppThemeColors.dark().primary, const Color(0xFF2e2ef4));
      expect(AppThemeColors.light().primary, const Color(0xFF2e2ef4));
      expect(AppTheme.darkTheme().extension<AppThemeColors>()!.primary,
          const Color(0xFF2e2ef4));
      expect(AppTheme.lightTheme().extension<AppThemeColors>()!.primary,
          const Color(0xFF2e2ef4));
    });

    testWidgets('selected tag pill outline follows the custom accent',
        (tester) async {
      const accent = Color(0xFFE91E63);
      await tester.pumpWidget(_host(
        TagPill(tag: Tag(name: 'urgent'), selected: true),
        primary: accent,
      ));

      final material = tester.widget<Material>(
        find
            .descendant(of: find.byType(TagPill), matching: find.byType(Material))
            .first,
      );
      final shape = material.shape! as StadiumBorder;
      expect(shape.side.color, accent);
    });
  });

  group('personal theme', () {
    test('save snapshots effective colors (defaults when unset)', () async {
      final settings = SettingsProvider();
      expect(settings.hasPersonalDarkTheme, isFalse);

      await settings.savePersonalTheme(darkMode: true);

      expect(settings.hasPersonalDarkTheme, isTrue);
      expect(
        settings.personalDarkColor('bg'),
        SettingsProvider.defaultForRole('bg', true),
      );
      expect(settings.personalDarkColor('primary'), const Color(0xFF2e2ef4));
    });

    test('apply restores saved colors after a reset', () async {
      final settings = SettingsProvider();
      const orange = Color(0xFFF97316);
      await settings.setDarkColor('primary', orange);
      await settings.setDarkColor('bg', const Color(0xFF111111));
      await settings.savePersonalTheme(darkMode: true);

      await settings.resetDarkColors();
      expect(settings.darkPrimary, isNull);

      await settings.applyPersonalTheme(darkMode: true);
      expect(settings.darkPrimary, orange);
      expect(settings.darkBackground, const Color(0xFF111111));
    });

    test('dark and light snapshots are stored independently', () async {
      final settings = SettingsProvider();
      await settings.setLightColor('primary', const Color(0xFF00897B));
      await settings.savePersonalTheme(darkMode: false);

      expect(settings.hasPersonalLightTheme, isTrue);
      expect(settings.hasPersonalDarkTheme, isFalse);
      expect(settings.personalLightColor('primary'), const Color(0xFF00897B));
    });

    test('snapshot persists to SharedPreferences', () async {
      final settings = SettingsProvider();
      await settings.savePersonalTheme(darkMode: true);
      await settings.savePersonalTheme(darkMode: false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('personalThemeDark'), isNotNull);
      expect(prefs.getString('personalThemeLight'), isNotNull);
    });

    test('delete removes the snapshot without touching active colors',
        () async {
      final settings = SettingsProvider();
      const orange = Color(0xFFF97316);
      await settings.setDarkColor('primary', orange);
      await settings.savePersonalTheme(darkMode: true);

      await settings.deletePersonalTheme(darkMode: true);

      expect(settings.hasPersonalDarkTheme, isFalse);
      expect(settings.darkPrimary, orange);
    });

    test('apply with no snapshot is a safe no-op', () async {
      final settings = SettingsProvider();
      await settings.applyPersonalTheme(darkMode: true);
      expect(settings.darkPrimary, isNull);
      expect(settings.hasPersonalDarkTheme, isFalse);
    });
  });
}
