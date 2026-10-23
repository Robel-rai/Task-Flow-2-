import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:taskflow/services/windows_registry.dart';

/// A dedicated, disposable key — deliberately *not* the Run key, so a failed
/// run can never leave a startup entry behind on the machine.
const String _testKey = r'Software\TaskFlowRegistrySelfTest';

void main() {
  final registry = WindowsRegistry();

  void cleanUp() {
    if (!Platform.isWindows) return;
    try {
      registry.deleteKey(_testKey);
    } on WindowsRegistryException {
      // Nothing to clean up.
    }
  }

  setUp(cleanUp);
  tearDown(cleanUp);

  test('round-trips a REG_SZ value through the real registry', () {
    const command = r'"C:\Program Files\TaskFlow\taskflow.exe"';

    expect(registry.readString(_testKey, 'probe'), isNull,
        reason: 'a missing key reads as absent rather than throwing');

    registry.writeString(_testKey, 'probe', command);
    expect(registry.readString(_testKey, 'probe'), command);

    registry.writeString(_testKey, 'probe', r'"D:\New\taskflow.exe"');
    expect(registry.readString(_testKey, 'probe'), r'"D:\New\taskflow.exe"',
        reason: 'writing an existing value replaces it');

    expect(registry.deleteValue(_testKey, 'probe'), isTrue);
    expect(registry.readString(_testKey, 'probe'), isNull);
    expect(registry.deleteValue(_testKey, 'probe'), isFalse,
        reason: 'deleting an absent value reports false');

    expect(registry.deleteKey(_testKey), isTrue);
    expect(registry.deleteKey(_testKey), isFalse);
  }, skip: !Platform.isWindows);

  test('keeps values independent within one key and handles empty strings', () {
    registry.writeString(_testKey, 'a', 'one');
    registry.writeString(_testKey, 'b', 'two');
    registry.writeString(_testKey, 'empty', '');

    expect(registry.readString(_testKey, 'a'), 'one');
    expect(registry.readString(_testKey, 'b'), 'two');
    expect(registry.readString(_testKey, 'empty'), '');

    expect(registry.deleteValue(_testKey, 'a'), isTrue);
    expect(registry.readString(_testKey, 'a'), isNull);
    expect(registry.readString(_testKey, 'b'), 'two');
  }, skip: !Platform.isWindows);
}
