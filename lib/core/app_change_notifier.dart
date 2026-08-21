import 'package:flutter/foundation.dart';

/// [ChangeNotifier] that tracks disposal so in-flight async work never
/// calls [notifyListeners] on a disposed provider (which throws).
///
/// All app providers extend this and call [safeNotify] instead of
/// [notifyListeners] after awaits.
abstract class AppChangeNotifier extends ChangeNotifier {
  bool _appDisposed = false;

  bool get isActive => !_appDisposed;

  @override
  void dispose() {
    _appDisposed = true;
    super.dispose();
  }

  /// Notifies listeners only if the notifier is still mounted.
  void safeNotify() {
    if (_appDisposed) return;
    notifyListeners();
  }
}
