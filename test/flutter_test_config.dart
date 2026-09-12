import 'dart:async';

import 'package:taskflow/services/ui_sound_service.dart';

/// Global test bootstrap, loaded automatically by the Flutter test runner
/// (see https://api.flutter.dev/flutter/flutter_test/flutter_test_config-experimental.html).
///
/// Widget tests run on the plain Flutter testbed with no plugin
/// implementations, so any cue fired through [UiSoundService] would hit
/// the audioplayers platform channels and crash with a
/// MissingPluginException. Swapping in the recording [FakeSoundBackend]
/// keeps every test silent and hermetic; tests that assert on sound
/// behavior install their own backend explicitly.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  UiSoundService.instance.backend = FakeSoundBackend();
  await testMain();
}
