import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:taskflow/services/ui_sound_service.dart';

void main() {
  late FakeSoundBackend backend;
  late UiSoundService service;

  setUp(() async {
    backend = FakeSoundBackend();
    service = UiSoundService.instance..backend = backend;
    // Reset the singleton to defaults before each test.
    await service.loadPreferences(
      enabled: true,
      volume: 1.0,
      pack: UiSoundPack.minimal,
      focusEnabled: true,
      tasksEnabled: true,
      notificationsEnabled: true,
      loopEnabled: false,
    );
  });

  group('asset mapping', () {
    test('cues map to their pack folder and file name', () {
      expect(UiSoundCue.check.assetFor('minimal'),
          'assets/sounds/minimal/check.mp3');
      expect(UiSoundCue.complete.assetFor('arcade'),
          'assets/sounds/arcade/complete.mp3');
      expect(UiSoundCue.processing.assetFor('zen'),
          'assets/sounds/zen/processing.mp3');
    });

    test('every pack exposes every cue (semantic contract)', () {
      for (final pack in UiSoundPack.values) {
        for (final cue in UiSoundCue.values) {
          expect(cue.assetFor(pack.id), endsWith('.mp3'));
          expect(cue.assetFor(pack.id), contains('/${pack.id}/'));
        }
      }
    });

    test('only the processing cue is a loop', () {
      for (final cue in UiSoundCue.values) {
        expect(cue.isLoop, cue == UiSoundCue.processing);
      }
    });

    test('backend strips the bundle prefix for audioplayers', () {
      // audioplayers prepends `assets/` itself; passing the full bundle
      // path would make it look for `assets/assets/...`.
      expect(
        AssetSoundBackend.stripBundlePrefix('assets/sounds/minimal/check.mp3'),
        'sounds/minimal/check.mp3',
      );
      expect(
        AssetSoundBackend.stripBundlePrefix('sounds/minimal/check.mp3'),
        'sounds/minimal/check.mp3',
      );
    });

    test('pack lookup falls back to minimal for unknown ids', () {
      expect(UiSoundPack.fromId('zen'), UiSoundPack.zen);
      expect(UiSoundPack.fromId('nope'), UiSoundPack.minimal);
      expect(UiSoundPack.fromId(null), UiSoundPack.minimal);
    });
  });

  group('gating', () {
    test('master off silences every cue', () {
      service.setEnabled(false);
      service.play(UiSoundCue.check, category: UiSoundCategory.tasks);
      expect(backend.played, isEmpty);
    });

    test('disabled category silences its cues but not others', () {
      service.setCategoryEnabled(UiSoundCategory.tasks, false);
      service.play(UiSoundCue.check, category: UiSoundCategory.tasks);
      expect(backend.played, isEmpty);

      service.play(UiSoundCue.start, category: UiSoundCategory.focus);
      expect(backend.played, hasLength(1));
    });

    test('uncategorized cues respect only the master switch', () {
      service.setCategoryEnabled(UiSoundCategory.tasks, false);
      service.play(UiSoundCue.success);
      expect(backend.played, hasLength(1));
    });

    test('volume 0 mutes playback entirely', () {
      service.setVolume(0);
      service.play(UiSoundCue.check);
      expect(backend.played, isEmpty);
    });
  });

  group('volume scaling', () {
    test('master volume scales the cue default volume', () {
      service.setVolume(0.5);
      service.play(UiSoundCue.check, category: UiSoundCategory.tasks);
      final played = backend.played.single;
      final volume = double.parse(played.split('@').last);
      expect(volume, closeTo(0.17 * 0.5, 0.001));
    });

    test('result is clamped to 1.0', () {
      service.setVolume(1.0);
      service.play(UiSoundCue.complete, category: UiSoundCategory.focus);
      final volume =
          double.parse(backend.played.single.split('@').last);
      expect(volume, lessThanOrEqualTo(1.0));
      expect(volume, closeTo(0.24, 0.001));
    });
  });

  group('rate limiting', () {
    test('duplicate cues within the window are dropped', () {
      service.play(UiSoundCue.check, category: UiSoundCategory.tasks);
      service.play(UiSoundCue.check, category: UiSoundCategory.tasks);
      expect(backend.played, hasLength(1));
    });

    test('different cues are not rate-limited against each other', () {
      service.play(UiSoundCue.check, category: UiSoundCategory.tasks);
      service.play(UiSoundCue.send, category: UiSoundCategory.tasks);
      expect(backend.played, hasLength(2));
    });

    test('stopAll clears the rate-limit memory', () {
      service.play(UiSoundCue.check, category: UiSoundCategory.tasks);
      service.stopAll();
      service.play(UiSoundCue.check, category: UiSoundCategory.tasks);
      expect(backend.played, hasLength(2));
    });
  });

  group('loops', () {
    test('startLoop is a no-op when the loop preference is off', () {
      service.focusStarted();
      expect(backend.loopActive, isFalse);
      expect(backend.loopAsset, isNull);
    });

    test('focusStarted starts the loop when opted in', () async {
      await service.loadPreferences(
        enabled: true,
        volume: 1.0,
        pack: UiSoundPack.minimal,
        focusEnabled: true,
        tasksEnabled: true,
        notificationsEnabled: true,
        loopEnabled: true,
      );
      service.focusStarted();
      expect(backend.loopActive, isTrue);
      expect(backend.loopAsset, 'assets/sounds/minimal/processing.mp3');
    });

    test('startLoop is deduplicated while already active', () async {
      await service.loadPreferences(
        enabled: true,
        volume: 1.0,
        pack: UiSoundPack.minimal,
        focusEnabled: true,
        tasksEnabled: true,
        notificationsEnabled: true,
        loopEnabled: true,
      );
      service.startLoop();
      service.startLoop();
      service.startLoop();
      expect(backend.loopActive, isTrue);
    });

    test('focusCompleted stops the loop and plays the completion cue',
        () async {
      await service.loadPreferences(
        enabled: true,
        volume: 1.0,
        pack: UiSoundPack.minimal,
        focusEnabled: true,
        tasksEnabled: true,
        notificationsEnabled: true,
        loopEnabled: true,
      );
      service.focusStarted();
      service.focusCompleted();
      expect(backend.loopActive, isFalse);
      expect(
          backend.played.any((p) => p.startsWith('assets/sounds/minimal/complete.mp3')),
          isTrue);
    });

    test('disabling the loop preference stops a running loop', () async {
      await service.loadPreferences(
        enabled: true,
        volume: 1.0,
        pack: UiSoundPack.minimal,
        focusEnabled: true,
        tasksEnabled: true,
        notificationsEnabled: true,
        loopEnabled: true,
      );
      service.startLoop();
      service.setLoopEnabled(false);
      expect(backend.loopActive, isFalse);
    });
  });

  group('convenience hooks', () {
    test('focus lifecycle plays the right cues', () {
      service.focusStarted();
      service.focusPaused();
      service.focusResumed();
      service.focusStopped();
      final assets = backend.played.map((p) => p.split('@').first).toList();
      expect(assets, [
        'assets/sounds/minimal/start.mp3',
        'assets/sounds/minimal/pause.mp3',
        'assets/sounds/minimal/play.mp3',
        'assets/sounds/minimal/stop.mp3',
      ]);
    });

    test('task hooks route through the tasks category', () {
      service.setCategoryEnabled(UiSoundCategory.tasks, false);
      service.taskCompleted();
      service.taskSaved();
      service.taskDeleted();
      service.dataRestored();
      expect(backend.played, isEmpty);
    });

    test('reminder hook routes through the notifications category', () {
      service.setCategoryEnabled(UiSoundCategory.notifications, false);
      service.reminderFired();
      expect(backend.played, isEmpty);

      service.setCategoryEnabled(UiSoundCategory.notifications, true);
      service.reminderFired();
      expect(backend.played.single,
          startsWith('assets/sounds/minimal/notification.mp3'));
    });
  });

  group('VolumeFader (focus loop fade-in)', () {
    late List<double> volumes;
    late VolumeFader fader;

    setUp(() {
      volumes = [];
      fader = VolumeFader();
    });

    test('starts silent, ends at target after exactly 2 seconds', () {
      fakeAsync((async) {
        fader.start(
          setVolume: (v) async => volumes.add(v),
          targetVolume: 0.08,
        );
        // Silence is applied synchronously — the loop is muted from the
        // very first moment, before any timer tick.
        expect(volumes, [0.0]);

        async.elapse(VolumeFader.duration);
        expect(volumes.last, 0.08);
        expect(volumes, hasLength(VolumeFader.stepCount + 1));
        // The whole ramp took exactly the fade duration — no overrun.
        expect(async.elapsed, VolumeFader.duration);
      });
    });

    test('ramps monotonically through small intermediate steps', () {
      fakeAsync((async) {
        fader.start(
          setVolume: (v) async => volumes.add(v),
          targetVolume: 0.5,
        );
        async.elapse(VolumeFader.duration);

        expect(volumes.first, 0.0);
        for (var i = 1; i < volumes.length; i++) {
          expect(volumes[i], greaterThan(volumes[i - 1]),
              reason: 'volume must increase at step $i');
        }
        // Roughly linear: step k ≈ target · k / steps.
        final mid = volumes[volumes.length ~/ 2];
        expect(mid, closeTo(0.25, 0.05));
      });
    });

    test('stop() mid-fade halts the ramp immediately', () {
      fakeAsync((async) {
        fader.start(
          setVolume: (v) async => volumes.add(v),
          targetVolume: 0.5,
        );
        async.elapse(const Duration(seconds: 1)); // half-way
        expect(volumes, isNotEmpty);
        final countAtStop = volumes.length;

        fader.stop();
        async.elapse(const Duration(seconds: 3)); // far past the fade end
        expect(volumes, hasLength(countAtStop));
        expect(volumes.last, lessThan(0.5),
            reason: 'never reached the target after cancel');
      });
    });

    test('starting a new fade cancels the previous one', () {
      fakeAsync((async) {
        final first = <double>[];
        final second = <double>[];
        fader.start(setVolume: (v) async => first.add(v), targetVolume: 0.5);
        async.elapse(const Duration(milliseconds: 300));
        final firstCount = first.length;

        fader.start(setVolume: (v) async => second.add(v), targetVolume: 0.2);
        async.elapse(VolumeFader.duration);

        expect(first, hasLength(firstCount)); // old ramp dead
        expect(second.last, 0.2); // new ramp completed
      });
    });

    test('non-positive target never schedules a ramp', () {
      fakeAsync((async) {
        fader.start(setVolume: (v) async => volumes.add(v), targetVolume: 0);
        async.elapse(VolumeFader.duration);
        expect(volumes, isEmpty);
      });
    });

    test('a failing setVolume does not crash the fader', () {
      fakeAsync((async) {
        fader.start(
          setVolume: (_) async => throw Exception('player gone'),
          targetVolume: 0.5,
        );
        expect(
          () => async.elapse(VolumeFader.duration),
          returnsNormally,
        );
      });
    });
  });

  group('loadPreferences', () {
    test('mirrors category flags and disables loops when master is off',
        () async {
      await service.loadPreferences(
        enabled: false,
        volume: 0.3,
        pack: UiSoundPack.zen,
        focusEnabled: false,
        tasksEnabled: true,
        notificationsEnabled: true,
        loopEnabled: true,
      );
      expect(service.enabled, isFalse);
      expect(service.volume, 0.3);
      expect(service.pack, UiSoundPack.zen);
      expect(service.isCategoryEnabled(UiSoundCategory.focus), isFalse);
      expect(service.isCategoryEnabled(UiSoundCategory.tasks), isTrue);
      expect(service.loopEnabled, isTrue); // preference mirrored as-is
      service.play(UiSoundCue.check);
      expect(backend.played, isEmpty); // master switch wins
    });
  });
}
