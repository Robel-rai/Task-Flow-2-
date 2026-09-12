import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/focus_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../services/focus_service.dart';
import '../services/notification_service.dart';
import '../services/ui_sound_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Formats seconds as `h:mm:ss` (or `mm:ss` under an hour).
String formatFocusDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Circular focus/pomodoro timer: configurable target duration, an
/// attached task, and start / pause / resume / stop controls. Auto-stops
/// (and records) the session when the target duration is reached.
class FocusTimer extends StatefulWidget {
  const FocusTimer({super.key});

  @override
  State<FocusTimer> createState() => _FocusTimerState();
}

class _FocusTimerState extends State<FocusTimer> {
  Timer? _ticker;
  int? _targetMinutes;
  int? _selectedTaskId;

  final NotificationService _notifications = NotificationService();

  // Captured in initState — reading context in dispose() is unsafe.
  late final FocusProvider _provider;
  late final TasksProvider _tasksProvider;

  List<int?> get _durations {
    final settings = context.read<SettingsProvider>();
    final work = settings.pomodoroWorkMinutes;
    return [15, work, 45, 60, null];
  }

  @override
  void initState() {
    super.initState();
    _provider = context.read<FocusProvider>();
    _tasksProvider = context.read<TasksProvider>();
    _targetMinutes = context.read<SettingsProvider>().pomodoroWorkMinutes;
    _provider.addListener(_syncTicker);
    _tasksProvider.addListener(_syncSelectedTask);
    _syncTicker();
  }

  @override
  void dispose() {
    _provider.removeListener(_syncTicker);
    _tasksProvider.removeListener(_syncSelectedTask);
    _ticker?.cancel();
    super.dispose();
  }

  /// The attach-selection can outlive its task: the dropdown's items come
  /// from the (filtered) task list, so a task hidden by the Tasks date
  /// filter, completed, or deleted would leave the dropdown holding a
  /// value with no matching item (which Flutter asserts against). Fall
  /// back to "No task (unfocused)" instead.
  void _syncSelectedTask() {
    final selected = _selectedTaskId;
    if (selected == null) return;
    final stillAvailable = _tasksProvider.tasks
        .where((t) => t.status != 'Completed')
        .any((t) => t.id == selected);
    if (!stillAvailable && mounted) {
      setState(() => _selectedTaskId = null);
    }
  }

  /// Runs a 1s ticker only while a session is active and unpaused.
  void _syncTicker() {
    final session = _provider.activeSession;
    final shouldTick =
        session != null && session.isRunning && !session.isPaused;
    if (shouldTick && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } else if (!shouldTick && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  Future<void> _tick() async {
    if (!mounted) return;
    final session = _provider.activeSession;
    if (session == null || !session.isRunning || session.isPaused) return;

    // Break reminder: fires once per session when the continuous-focus
    // threshold is crossed (2h), then never again for that session.
    if (await _notifications.shouldShowBreakReminder(session)) {
      UiSoundService.instance.reminderFired();
      await _notifications.showToast(
        title: 'Time for a break',
        body: 'You\'ve been focusing for over '
            '${formatFocusDuration(FocusService.breakThresholdSeconds)}. '
            'Stand up and stretch.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Time for a break — you\'ve been focusing '
              'for over 2 hours. Stand up and stretch.'),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_targetMinutes != null &&
        session.currentDurationSeconds >= _targetMinutes! * 60) {
      // Reaches target → completion cue (not the early-stop one).
      _provider.complete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session complete — '
                '${formatFocusDuration(_targetMinutes! * 60)} 🎉'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    setState(() {}); // refresh the ring + elapsed text
  }

  Future<void> _start() async {
    await _provider.start(taskId: _selectedTaskId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    // watch() registers the rebuild dependency so the ring and buttons
    // follow the provider (start/pause/resume/stop) without a tick.
    final provider = context.watch<FocusProvider>();
    final session = provider.activeSession;
    final active = session != null && session.isRunning;
    final paused = session?.isPaused ?? false;
    final elapsed = session?.currentDurationSeconds ?? 0;
    final target = _targetMinutes != null ? _targetMinutes! * 60 : null;

    final double progress;
    if (target != null) {
      progress = (elapsed / target).clamp(0.0, 1.0);
    } else {
      progress = (elapsed % 3600) / 3600; // rolling hour for manual mode
    }
    final ringColor = paused
        ? AppTheme.amber
        : (active ? AppTheme.emerald : AppTheme.primary);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Focus Timer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          SizedBox(
            width: 230,
            height: 230,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  backgroundColor: colors.surfaceVariant,
                  color: ringColor,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatFocusDuration(elapsed),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        paused
                            ? 'Paused'
                            : (active
                                ? (target != null
                                    ? '${formatFocusDuration(target - elapsed)} left'
                                    : 'Focusing')
                                : 'Ready'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ringColor,
                        ),
                      ),
                      if (active && _taskName(context) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _taskName(context)!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: colors.textTertiary),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Task attach picker (disabled while a session is active).
          DropdownButtonFormField<int?>(
            initialValue: _selectedTaskId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Attach to task',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('No task (unfocused)')),
              ...context
                  .watch<TasksProvider>()
                  .tasks
                  .where((t) => t.status != 'Completed')
                  .map((t) => DropdownMenuItem<int?>(
                        value: t.id,
                        child: Text(t.title, overflow: TextOverflow.ellipsis),
                      )),
            ],
            onChanged:
                active ? null : (v) => setState(() => _selectedTaskId = v),
          ),
          const SizedBox(height: 12),

          // Target duration selector (disabled while active).
          Wrap(
            spacing: 6,
            children: [
              for (final minutes in _durations)
                ChoiceChip(
                  label: Text(minutes == null
                      ? '∞'
                      : '${minutes}m'),
                  selected: _targetMinutes == minutes,
                  onSelected:
                      active ? null : (_) => setState(() => _targetMinutes = minutes),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Controls
          if (!active)
            ElevatedButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Start Session'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(180, 44),
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: paused ? _provider.resume : _provider.pause,
                  icon: Icon(
                      paused ? Icons.play_arrow : Icons.pause, size: 18),
                  label: Text(paused ? 'Resume' : 'Pause'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(110, 44),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _provider.stop,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.rose,
                    minimumSize: const Size(110, 44),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String? _taskName(BuildContext context) {
    final session = context.watch<FocusProvider>().activeSession;
    final taskId = session?.taskId;
    if (taskId == null) return null;
    for (final task in context.read<TasksProvider>().tasks) {
      if (task.id == taskId) return task.title;
    }
    return null;
  }
}
