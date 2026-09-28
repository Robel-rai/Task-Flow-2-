import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/app_version.dart';
import '../theme/app_colors.dart';
import 'app_logo.dart';

/// Height of the custom title bar, matching the Windows 11 caption height.
const double kAppTitleBarHeight = 32;

/// Custom window title bar that replaces the native one (which is hidden via
/// `TitleBarStyle.hidden`). Behaves like a standard Windows caption bar:
///
/// - Drag anywhere on the bar to move the window (with snap layouts).
/// - Double-click (or maximize/restore button) to toggle maximize.
/// - Aero Snap via Win+Arrow keys and Windows shortcuts still work because the
///   window keeps its system frame.
/// - Minimize / maximize-restore / close buttons on the right.
///
/// Colors follow the app theme so the bar blends with the window in both
/// dark and light mode (including custom user palettes).
class AppTitleBar extends StatefulWidget {
  const AppTitleBar({super.key, this.showControls = true});

  /// Whether to show the minimize/maximize/close buttons. Disabled for
  /// non-window surfaces (e.g. the settings theme mockup).
  final bool showControls;

  @override
  State<AppTitleBar> createState() => _AppTitleBarState();
}

class _AppTitleBarState extends State<AppTitleBar> with WindowListener {
  bool _maximized = false;

  /// True once a call into window_manager has succeeded. In widget tests (and
  /// on platforms without the plugin) channel calls throw; fail-safe so the
  /// bar still renders and the tests boot the real app tree unharmed.
  bool _nativeAvailable = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _refreshMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _refreshMaximized() async {
    if (!mounted || !_nativeAvailable) return;
    try {
      final maximized = await windowManager.isMaximized();
      if (mounted && maximized != _maximized) {
        setState(() => _maximized = maximized);
      }
    } catch (_) {
      _nativeAvailable = false;
    }
  }

  // WindowListener callbacks keep the maximize/restore icon in sync even when
  // the window state changes outside the app (Win+Up, Aero Snap, taskbar).
  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  void onWindowRestore() => _refreshMaximized();

  Future<void> _toggleMaximize() async {
    try {
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    } catch (_) {
      // No native window (e.g. widget tests) — nothing to do.
    }
  }

  /// Runs a window_manager call, swallowing the MissingPluginException thrown
  /// when the native side isn't available (widget tests).
  Future<void> _safe(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {
      _nativeAvailable = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMaximized = _maximized;

    final Widget bar = Container(
      height: kAppTitleBarHeight,
      decoration: BoxDecoration(
        color: colors.sidebarBackground,
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          if (!isMaximized) const SizedBox(width: 1),
          Expanded(
            child: DragToMoveArea(
              onDoubleTap: _toggleMaximize,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const AppLogo(size: 16),
                  const SizedBox(width: 8),
                  Text(
                    AppVersion.appName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'v${AppVersion.version}',
                    style: TextStyle(
                      fontSize: 10,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.showControls)
            Row(
              children: [
                _CaptionButton(
                  icon: Icons.horizontal_rule,
                  tooltip: 'Minimize',
                  isDark: isDark,
                  onTap: () => _safe(() => windowManager.minimize()),
                ),
                _CaptionButton(
                  icon: isMaximized
                      ? Icons.filter_none
                      : Icons.crop_square,
                  tooltip: isMaximized ? 'Restore' : 'Maximize',
                  iconSize: isMaximized ? 13 : 12,
                  isDark: isDark,
                  onTap: _toggleMaximize,
                ),
                _CloseButton(
                  isDark: isDark,
                  onTap: () => _safe(() => windowManager.close()),
                ),
              ],
            ),
        ],
      ),
    );

    return bar;
  }
}

/// A caption-bar icon button with Windows-style hover feedback.
class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
    this.iconSize = 14,
  });

  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;
  final double iconSize;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovering = false;
  bool _pressed = false;

  Color get _bg {
    if (_pressed) {
      return widget.isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.black.withValues(alpha: 0.04);
    }
    if (_hovering) {
      return widget.isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06);
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final iconColor =
        _hovering ? colors.textPrimary : colors.textSecondary;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() {
          _hovering = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: Container(
            width: 46,
            height: kAppTitleBarHeight,
            color: _bg,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Close button with the standard Windows red hover.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.isDark, required this.onTap});

  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    const hoverBg = Color(0xFFC42B1C);

    return Tooltip(
      message: 'Close',
      waitDuration: const Duration(milliseconds: 600),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: hoverBg,
          splashColor: hoverBg.withValues(alpha: 0.9),
          highlightColor: hoverBg.withValues(alpha: 0.8),
          child: Ink(
            width: 46,
            height: kAppTitleBarHeight,
            child: Center(
              child: Icon(
                Icons.close,
                size: 15,
                color: colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Drag-to-move area with double-click maximize/restore.
///
/// Local copy of window_manager's [DragToMoveArea] so double-click can reuse
/// the tracked maximize state instead of issuing an extra channel call.
class DragToMoveArea extends StatelessWidget {
  const DragToMoveArea({super.key, required this.child, this.onDoubleTap});

  final Widget child;
  final VoidCallback? onDoubleTap;

  Future<void> _startDragging() async {
    try {
      await windowManager.startDragging();
    } catch (_) {
      // No native window (e.g. widget tests).
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => _startDragging(),
      onDoubleTap: onDoubleTap ??
          () async {
            try {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            } catch (_) {
              // No native window (e.g. widget tests).
            }
          },
      child: child,
    );
  }
}
