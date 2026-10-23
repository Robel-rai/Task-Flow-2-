import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:taskflow/services/startup_service.dart';

/// In-memory stand-in for the Windows Run key.
class _FakeRegistry implements StartupRegistry {
  _FakeRegistry([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;
  int writeCount = 0;
  int removeCount = 0;

  /// When set, every call throws this (simulates an ACL/registry failure).
  Object? failWith;

  @override
  String? readCommand(String valueName) {
    _throwIfConfigured();
    return values[valueName];
  }

  @override
  void writeCommand(String valueName, String command) {
    _throwIfConfigured();
    writeCount++;
    values[valueName] = command;
  }

  @override
  void removeCommand(String valueName) {
    _throwIfConfigured();
    removeCount++;
    values.remove(valueName);
  }

  void _throwIfConfigured() {
    final error = failWith;
    if (error != null) throw error;
  }
}

const String _exe = r'C:\Program Files\TaskFlow\taskflow.exe';
const String _otherExe = r'D:\Old\taskflow.exe';

/// The quoted command the app registers for [_exe].
final String _command = '"$_exe"';

StartupService _service(_FakeRegistry registry, {String valueName = 'TaskFlow'}) =>
    StartupService(
      registry: registry,
      executablePath: _exe,
      valueName: valueName,
    );

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to off and registers nothing', () async {
    final registry = _FakeRegistry();
    final service = _service(registry);

    expect(await service.isEnabled(), isFalse);
    expect(registry.values, isEmpty);
    expect(registry.writeCount, 0);
  });

  test('the registered command quotes the executable path', () {
    expect(_service(_FakeRegistry()).command, _command);
  });

  test('enabling registers a quoted command and persists the preference',
      () async {
    final registry = _FakeRegistry();
    final service = _service(registry);

    await service.setEnabled(true);

    expect(registry.values['TaskFlow'], _command);
    expect((await _prefs()).getBool(StartupService.prefLaunchAtStartup), isTrue);
    expect(await service.isEnabled(), isTrue);
  });

  test('disabling removes the entry and clears the preference', () async {
    final registry = _FakeRegistry();
    final service = _service(registry);

    await service.setEnabled(true);
    await service.setEnabled(false);

    expect(registry.values, isEmpty);
    expect(registry.removeCount, 1);
    expect(
        (await _prefs()).getBool(StartupService.prefLaunchAtStartup), isFalse);
    expect(await service.isEnabled(), isFalse);
  });

  test('a failed registration leaves the preference off so the switch cannot '
      'claim a startup entry that is not there', () async {
    final registry = _FakeRegistry()
      ..failWith = StartupRegistrationException('access denied');
    final service = _service(registry);

    await expectLater(
      service.setEnabled(true),
      throwsA(isA<StartupRegistrationException>()),
    );

    expect((await _prefs()).getBool(StartupService.prefLaunchAtStartup),
        isNot(isTrue));
    expect(await service.isEnabled(), isFalse);
  });

  test('isEnabled is false when the entry was removed behind the app\'s back',
      () async {
    final registry = _FakeRegistry();
    final service = _service(registry);
    await service.setEnabled(true);

    // e.g. the user cleaned it up in Task Manager / the registry directly.
    registry.values.clear();

    expect(await service.isEnabled(), isFalse);
  });

  test('reconcile repairs an entry that points at a stale path', () async {
    SharedPreferences.setMockInitialValues(
        {StartupService.prefLaunchAtStartup: true});
    final registry = _FakeRegistry({'TaskFlow': '"$_otherExe"'});

    await _service(registry).reconcile();

    expect(registry.values['TaskFlow'], _command);
    expect(registry.writeCount, 1);
  });

  test('reconcile registers the entry when the preference is on but the '
      'entry is missing', () async {
    SharedPreferences.setMockInitialValues(
        {StartupService.prefLaunchAtStartup: true});
    final registry = _FakeRegistry();

    await _service(registry).reconcile();

    expect(registry.values['TaskFlow'], _command);
  });

  test('reconcile writes nothing when the entry already matches', () async {
    SharedPreferences.setMockInitialValues(
        {StartupService.prefLaunchAtStartup: true});
    final registry = _FakeRegistry({'TaskFlow': _command});

    await _service(registry).reconcile();

    expect(registry.writeCount, 0);
    expect(registry.removeCount, 0);
    expect(registry.values['TaskFlow'], _command);
  });

  test('reconcile clears a leftover entry when the preference is off',
      () async {
    final registry = _FakeRegistry({'TaskFlow': _command});

    await _service(registry).reconcile();

    expect(registry.values, isEmpty);
    expect(registry.removeCount, 1);
  });

  test('reconcile leaves another build\'s entry alone', () async {
    final registry = _FakeRegistry({'TaskFlow': _command});

    // The dev build owns the "TaskFlow Dev" value, not "TaskFlow".
    await _service(registry, valueName: 'TaskFlow Dev').reconcile();

    expect(registry.values['TaskFlow'], _command);
    expect(registry.removeCount, 0);
    expect(registry.writeCount, 0);
  });

  test('reconcile never throws when the registry is unavailable', () async {
    SharedPreferences.setMockInitialValues(
        {StartupService.prefLaunchAtStartup: true});
    final registry = _FakeRegistry()
      ..failWith = StartupRegistrationException('registry unavailable');

    await expectLater(_service(registry).reconcile(), completes);
  });

  test('the value name follows the build mode unless overridden', () {
    final defaulted =
        StartupService(registry: _FakeRegistry(), executablePath: _exe);

    expect(defaulted.valueName,
        kDebugMode ? StartupService.valueNameDebug : StartupService.valueNameRelease);
    expect(StartupService.valueNameDebug, 'TaskFlow Dev');
    expect(StartupService.valueNameRelease, 'TaskFlow');
  });
}
