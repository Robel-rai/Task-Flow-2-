import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:taskflow/components/settings/ui_sound_page.dart';
import 'package:taskflow/database/app_database.dart';
import 'package:taskflow/providers/settings_provider.dart';
import 'package:taskflow/services/ui_sound_service.dart';
import 'package:taskflow/theme/app_theme.dart';

import '../database/test_helpers.dart';

void main() {
  late FakeSoundBackend backend;
  late UiSoundService sounds;
  late Database testDb;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'user_name': 'Test User',
    });
    testDb = await createTestDb();
    AppDatabase.setDatabaseForTesting(testDb);
    backend = FakeSoundBackend();
    sounds = UiSoundService.instance..backend = backend;
    await sounds.loadPreferences(
      enabled: true,
      volume: 0.7,
      pack: UiSoundPack.minimal,
      focusEnabled: true,
      tasksEnabled: true,
      notificationsEnabled: true,
      loopEnabled: false,
    );
  });

  tearDown(() async {
    await testDb.close();
    AppDatabase.closeForTesting();
  });

  /// sqflite FFI queries need real async time inside testWidgets, so
  /// provider initialization runs under runAsync (repo convention).
  Future<SettingsProvider> makeProvider(WidgetTester tester) async {
    late SettingsProvider provider;
    await tester.runAsync(() async {
      provider = SettingsProvider();
      await provider.initialize();
    });
    return provider;
  }

  Widget harness(SettingsProvider settings) => MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme(fontFamily: 'Montserrat'),
          home: UiSoundPage(onBack: () {}),
        ),
      );

  /// The page is long; give the test surface room for every section.
  void useTallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Asserts a play call happened for [asset] with [volume] (to 3 dp,
  /// avoiding float-formatting mismatch in the recorded string).
  void expectPlayed(String asset, double volume) {
    final matches = backend.played
        .where((entry) => entry.startsWith('$asset@'))
        .map((entry) => double.parse(entry.split('@').last))
        .toList(growable: false);
    expect(matches, hasLength(1));
    expect(matches.single, closeTo(volume, 0.001));
  }

  testWidgets('renders all controls with defaults', (tester) async {
    useTallView(tester);
    final settings = await makeProvider(tester);

    await tester.pumpWidget(harness(settings));
    await tester.pump();

    expect(find.text('UI Sound & Customization'), findsOneWidget);
    expect(find.text('UI sounds'), findsOneWidget);
    expect(find.text('Sound Pack'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Preview Sounds'), findsOneWidget);

    // All 12 packs are offered, minimal selected by default.
    for (final pack in UiSoundPack.values) {
      expect(find.text(pack.label), findsOneWidget);
    }

    // Category switches + focus loop.
    expect(find.text('Focus timer'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Loop while focusing'), findsOneWidget);

    // Preview list. (The 'Task completed' label appears twice: the
    // preview row title and the cue's own label subtitle.)
    expect(find.text('Focus timer completed'), findsOneWidget);
    expect(find.text('Task completed'), findsWidgets);
    expect(find.text('Reminder fired'), findsOneWidget);

    // Attribution.
    expect(find.text('About the sounds'), findsOneWidget);

    // Master switch starts on.
    final master = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'UI sounds'));
    expect(master.value, isTrue);
  });

  testWidgets('toggling master off persists and disables dependent controls',
      (tester) async {
    useTallView(tester);
    final settings = await makeProvider(tester);

    await tester.pumpWidget(harness(settings));
    await tester.pump();

    await tester.tap(find.text('UI sounds'));
    await tester.pump();

    expect(settings.uiSoundEnabled, isFalse);
    expect(sounds.enabled, isFalse);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('uiSoundEnabled'), isFalse);

    // Dependent rows become disabled.
    final focusRow = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, 'Focus timer'));
    expect(focusRow.onChanged, isNull);
  });

  testWidgets('picking a pack persists it and previews the new pack',
      (tester) async {
    useTallView(tester);
    final settings = await makeProvider(tester);

    await tester.pumpWidget(harness(settings));
    await tester.pump();

    await tester.ensureVisible(find.text('Zen'));
    await tester.pump();
    await tester.tap(find.text('Zen'));
    await tester.pump();

    expect(settings.uiSoundPack, UiSoundPack.zen);
    expect(sounds.pack, UiSoundPack.zen);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('uiSoundPack'), 'zen');

    // The preview fired through the service with the new pack.
    expectPlayed('assets/sounds/zen/notification.mp3', 0.20 * 0.7);
  });

  testWidgets('preview rows play their cue through the service',
      (tester) async {
    useTallView(tester);
    final settings = await makeProvider(tester);

    await tester.pumpWidget(harness(settings));
    await tester.pump();

    await tester.ensureVisible(find.text('Focus timer completed'));
    await tester.pump();
    await tester.tap(find.text('Focus timer completed'));
    await tester.pump();

    expectPlayed('assets/sounds/minimal/complete.mp3', 0.24 * 0.7);
  });

  testWidgets('toggling the focus loop persists it', (tester) async {
    useTallView(tester);
    final settings = await makeProvider(tester);

    await tester.pumpWidget(harness(settings));
    await tester.pump();

    await tester.ensureVisible(find.text('Loop while focusing'));
    await tester.pump();
    await tester.tap(find.text('Loop while focusing'));
    await tester.pump();

    expect(settings.uiSoundLoopEnabled, isTrue);
    expect(sounds.loopEnabled, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('uiSoundLoopEnabled'), isTrue);
  });
}
