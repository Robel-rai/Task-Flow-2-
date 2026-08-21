import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/shortcuts_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Settings sub-page for viewing and rebinding keyboard shortcuts.
class ShortcutsPage extends StatefulWidget {
  const ShortcutsPage({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  State<ShortcutsPage> createState() => _ShortcutsPageState();
}

class _ShortcutsPageState extends State<ShortcutsPage> {
  ShortcutAction? _recordingFor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final shortcuts = context.watch<ShortcutsProvider>();

    // Group by category
    final categories = <String, List<ShortcutAction>>{};
    for (final action in ShortcutAction.values) {
      final meta = ShortcutMeta.all[action]!;
      categories.putIfAbsent(meta.category, () => []).add(action);
    }

    return Column(
      children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to settings',
                icon: Icon(Icons.arrow_back, color: colors.textSecondary),
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Keyboard Shortcuts', style: Theme.of(context).textTheme.titleLarge),
                    Text('Click a shortcut to rebind it', style: TextStyle(fontSize: 12, color: colors.textTertiary)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await shortcuts.resetAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Shortcuts reset to defaults'), duration: Duration(seconds: 2)),
                    );
                  }
                },
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(32),
            children: [
              for (final entry in categories.entries) ...[
                Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (int i = 0; i < entry.value.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _ShortcutRow(
                          action: entry.value[i],
                          binding: shortcuts.bindings[entry.value[i]]!,
                          isRecording: _recordingFor == entry.value[i],
                          onRecord: () {
                            setState(() {
                              _recordingFor = _recordingFor == entry.value[i] ? null : entry.value[i];
                            });
                          },
                          onCaptured: (keys) async {
                            await shortcuts.setBinding(entry.value[i], keys);
                            setState(() => _recordingFor = null);
                          },
                          onReset: () async {
                            await shortcuts.setBinding(entry.value[i], null);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatefulWidget {
  const _ShortcutRow({
    required this.action,
    required this.binding,
    required this.isRecording,
    required this.onRecord,
    required this.onCaptured,
    required this.onReset,
  });

  final ShortcutAction action;
  final LogicalKeySet binding;
  final bool isRecording;
  final VoidCallback onRecord;
  final ValueChanged<LogicalKeySet?> onCaptured;
  final VoidCallback onReset;

  @override
  State<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends State<_ShortcutRow> {
  final FocusNode _focusNode = FocusNode();
  LogicalKeySet? _captured;

  @override
  void didUpdateWidget(_ShortcutRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !oldWidget.isRecording) {
      _captured = null;
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCaptured(null); // cancel recording
      return KeyEventResult.handled;
    }
    // Build the key set from currently pressed keys
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final keys = pressed.where((k) => !{
      LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
      LogicalKeyboardKey.alt, LogicalKeyboardKey.meta,
    }.contains(k)).toSet();
    if (keys.isEmpty) return KeyEventResult.ignored;
    // Include modifiers
    final modifiers = pressed.where((k) => {
      LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
      LogicalKeyboardKey.alt, LogicalKeyboardKey.meta,
    }.contains(k)).toSet();
    widget.onCaptured(LogicalKeySet.fromSet({...modifiers, ...keys}));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final meta = ShortcutMeta.all[widget.action]!;
    final display = ShortcutsProvider.keySetToString(widget.binding);

    return ListTile(
      title: Text(meta.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(meta.description, style: TextStyle(fontSize: 12, color: colors.textTertiary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isRecording)
            Focus(
              focusNode: _focusNode,
              onKeyEvent: _onKey,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary, width: 1.5),
                ),
                child: Text(
                  _captured != null ? ShortcutsProvider.keySetToString(_captured!) : 'Press keys...',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: widget.onRecord,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
           
                  display,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textSecondary),
                ),
              ),
            ),
          const SizedBox(width: 8),
          if (widget.binding != defaultBindings[widget.action])
            IconButton(
              tooltip: 'Reset to default',
              icon: Icon(Icons.restart_alt, size: 16, color: colors.textTertiary),
              onPressed: widget.onReset,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}
