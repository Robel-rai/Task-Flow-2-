import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Semantic UI sound cues, mapped 1:1 to sound files from
/// [UI SFX](https://github.com/romainsimon/uisfx) (CC0 audio, MIT code).
///
/// Cues are **semantic**: the app event stays stable while the timbre
/// changes with the selected sound pack. Sounds are used only to give
/// instant feedback, confirm user actions, and indicate ongoing states —
/// never as decoration.
enum UiSoundCue {
  /// A process, recording, or session begins. (Focus session started.)
  start('start', 'Session started'),

  /// A multi-step process reaches its final state. (Focus timer hit its
  /// target duration.)
  complete('complete', 'Timer completed'),

  /// A process or session ends early. (Focus session stopped by user.)
  stop('stop', 'Session stopped'),

  /// Media playback begins or resumes. (Focus session resumed.)
  play('play', 'Session resumed'),

  /// Media playback pauses. (Focus session paused.)
  pause('pause', 'Session paused'),

  /// A restrained repeating bed while sustained work is running.
  /// (Optional loop during an active focus session.)
  processing('processing', 'Ongoing focus', isLoop: true),

  /// A checkbox or task enters its completed state. (Task completed.)
  check('check', 'Task completed'),

  /// A message or object leaves the user. (Task created / saved.)
  send('send', 'Task saved'),

  /// A destructive removal is committed. (Task deleted / trashed.)
  delete('delete', 'Task deleted'),

  /// An action finished with the expected result. (Backup restored,
  /// bulk operations.)
  success('success', 'Action succeeded'),

  /// New information is available, without urgency. (Reminder popups
  /// and toasts.)
  notification('notification', 'Reminder');

  const UiSoundCue(this.file, this.label, {this.isLoop = false});

  /// File name inside `assets/sounds/{pack}/` (without extension).
  final String file;

  /// Human-readable label for the preview list on the settings page.
  final String label;

  final bool isLoop;

  /// Default per-cue volume from the uisfx manifest; scales under the
  /// user's master volume so quiet cues (loops) stay quiet.
  double get defaultVolume => switch (this) {
        UiSoundCue.start => 0.19,
        UiSoundCue.complete => 0.24,
        UiSoundCue.stop => 0.19,
        UiSoundCue.play => 0.18,
        UiSoundCue.pause => 0.17,
        UiSoundCue.processing => 0.08,
        UiSoundCue.check => 0.17,
        UiSoundCue.send => 0.20,
        UiSoundCue.delete => 0.22,
        UiSoundCue.success => 0.23,
        UiSoundCue.notification => 0.20,
      };

  /// Asset path for [pack], e.g. `assets/sounds/minimal/check.mp3`.
  String assetFor(String pack) => 'assets/sounds/$pack/$file.mp3';
}

/// One of the 12 coherent uisfx sonic personalities. Every pack
/// implements every cue, so switching packs never changes app logic.
enum UiSoundPack {
  minimal('minimal', 'Minimal', 'Dry, precise, almost invisible.',
      'Productivity, SaaS, system UI'),
  soft('soft', 'Soft', 'Rounded felt, warm and reassuring.',
      'Mobile, wellness, friendly SaaS'),
  glass('glass', 'Glass', 'Bright, crystalline, and premium.',
      'Media, finance, luxury products'),
  arcade('arcade', 'Arcade', 'Chunky pixels and cheerful voltage.',
      'Games, streaks, gamified learning'),
  mechanical('mechanical', 'Mechanical', 'Switches, relays, and firm detents.',
      'Devtools, hardware, industrial UI'),
  organic('organic', 'Organic', 'Wood, water, breath, and small stones.',
      'Education, kids, calm games'),
  dreamy('dreamy', 'Dreamy', 'Airy blooms, soft light, and slow sparkle.',
      'Creative tools, wellness, ambient apps'),
  scifi('scifi', 'Sci-fi',
      'Clean holographic pings with a restrained digital shimmer.',
      'AI tools, spatial UI, futuristic games'),
  rubber('rubber', 'Rubber',
      'Tactile elastic taps with a quick, friendly rebound.',
      'Kids, playful mobile, casual games'),
  cinematic('cinematic', 'Cinematic',
      'Deep impacts, polished tails, and quiet scale.',
      'Premium media, games, dramatic moments'),
  studio('studio', 'Studio',
      'Tactile editing precision with warm cinematic restraint.',
      'Film, audio, and AI creative tools'),
  zen('zen', 'Zen', 'Pure tones, dry wood, and brief washi detail.',
      'Mindfulness, reading, writing, calm productivity');

  const UiSoundPack(this.id, this.label, this.description, this.bestFor);

  final String id;
  final String label;
  final String description;
  final String bestFor;

  static UiSoundPack fromId(String? id) => UiSoundPack.values.firstWhere(
        (p) => p.id == id,
        orElse: () => UiSoundPack.minimal,
      );
}

/// Which event group a cue belongs to — the per-category switches on the
/// "UI Sound & Customization" page gate these groups independently.
enum UiSoundCategory { focus, tasks, notifications }

/// Minimal playback contract so the service is testable without the
/// audioplayers plugin. The real backend plays asset files; the fake
/// backend records calls for assertions.
abstract class SoundBackend {
  Future<void> playAsset(String asset, {required double volume});

  /// Starts an asset on repeat; returns the loop handle used by
  /// [SoundBackend.stopLoop].
  Future<void> startLoopAsset(String asset, {required double volume});

  Future<void> stopLoop();
  Future<void> stopAll();
}

/// Plays sound assets through the app's asset bundle.
class AssetSoundBackend implements SoundBackend {
  /// audioplayers' [AssetSource] resolves paths through its default
  /// [AudioCache], which prepends `assets/` itself — so it must receive
  /// the bundle path *without* that prefix, otherwise it would look for
  /// `assets/assets/...` and silently fail to load.
  static String stripBundlePrefix(String asset) =>
      asset.startsWith('assets/') ? asset.substring('assets/'.length) : asset;

  @override
  Future<void> playAsset(String asset, {required double volume}) async {
    final player = await _acquire();
    await player.play(AssetSource(stripBundlePrefix(asset)), volume: volume);
  }

  @override
  Future<void> startLoopAsset(String asset, {required double volume}) async {
    _fader.stop(); // cancel any fade from a previous loop
    _loop?.release();
    final player = await _acquire();
    await player.setReleaseMode(ReleaseMode.loop);
    // Start silent, then ramp up to the target volume so the loop eases
    // in behind the start cue instead of popping in at full level.
    await player.play(AssetSource(stripBundlePrefix(asset)), volume: 0);
    _loop = player;
    _fader.start(setVolume: player.setVolume, targetVolume: volume);
  }

  @override
  Future<void> stopLoop() async {
    _fader.stop(); // no volume steps after the loop is gone
    final player = _loop;
    _loop = null;
    if (player != null) {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.release);
      _release(player);
    }
  }

  @override
  Future<void> stopAll() async {
    _fader.stop();
    _loop = null;
    for (final player in List.of(_busy)) {
      await player.stop();
      _release(player);
    }
  }

  // ── Player pool (audioplayers costs one OS player per instance) ──

  static const int _poolSize = 6;
  final List<AudioPlayer> _idle = [];
  final Set<AudioPlayer> _busy = {};
  AudioPlayer? _loop;

  /// Ramps the loop player from silence to its target volume.
  final VolumeFader _fader = VolumeFader();

  Future<AudioPlayer> _acquire() async {
    if (_idle.isNotEmpty) {
      final player = _idle.removeLast();
      _busy.add(player);
      return player;
    }
    final player = AudioPlayer();
    _busy.add(player);
    return player;
  }

  Future<void> _release(AudioPlayer player) async {
    if (_busy.remove(player) && _idle.length < _poolSize) {
      _idle.add(player);
    } else {
      await player.dispose();
    }
  }
}

/// Ramps a volume from silence up to a target over a fixed duration,
/// in small discrete steps, by calling the provided volume setter.
///
/// Discrete steps (~50 ms apart) are used instead of a continuous curve:
/// they are perceptually identical for a background fade-in, and they
/// keep the fader fully deterministic and testable with [FakeAsync].
/// Only one ramp runs at a time — starting a new fade cancels the
/// previous one, and [stop] kills the active ramp immediately (used when
/// the loop is stopped, paused, or the preference turns off).
abstract class VolumeFader {
  /// Fade-in duration for the focus loop.
  static const Duration duration = Duration(seconds: 2);

  /// Volume update interval — slow enough to be cheap, fast enough to
  /// sound continuous.
  static const Duration _stepInterval = Duration(milliseconds: 50);

  /// 2000 ms / 50 ms = 40 steps. Const math on raw ints: Dart cannot
  /// call instance getters like [Duration.inMilliseconds] inside const
  /// expressions.
  static const int stepCount = 2000 ~/ 50;

  factory VolumeFader() = _TimerVolumeFader;

  /// Starts ramping from 0 to [targetVolume], calling [setVolume] with
  /// each intermediate value. Cancels any previously running ramp first.
  void start({
    required Future<void> Function(double volume) setVolume,
    required double targetVolume,
  });

  /// Cancels the active ramp, leaving the volume where it is now.
  void stop();
}

class _TimerVolumeFader implements VolumeFader {
  Timer? _timer;

  @override
  void start({
    required Future<void> Function(double volume) setVolume,
    required double targetVolume,
  }) {
    stop();
    if (targetVolume <= 0) return; // nothing to ramp towards
    // Exact silence now (Timer.periodic's first tick would only fire
    // after one interval), then 40 ticks ending exactly on target at
    // the 2-second mark.
    setVolume(0).catchError((_) {});
    var step = 0;
    _timer = Timer.periodic(VolumeFader._stepInterval, (timer) {
      step++;
      final volume = targetVolume * step / VolumeFader.stepCount;
      if (step >= VolumeFader.stepCount) {
        timer.cancel();
        _timer = null;
      }
      // Never let a failed volume step escape: the fader is cosmetic.
      setVolume(volume).catchError((_) {});
    });
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Silent backend for tests: records what was requested.
class FakeSoundBackend implements SoundBackend {
  final List<String> played = [];
  String? loopAsset;
  bool loopActive = false;
  int stopAllCalls = 0;

  @override
  Future<void> playAsset(String asset, {required double volume}) async {
    played.add('$asset@$volume');
  }

  @override
  Future<void> startLoopAsset(String asset, {required double volume}) async {
    loopAsset = asset;
    loopActive = true;
  }

  @override
  Future<void> stopLoop() async {
    loopActive = false;
  }

  @override
  Future<void> stopAll() async {
    stopAllCalls++;
    loopActive = false;
  }
}

/// Central UI-sound player: a pure-Dart singleton with no BuildContext
/// (services-layer rule) that gates every cue through the user's
/// preferences and never lets audio errors escape.
///
/// Preferences are loaded via [loadPreferences] (called from
/// [SettingsProvider.initialize]); until then the service stays enabled
/// with defaults so early events still work.
class UiSoundService {
  UiSoundService._();

  static final UiSoundService instance = UiSoundService._();

  /// Injectable backend (tests set a [FakeSoundBackend]).
  SoundBackend backend = AssetSoundBackend();

  // ─── Preferences (mirrored by SettingsProvider for the UI) ───

  bool _enabled = true;
  double _volume = 0.7;
  UiSoundPack _pack = UiSoundPack.minimal;
  final Set<UiSoundCategory> _disabledCategories = {};
  bool _loopEnabled = false;

  bool get enabled => _enabled;
  double get volume => _volume;
  UiSoundPack get pack => _pack;
  bool isCategoryEnabled(UiSoundCategory c) => !_disabledCategories.contains(c);
  bool get loopEnabled => _loopEnabled;

  /// Applies persisted preferences. Returns the loaded values so
  /// SettingsProvider can mirror them in one pass.
  Future<void> loadPreferences(
      {required bool enabled,
      required double volume,
      required UiSoundPack pack,
      required bool focusEnabled,
      required bool tasksEnabled,
      required bool notificationsEnabled,
      required bool loopEnabled}) async {
    _enabled = enabled;
    _volume = volume.clamp(0.0, 1.0);
    _pack = pack;
    _loopEnabled = loopEnabled;
    _disabledCategories
      ..clear()
      ..addAll([
        if (!focusEnabled) UiSoundCategory.focus,
        if (!tasksEnabled) UiSoundCategory.tasks,
        if (!notificationsEnabled) UiSoundCategory.notifications,
      ]);
    // Reset transient playback state so a preference reload never
    // inherits a stale loop or rate-limit memory.
    _loopActive = false;
    _lastPlayed.clear();
    try {
      await backend.stopAll();
    } catch (_) {}
  }

  void setPack(UiSoundPack value) => _pack = value;
  void setEnabled(bool value) => _enabled = value;
  void setVolume(double value) => _volume = value.clamp(0.0, 1.0);
  void setCategoryEnabled(UiSoundCategory category, bool enabled) {
    if (enabled) {
      _disabledCategories.remove(category);
    } else {
      _disabledCategories.add(category);
    }
  }

  void setLoopEnabled(bool value) {
    _loopEnabled = value;
    if (!value) stopLoop();
  }

  // ─── Playback ───

  /// Rate-limits identical one-shot cues so a fast double-fire doesn't
  /// machine-gun the sound.
  static const _rateLimitWindow = Duration(milliseconds: 80);
  final Map<UiSoundCue, DateTime> _lastPlayed = {};

  /// Plays [cue] with the current pack, volume, and gating.
  /// Fire-and-forget: never throws, never blocks the caller.
  void play(UiSoundCue cue, {UiSoundCategory? category}) {
    if (!_enabled || _volume <= 0) return;
    if (category != null && !isCategoryEnabled(category)) return;
    if (cue.isLoop) return; // loops go through startLoop

    final now = DateTime.now();
    final last = _lastPlayed[cue];
    if (last != null && now.difference(last) < _rateLimitWindow) return;
    _lastPlayed[cue] = now;

    final volume = (cue.defaultVolume * _volume).clamp(0.0, 1.0);
    // Intentionally un-awaited: sounds must never delay the action.
    backend
        .playAsset(cue.assetFor(_pack.id), volume: volume)
        .catchError((_) {});
  }

  /// Starts the ongoing-state loop when the user opts in via
  /// [setLoopEnabled]. Deduplicated: calling twice while active is a
  /// no-op so repeated refreshes can't stack copies.
  void startLoop() {
    if (!_enabled || !_loopEnabled || _volume <= 0) return;
    if (_loopActive) return;
    _loopActive = true;
    final volume = (UiSoundCue.processing.defaultVolume * _volume)
        .clamp(0.0, 1.0);
    backend
        .startLoopAsset(UiSoundCue.processing.assetFor(_pack.id),
            volume: volume)
        .catchError((_) {
      _loopActive = false;
    });
  }

  bool _loopActive = false;

  /// Stops the ongoing-state loop (session paused, stopped, completed,
  /// or the preference turned off).
  void stopLoop() {
    _loopActive = false;
    backend.stopLoop().catchError((_) {});
  }

  /// Silences everything (app teardown, restore-with-replace flows).
  void stopAll() {
    _lastPlayed.clear();
    backend.stopAll().catchError((_) {});
  }

  /// Convenience hooks the providers call, keeping cue→category mapping
  /// in one place.

  void focusStarted() {
    play(UiSoundCue.start, category: UiSoundCategory.focus);
    startLoop();
  }

  void focusCompleted() {
    stopLoop();
    play(UiSoundCue.complete, category: UiSoundCategory.focus);
  }

  void focusStopped() {
    stopLoop();
    play(UiSoundCue.stop, category: UiSoundCategory.focus);
  }

  void focusPaused() {
    stopLoop();
    play(UiSoundCue.pause, category: UiSoundCategory.focus);
  }

  void focusResumed() {
    play(UiSoundCue.play, category: UiSoundCategory.focus);
    startLoop();
  }

  void taskCompleted() =>
      play(UiSoundCue.check, category: UiSoundCategory.tasks);

  void taskSaved() => play(UiSoundCue.send, category: UiSoundCategory.tasks);

  void taskDeleted() =>
      play(UiSoundCue.delete, category: UiSoundCategory.tasks);

  void dataRestored() =>
      play(UiSoundCue.success, category: UiSoundCategory.tasks);

  void reminderFired() =>
      play(UiSoundCue.notification, category: UiSoundCategory.notifications);
}
