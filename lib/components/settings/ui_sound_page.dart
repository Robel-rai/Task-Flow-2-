import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../services/ui_sound_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Sub-setting page: "UI Sound & Customization".
///
/// The app's UI sounds come from
/// [UI SFX](https://github.com/romainsimon/uisfx) — 12 coherent sound
/// packs of the same semantic cues (CC0 audio). Sounds are used only to
/// give instant feedback, confirm user actions, and indicate ongoing
/// states; this page controls how that feedback sounds and when it plays.
class UiSoundPage extends StatelessWidget {
  const UiSoundPage({super.key, required this.onBack});

  final VoidCallback onBack;

  // Preview order follows the event table on the page.
  static const _previews = <(UiSoundCue, UiSoundCategory, String)>[
    (UiSoundCue.start, UiSoundCategory.focus, 'Focus session started'),
    (UiSoundCue.complete, UiSoundCategory.focus, 'Focus timer completed'),
    (UiSoundCue.pause, UiSoundCategory.focus, 'Focus paused'),
    (UiSoundCue.play, UiSoundCategory.focus, 'Focus resumed'),
    (UiSoundCue.stop, UiSoundCategory.focus, 'Focus stopped'),
    (UiSoundCue.check, UiSoundCategory.tasks, 'Task completed'),
    (UiSoundCue.send, UiSoundCategory.tasks, 'Task saved'),
    (UiSoundCue.delete, UiSoundCategory.tasks, 'Task deleted'),
    (UiSoundCue.success, UiSoundCategory.tasks, 'Backup restored'),
    (
      UiSoundCue.notification,
      UiSoundCategory.notifications,
      'Reminder fired'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final settings = context.watch<SettingsProvider>();

    return Column(
      children: [
        // Header — same pattern as the other settings sub-pages.
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
                onPressed: onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('UI Sound & Customization',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Feedback sounds for actions and ongoing states',
                      style: TextStyle(
                          fontSize: 12, color: colors.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Master ──
                Text('General', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(Icons.volume_up_outlined,
                            color: colors.primary),
                        title: const Text('UI sounds',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Play sounds for instant feedback, action '
                          'confirmations, and ongoing states — never as '
                          'decoration',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                        value: settings.uiSoundEnabled,
                        onChanged: settings.setUiSoundEnabled,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        enabled: settings.uiSoundEnabled,
                        leading: Icon(Icons.volume_down_outlined,
                            color: colors.primary),
                        title: const Text('Volume',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Slider(
                          value: settings.uiSoundVolume,
                          min: 0,
                          max: 1,
                          divisions: 20,
                          label:
                              '${(settings.uiSoundVolume * 100).round()}%',
                          onChanged: settings.uiSoundEnabled
                              ? settings.setUiSoundVolume
                              : null,
                          onChangeEnd: (v) {
                            if (settings.uiSoundEnabled) {
                              UiSoundService.instance.play(
                                UiSoundCue.notification,
                                category: UiSoundCategory.notifications,
                              );
                            }
                          },
                        ),
                        trailing: Text(
                          '${(settings.uiSoundVolume * 100).round()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Sound pack ──
                Text('Sound Pack',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Every pack plays the same cues with a different '
                  'personality — switching never changes app behavior.',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final pack in UiSoundPack.values)
                          _PackChip(
                            pack: pack,
                            selected: settings.uiSoundPack == pack,
                            enabled: settings.uiSoundEnabled,
                            onSelect: () async {
                              await settings.setUiSoundPack(pack);
                              if (settings.uiSoundEnabled) {
                                UiSoundService.instance.play(
                                  UiSoundCue.notification,
                                  category: UiSoundCategory.notifications,
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Categories ──
                Text('Events', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(Icons.timer_outlined,
                            color: AppTheme.emerald),
                        title: const Text('Focus timer',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Session start, completion, pause, resume, stop',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                        value: settings.uiSoundFocusEnabled,
                        onChanged: settings.uiSoundEnabled
                            ? (v) => settings.setUiSoundCategoryEnabled(
                                UiSoundCategory.focus, v)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: Icon(Icons.check_circle_outline,
                            color: AppTheme.indigo),
                        title: const Text('Tasks',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Create, save, complete, and delete confirmations',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                        value: settings.uiSoundTasksEnabled,
                        onChanged: settings.uiSoundEnabled
                            ? (v) => settings.setUiSoundCategoryEnabled(
                                UiSoundCategory.tasks, v)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: Icon(Icons.notifications_outlined,
                            color: AppTheme.rose),
                        title: const Text('Notifications',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Reminder popups and toasts',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                        value: settings.uiSoundNotificationsEnabled,
                        onChanged: settings.uiSoundEnabled
                            ? (v) => settings.setUiSoundCategoryEnabled(
                                UiSoundCategory.notifications, v)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: Icon(Icons.graphic_eq,
                            color: AppTheme.amber),
                        title: const Text('Loop while focusing',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'A subtle repeating sound while a focus session '
                          'is running, stopped when it ends',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                        value: settings.uiSoundLoopEnabled,
                        onChanged: settings.uiSoundEnabled
                            ? settings.setUiSoundLoopEnabled
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Previews ──
                Text('Preview Sounds',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < _previews.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        ListTile(
                          enabled: settings.uiSoundEnabled,
                          leading: Icon(Icons.play_circle_outline,
                              color: colors.primary),
                          title: Text(_previews[i].$3,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            _previews[i].$1.label,
                            style: TextStyle(
                                fontSize: 12, color: colors.textTertiary),
                          ),
                          onTap: settings.uiSoundEnabled
                              ? () => UiSoundService.instance
                                  .play(_previews[i].$1)
                              : null,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Attribution ──
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.music_note_outlined,
                        color: colors.primary),
                    title: const Text('About the sounds',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Semantic UI sound effects from UI SFX '
                      '(CC0) — github.com/romainsimon/uisfx',
                      style: TextStyle(fontSize: 12, color: colors.textTertiary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Selectable chip showing a pack's name, character, and best-fit note.
class _PackChip extends StatelessWidget {
  const _PackChip({
    required this.pack,
    required this.selected,
    required this.enabled,
    required this.onSelect,
  });

  final UiSoundPack pack;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final tooltip = '${pack.description} Best for: ${pack.bestFor}';

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: selected
            ? colors.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: enabled ? onSelect : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 232,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? colors.primary : colors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected ? colors.primary : colors.textTertiary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? colors.primary
                              : colors.textPrimary,
                        ),
                      ),
                      Text(
                        pack.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: colors.textTertiary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
