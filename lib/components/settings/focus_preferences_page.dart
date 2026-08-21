import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Sub-setting page for focus / pomodoro preferences.
class FocusPreferencesPage extends StatelessWidget {
  const FocusPreferencesPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final settings = context.watch<SettingsProvider>();

    return Column(
      children: [
        // Header
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
                    Text('Focus Preferences',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Pomodoro durations and auto-start behavior',
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
                // Pomodoro durations
                Text('Pomodoro Durations',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _DurationRow(
                        label: 'Work Session',
                        subtitle: 'How long each focus session lasts',
                        minutes: settings.pomodoroWorkMinutes,
                        color: AppTheme.primary,
                        onChanged: settings.setPomodoroWorkMinutes,
                      ),
                      const Divider(height: 1),
                      _DurationRow(
                        label: 'Short Break',
                        subtitle: 'Rest after a work session',
                        minutes: settings.pomodoroBreakMinutes,
                        color: AppTheme.emerald,
                        onChanged: settings.setPomodoroBreakMinutes,
                      ),
                      const Divider(height: 1),
                      _DurationRow(
                        label: 'Long Break',
                        subtitle: 'Extended rest after multiple sessions',
                        minutes: settings.pomodoroLongBreakMinutes,
                        color: AppTheme.sky,
                        onChanged: settings.setPomodoroLongBreakMinutes,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Auto-start
                Text('Behavior',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: SwitchListTile(
                    title: const Text('Auto-start task timer',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'When starting a focus session attached to a task, automatically start the task\'s timer',
                      style:
                          TextStyle(fontSize: 12, color: colors.textTertiary),
                    ),
                    value: settings.autoStartTaskTimer,
                    onChanged: settings.setAutoStartTaskTimer,
                    secondary: Icon(Icons.timer_outlined,
                        color: AppTheme.primary),
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

class _DurationRow extends StatelessWidget {
  const _DurationRow({
    required this.label,
    required this.subtitle,
    required this.minutes,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final int minutes;
  final Color color;
  final ValueChanged<int> onChanged;

  static const List<int> _presets = [5, 10, 15, 20, 25, 30, 45, 60];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return ListTile(
      leading: Icon(Icons.timer_outlined, color: color),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: colors.textTertiary)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$minutes min',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: colors.textTertiary),
        ],
      ),
      onTap: () => _showDurationPicker(context, colors),
    );
  }

  Future<void> _showDurationPicker(
      BuildContext context, AppThemeColors colors) async {
    int temp = minutes;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              title: Text(label),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$temp minutes',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: color)),
                  const SizedBox(height: 16),
                  Slider(
                    value: temp.toDouble(),
                    min: 1,
                    max: 120,
                    divisions: 119,
                    activeColor: color,
                    label: '$temp min',
                    onChanged: (v) =>
                        setDialogState(() => temp = v.round()),
                  ),
                  const SizedBox(height: 8),
                  Text('Quick select:',
                      style: TextStyle(
                          fontSize: 12, color: colors.textTertiary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final p in _presets)
                        ActionChip(
                          label: Text('${p}m',
                              style: const TextStyle(fontSize: 12)),
                          onPressed: () => setDialogState(() => temp = p),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel',
                      style: TextStyle(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  onPressed: () => Navigator.pop(ctx, temp),
                  child: const Text('Set'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result != null) onChanged(result);
  }
}
