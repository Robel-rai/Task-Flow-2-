import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

/// Raised when a Win32 registry call returns a non-zero status code.
class WindowsRegistryException implements Exception {
  WindowsRegistryException(this.operation, this.status)
      : message = 'Registry $operation failed (Win32 error $status)'
            '${status == _errorAccessDenied ? ' — access denied' : ''}';

  final String operation;
  final int status;
  final String message;

  @override
  String toString() => 'WindowsRegistryException: $message';
}

const int _errorSuccess = 0;
const int _errorFileNotFound = 2;
const int _errorPathNotFound = 3;
const int _errorAccessDenied = 5;

// ─── Native signatures ───

typedef _RegOpenKeyExNative = ffi.Int32 Function(ffi.IntPtr,
    ffi.Pointer<Utf16>, ffi.Uint32, ffi.Uint32, ffi.Pointer<ffi.IntPtr>);
typedef _RegOpenKeyExDart = int Function(
    int, ffi.Pointer<Utf16>, int, int, ffi.Pointer<ffi.IntPtr>);

typedef _RegCreateKeyExNative = ffi.Int32 Function(
    ffi.IntPtr,
    ffi.Pointer<Utf16>,
    ffi.Uint32,
    ffi.Pointer<Utf16>,
    ffi.Uint32,
    ffi.Uint32,
    ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.IntPtr>,
    ffi.Pointer<ffi.Uint32>);
typedef _RegCreateKeyExDart = int Function(int, ffi.Pointer<Utf16>, int,
    ffi.Pointer<Utf16>, int, int, ffi.Pointer<ffi.Void>,
    ffi.Pointer<ffi.IntPtr>, ffi.Pointer<ffi.Uint32>);

typedef _RegSetValueExNative = ffi.Int32 Function(ffi.IntPtr,
    ffi.Pointer<Utf16>, ffi.Uint32, ffi.Uint32, ffi.Pointer<ffi.Uint8>,
    ffi.Uint32);
typedef _RegSetValueExDart = int Function(int, ffi.Pointer<Utf16>, int, int,
    ffi.Pointer<ffi.Uint8>, int);

typedef _RegQueryValueExNative = ffi.Int32 Function(
    ffi.IntPtr,
    ffi.Pointer<Utf16>,
    ffi.Pointer<ffi.Uint32>,
    ffi.Pointer<ffi.Uint32>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint32>);
typedef _RegQueryValueExDart = int Function(
    int,
    ffi.Pointer<Utf16>,
    ffi.Pointer<ffi.Uint32>,
    ffi.Pointer<ffi.Uint32>,
    ffi.Pointer<ffi.Uint8>,
    ffi.Pointer<ffi.Uint32>);

typedef _RegDeleteValueNative = ffi.Int32 Function(
    ffi.IntPtr, ffi.Pointer<Utf16>);
typedef _RegDeleteValueDart = int Function(int, ffi.Pointer<Utf16>);

typedef _RegDeleteKeyNative = ffi.Int32 Function(
    ffi.IntPtr, ffi.Pointer<Utf16>);
typedef _RegDeleteKeyDart = int Function(int, ffi.Pointer<Utf16>);

typedef _RegCloseKeyNative = ffi.Int32 Function(ffi.IntPtr);
typedef _RegCloseKeyDart = int Function(int);

/// Minimal Win32 registry access for the current-user hive (`HKCU`).
///
/// Only the calls the app needs are bound: open or create a key, read, write
/// and delete a `REG_SZ` value, and delete a key. Everything is synchronous
/// and cheap. No elevation is ever required, because `HKEY_CURRENT_USER` is
/// owned by the signed-in user — which is why the app registers itself there
/// rather than in `HKEY_LOCAL_MACHINE`.
///
/// This class is deliberately free of Flutter imports so it can be exercised
/// by tests and by plain `dart run` scripts.
class WindowsRegistry {
  WindowsRegistry({ffi.DynamicLibrary? library}) : _library = library;

  /// `HKEY_CURRENT_USER` — a 32-bit pseudo-handle with the high bit set.
  static const int _hkeyCurrentUser = 0x80000001;

  static const int _keyQueryValue = 0x0001;
  static const int _keySetValue = 0x0002;

  /// `REG_SZ` — a null-terminated UTF-16 string.
  static const int _regSz = 1;

  /// Bytes per UTF-16 code unit.
  static const int _utf16UnitSize = 2;

  ffi.DynamicLibrary? _library;

  ffi.DynamicLibrary get _advapi32 =>
      _library ??= ffi.DynamicLibrary.open('advapi32.dll');

  late final _RegOpenKeyExDart _regOpenKeyEx = _advapi32.lookupFunction<
      _RegOpenKeyExNative, _RegOpenKeyExDart>('RegOpenKeyExW');

  late final _RegCreateKeyExDart _regCreateKeyEx = _advapi32.lookupFunction<
      _RegCreateKeyExNative, _RegCreateKeyExDart>('RegCreateKeyExW');

  late final _RegSetValueExDart _regSetValueEx = _advapi32.lookupFunction<
      _RegSetValueExNative, _RegSetValueExDart>('RegSetValueExW');

  late final _RegQueryValueExDart _regQueryValueEx = _advapi32.lookupFunction<
      _RegQueryValueExNative, _RegQueryValueExDart>('RegQueryValueExW');

  late final _RegDeleteValueDart _regDeleteValue = _advapi32
      .lookupFunction<_RegDeleteValueNative, _RegDeleteValueDart>(
          'RegDeleteValueW');

  late final _RegDeleteKeyDart _regDeleteKey = _advapi32.lookupFunction<
      _RegDeleteKeyNative, _RegDeleteKeyDart>('RegDeleteKeyW');

  late final _RegCloseKeyDart _regCloseKey = _advapi32.lookupFunction<
      _RegCloseKeyNative, _RegCloseKeyDart>('RegCloseKey');

  /// Reads a `REG_SZ` value under [subKey].
  ///
  /// Returns null when the key or the value does not exist, so a missing
  /// entry is a normal result rather than an error.
  String? readString(String subKey, String valueName) {
    final key = _openKeyWithAccess(subKey, _keyQueryValue);
    if (key == null) return null;

    final name = valueName.toNativeUtf16();
    final type = calloc<ffi.Uint32>();
    final size = calloc<ffi.Uint32>();
    try {
      // First call asks for the size with a null buffer, the second reads
      // the data — REG_SZ values have no fixed upper bound.
      var status =
          _regQueryValueEx(key, name, ffi.nullptr, type, ffi.nullptr, size);
      if (status == _errorFileNotFound) return null;
      if (status != _errorSuccess) {
        throw WindowsRegistryException('read "$valueName"', status);
      }

      final byteCount = size.value;
      if (byteCount == 0) return '';

      final data = calloc<ffi.Uint8>(byteCount);
      try {
        status = _regQueryValueEx(key, name, ffi.nullptr, type, data, size);
        if (status != _errorSuccess) {
          throw WindowsRegistryException('read "$valueName"', status);
        }
        return _decodeUtf16(data, byteCount);
      } finally {
        calloc.free(data);
      }
    } finally {
      calloc.free(name);
      calloc.free(type);
      calloc.free(size);
      _regCloseKey(key);
    }
  }

  /// Writes [value] as a `REG_SZ` under [subKey], creating the key if needed.
  void writeString(String subKey, String valueName, String value) {
    final key = _createKey(subKey);
    final name = valueName.toNativeUtf16();
    final data = value.toNativeUtf16();
    try {
      // [toNativeUtf16] already appends the terminator, so the byte count
      // includes it. `Utf16` is opaque (no `sizeOf`), and it is always
      // 2 bytes per code unit.
      final byteCount = (value.length + 1) * _utf16UnitSize;
      final status = _regSetValueEx(
          key, name, 0, _regSz, data.cast<ffi.Uint8>(), byteCount);
      if (status != _errorSuccess) {
        throw WindowsRegistryException('write "$valueName"', status);
      }
    } finally {
      calloc.free(name);
      calloc.free(data);
      _regCloseKey(key);
    }
  }

  /// Deletes a single value under [subKey].
  ///
  /// Returns false when the key or value was already absent.
  bool deleteValue(String subKey, String valueName) {
    final key = _openKeyWithAccess(subKey, _keySetValue);
    if (key == null) return false;

    final name = valueName.toNativeUtf16();
    try {
      final status = _regDeleteValue(key, name);
      if (status == _errorFileNotFound) return false;
      if (status != _errorSuccess) {
        throw WindowsRegistryException('delete "$valueName"', status);
      }
      return true;
    } finally {
      calloc.free(name);
      _regCloseKey(key);
    }
  }

  /// Deletes [subKey], which must have no subkeys of its own.
  ///
  /// Returns false when the key was already absent.
  bool deleteKey(String subKey) {
    final name = subKey.toNativeUtf16();
    try {
      final status = _regDeleteKey(_hkeyCurrentUser, name);
      if (status == _errorFileNotFound || status == _errorPathNotFound) {
        return false;
      }
      if (status != _errorSuccess) {
        throw WindowsRegistryException('delete key "$subKey"', status);
      }
      return true;
    } finally {
      calloc.free(name);
    }
  }

  // ─── Internals ───

  /// Decodes [byteCount] bytes of null-terminated UTF-16 at [data].
  ///
  /// `Utf16` is an opaque FFI type (so it cannot be used with `cast`), hence
  /// the manual code-unit decode. `String.fromCharCodes` re-assembles
  /// surrogate pairs correctly.
  static String _decodeUtf16(ffi.Pointer<ffi.Uint8> data, int byteCount) {
    final units = byteCount ~/ 2;
    if (units == 0) return '';
    final codeUnits = data.cast<ffi.Uint16>().asTypedList(units);
    var end = units;
    while (end > 0 && codeUnits[end - 1] == 0) {
      end--;
    }
    return String.fromCharCodes(codeUnits, 0, end);
  }

  int? _openKeyWithAccess(String subKey, int access) {
    final name = subKey.toNativeUtf16();
    final result = calloc<ffi.IntPtr>();
    try {
      final status =
          _regOpenKeyEx(_hkeyCurrentUser, name, 0, access, result);
      if (status == _errorFileNotFound || status == _errorPathNotFound) {
        return null;
      }
      if (status != _errorSuccess) {
        throw WindowsRegistryException('open "$subKey"', status);
      }
      return result.value;
    } finally {
      calloc.free(name);
      calloc.free(result);
    }
  }

  int _createKey(String subKey) {
    final name = subKey.toNativeUtf16();
    final result = calloc<ffi.IntPtr>();
    final disposition = calloc<ffi.Uint32>();
    try {
      final status = _regCreateKeyEx(
        _hkeyCurrentUser,
        name,
        0,
        ffi.nullptr,
        0,
        _keyQueryValue | _keySetValue,
        ffi.nullptr,
        result,
        disposition,
      );
      if (status != _errorSuccess) {
        throw WindowsRegistryException('create "$subKey"', status);
      }
      return result.value;
    } finally {
      calloc.free(name);
      calloc.free(result);
      calloc.free(disposition);
    }
  }
}
