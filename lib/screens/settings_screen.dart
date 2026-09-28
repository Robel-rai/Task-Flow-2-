import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../database/app_database.dart';
import '../components/settings/about_page.dart';
import '../components/settings/backup_page.dart';
import '../components/settings/categories_page.dart';
import '../components/settings/customization_page.dart';
import '../components/settings/focus_preferences_page.dart';
import '../components/settings/nav_order_page.dart';
import '../components/settings/shortcuts_page.dart';
import '../components/settings/ui_sound_page.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../core/event_bus.dart';
import '../providers/analytics_provider.dart';
import '../providers/tasks_provider.dart';
import '../services/auto_backup_service.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/reporting_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';

/// Settings home. Each entry opens its own sub-setting page; toggles and
/// data tools live here.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showCategories = false;
  bool _showNavOrder = false;
  bool _showCustomization = false;
  bool _showFocusPreferences = false;
  bool _showAbout = false;
  bool _showShortcuts = false;
  bool _showUiSound = false;
  bool _showBackup = false;

  @override
  Widget build(BuildContext context) {
    if (_showCategories) {
      return CategoriesPage(
        onBack: () => setState(() => _showCategories = false),
      );
    }
    if (_showNavOrder) {
      return NavOrderPage(
        onBack: () => setState(() => _showNavOrder = false),
      );
    }
    if (_showCustomization) {
      return CustomizationPage(
        onBack: () => setState(() => _showCustomization = false),
      );
    }
    if (_showFocusPreferences) {
      return FocusPreferencesPage(
        onBack: () => setState(() => _showFocusPreferences = false),
      );
    }
    if (_showShortcuts) {
      return ShortcutsPage(
        onBack: () => setState(() => _showShortcuts = false),
      );
    }
    if (_showUiSound) {
      return UiSoundPage(
        onBack: () => setState(() => _showUiSound = false),
      );
    }
    if (_showAbout) {
      return AboutPage(
        onBack: () => setState(() => _showAbout = false),
      );
    }
    if (_showBackup) {
      return BackupPage(
        onBack: () => setState(() => _showBackup = false),
      );
    }
    return _SettingsHome(
      onOpenCategories: () => setState(() => _showCategories = true),
      onOpenNavOrder: () => setState(() => _showNavOrder = true),
      onOpenCustomization: () => setState(() => _showCustomization = true),
      onOpenFocusPreferences: () => setState(() => _showFocusPreferences = true),
      onOpenAbout: () => setState(() => _showAbout = true),
      onOpenShortcuts: () => setState(() => _showShortcuts = true),
      onOpenUiSound: () => setState(() => _showUiSound = true),
      onOpenBackup: () => setState(() => _showBackup = true),
    );
  }
}

class _SettingsHome extends StatefulWidget {
  const _SettingsHome({
    required this.onOpenCategories,
    required this.onOpenNavOrder,
    required this.onOpenCustomization,
    required this.onOpenFocusPreferences,
    required this.onOpenAbout,
    required this.onOpenShortcuts,
    required this.onOpenUiSound,
    required this.onOpenBackup,
  });

  final VoidCallback onOpenCategories;
  final VoidCallback onOpenNavOrder;
  final VoidCallback onOpenCustomization;
  final VoidCallback onOpenFocusPreferences;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenShortcuts;
  final VoidCallback onOpenUiSound;
  final VoidCallback onOpenBackup;

  @override
  State<_SettingsHome> createState() => _SettingsHomeState();
}

class _SettingsHomeState extends State<_SettingsHome> {
  final NotificationService _notifications = NotificationService(toasts: false);

  bool _breakReminders = true;
  bool _routineReminders = true;
  bool _dueDateReminders = true;
  bool _pendingTasksAlerts = true;
  bool _completionConfirmations = true;
  bool _importing = false;

  // ── Pending tasks schedule ──
  int _pendingStartHour = 8;
  int _pendingStartMinute = 0;
  int _pendingIntervalHours = 1;
  int _pendingRepeatCount = 3;

  // ── Due-date schedule ──
  int _dueDateStartHour = 8;
  int _dueDateStartMinute = 0;
  int _dueDateIntervalHours = 1;
  int _dueDateRepeatCount = 3;
  int _dueDateAdvanceMinutes = 0;

  @override
  void initState() {
    super.initState();
    _loadToggles();
  }

  Future<void> _loadToggles() async {
    final breakOn = await _notifications.breakEnabled;
    final routinesOn = await _notifications.routinesEnabled;
    final dueDateOn = await _notifications.dueDateEnabled;
    final pendingOn = await _notifications.pendingTasksEnabled;
    final completionOn = await _notifications.completionEnabled;
    final startH = await _notifications.pendingStartHour;
    final startM = await _notifications.pendingStartMinute;
    final interval = await _notifications.pendingIntervalHours;
    final repeat = await _notifications.pendingRepeatCount;
    final ddStartH = await _notifications.dueDateStartHour;
    final ddStartM = await _notifications.dueDateStartMinute;
    final ddInterval = await _notifications.dueDateIntervalHours;
    final ddRepeat = await _notifications.dueDateRepeatCount;
    final ddAdvance = await _notifications.dueDateAdvanceMinutes;
    if (!mounted) return;
    setState(() {
      _breakReminders = breakOn;
      _routineReminders = routinesOn;
      _dueDateReminders = dueDateOn;
      _pendingTasksAlerts = pendingOn;
      _completionConfirmations = completionOn;
      _pendingStartHour = startH;
      _pendingStartMinute = startM;
      _pendingIntervalHours = interval;
      _pendingRepeatCount = repeat;
      _dueDateStartHour = ddStartH;
      _dueDateStartMinute = ddStartM;
      _dueDateIntervalHours = ddInterval;
      _dueDateRepeatCount = ddRepeat;
      _dueDateAdvanceMinutes = ddAdvance;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _exportTasksCsv() async {
    final csv = await ReportingService().exportTasksCsv();
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Export tasks',
      fileName:
          'taskflow_tasks_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
      bytes: Uint8List.fromList(utf8.encode(csv)),
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (uri == null || !mounted) return;
    _snack('Tasks exported');
  }

  Future<void> _importTasksCsv() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Import tasks',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (file == null) return;
    setState(() => _importing = true);
    final content = utf8.decode(await file.readAsBytes());
    final count = await ReportingService().importTasksCsv(content);
    if (!mounted) return;
    await context.read<TasksProvider>().refresh();
    EventBus.instance.emit(AppEvent.taskCreated);
    setState(() => _importing = false);
    _snack(count > 0
        ? '$count task${count == 1 ? '' : 's'} imported'
        : 'No tasks found in the file');
  }

  Future<void> _exportCsv(String fileName, Map<String, Object> data) async {
    final csv = await ReportingService().exportAnalyticsCsv(data);
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Export',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(csv)),
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (uri == null || !mounted) return;
    _snack('Exported');
  }

  String _formatScheduleSummary() {
    final h = _pendingStartHour;
    final m = _pendingStartMinute;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final timeStr = '$h12:${m.toString().padLeft(2, '0')} $ampm';
    final pendingIntervalLabel = _pendingIntervalHours == 0 ? '30m' : '${_pendingIntervalHours}h';
    return '$timeStr, every $pendingIntervalLabel, $_pendingRepeatCount times';
  }

  Future<void> _showPendingScheduleDialog(BuildContext context) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    int tempHour = _pendingStartHour;
    int tempMinute = _pendingStartMinute;
    int tempInterval = _pendingIntervalHours;
    int tempRepeat = _pendingRepeatCount;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: AppTheme.indigo.withValues(alpha: 0.3), width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.pending_actions_outlined,
                      color: AppTheme.indigo, size: 22),
                  const SizedBox(width: 10),
                  const Text('Pending Tasks Schedule',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose when to receive pending-task notifications.',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 18),

                  // ── Start Time ──
                  Text('Start Time',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay(
                            hour: tempHour, minute: tempMinute),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: Theme.of(context)
                                  .colorScheme
                                  .copyWith(primary: AppTheme.indigo),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() {
                          tempHour = picked.hour;
                          tempMinute = picked.minute;
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                        color: colors.background,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 18, color: AppTheme.indigo),
                          const SizedBox(width: 10),
                          Text(
                            (() {
                              final h = tempHour;
                              final m = tempMinute;
                              final ampm = h >= 12 ? 'PM' : 'AM';
                              final h12 = h == 0
                                  ? 12
                                  : (h > 12 ? h - 12 : h);
                              return '$h12:${m.toString().padLeft(2, '0')} $ampm';
                            })(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.edit,
                              size: 16, color: colors.textTertiary),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Interval ──
                  Text('Repeat Every',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.border),
                      color: colors.background,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        _IntervalChip(
                          label: '30m',
                          selected: tempInterval == 0,
                          onTap: () => setDialogState(() => tempInterval = 0),
                          colors: colors,
                        ),
                        _IntervalChip(
                          label: '1h',
                          selected: tempInterval == 1,
                          onTap: () => setDialogState(() => tempInterval = 1),
                          colors: colors,
                        ),
                        _IntervalChip(
                          label: '2h',
                          selected: tempInterval == 2,
                          onTap: () => setDialogState(() => tempInterval = 2),
                          colors: colors,
                        ),
                        _IntervalChip(
                          label: '3h',
                          selected: tempInterval == 3,
                          onTap: () => setDialogState(() => tempInterval = 3),
                          colors: colors,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Repeat Count ──
                  Text('Number of Times',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CountButton(
                        icon: Icons.remove,
                        onTap: tempRepeat > 1
                            ? () => setDialogState(() => tempRepeat--)
                            : null,
                        colors: colors,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$tempRepeat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _CountButton(
                        icon: Icons.add,
                        onTap: tempRepeat < 12
                            ? () => setDialogState(() => tempRepeat++)
                            : null,
                        colors: colors,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'time${tempRepeat == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Preview ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.indigo.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppTheme.indigo),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (() {
                              final times = <String>[];
                              for (var i = 0; i < tempRepeat; i++) {
                                int h = tempHour +
                                    (tempInterval == 0 ? 0 : i * tempInterval);
                                int m = tempMinute +
                                    (tempInterval == 0 ? i * 30 : 0);
                                while (m >= 60) {
                                  h += 1;
                                  m -= 60;
                                }
                                final ampm = h >= 12 ? 'PM' : 'AM';
                                final h12 = h == 0
                                    ? 12
                                    : (h > 12 ? h - 12 : h);
                                times.add(
                                    '$h12:${m.toString().padLeft(2, '0')} $ampm');
                              }
                              return 'Notifications at: ${times.join(', ')}';
                            })(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.indigo,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel',
                      style: TextStyle(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await _notifications.setPendingSchedule(
                      startHour: tempHour,
                      startMinute: tempMinute,
                      intervalHours: tempInterval,
                      repeatCount: tempRepeat,
                    );
                    setState(() {
                      _pendingStartHour = tempHour;
                      _pendingStartMinute = tempMinute;
                      _pendingIntervalHours = tempInterval;
                      _pendingRepeatCount = tempRepeat;
                    });
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatDueDateSummary() {
    final h = _dueDateStartHour;
    final m = _dueDateStartMinute;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    final timeStr = '$h12:${m.toString().padLeft(2, '0')} $ampm';
    final advanceStr = _dueDateAdvanceMinutes == 0
        ? 'on time'
        : _dueDateAdvanceMinutes >= 1440
            ? '${_dueDateAdvanceMinutes ~/ 1440}d before'
            : '${_dueDateAdvanceMinutes ~/ 60}h before';
    final ddIntervalLabel = _dueDateIntervalHours == 0 ? '30m' : '${_dueDateIntervalHours}h';
    return '$timeStr, every $ddIntervalLabel, $_dueDateRepeatCount times ($advanceStr)';
  }

  Future<void> _showDueDateScheduleDialog(BuildContext context) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    int tempHour = _dueDateStartHour;
    int tempMinute = _dueDateStartMinute;
    int tempInterval = _dueDateIntervalHours;
    int tempRepeat = _dueDateRepeatCount;
    int tempAdvance = _dueDateAdvanceMinutes;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: AppTheme.rose.withValues(alpha: 0.3), width: 1.5),
              ),
              title: Row(
                children: [
                  const Icon(Icons.notification_important_outlined,
                      color: AppTheme.rose, size: 22),
                  const SizedBox(width: 10),
                  const Text('Due Date Schedule',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose when to receive due-date notifications.',
                      style: TextStyle(fontSize: 13, color: colors.textSecondary),
                    ),
                    const SizedBox(height: 18),

                    // ── Advance Reminder ──
                    Text('Advance Reminder',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                        color: colors.background,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          _IntervalChip(
                            label: 'On time',
                            selected: tempAdvance == 0,
                            onTap: () => setDialogState(() => tempAdvance = 0),
                            colors: colors,
                          ),
                          _IntervalChip(
                            label: '1h before',
                            selected: tempAdvance == 60,
                            onTap: () => setDialogState(() => tempAdvance = 60),
                            colors: colors,
                          ),
                          _IntervalChip(
                            label: '1d before',
                            selected: tempAdvance == 1440,
                            onTap: () => setDialogState(() => tempAdvance = 1440),
                            colors: colors,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Start Time ──
                    Text('Start Time',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary)),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay(
                              hour: tempHour, minute: tempMinute),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: Theme.of(context)
                                    .colorScheme
                                    .copyWith(primary: AppTheme.rose),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            tempHour = picked.hour;
                            tempMinute = picked.minute;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                          color: colors.background,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 18, color: AppTheme.rose),
                            const SizedBox(width: 10),
                            Text(
                              (() {
                                final h = tempHour;
                                final m = tempMinute;
                                final ampm = h >= 12 ? 'PM' : 'AM';
                                final h12 = h == 0
                                    ? 12
                                    : (h > 12 ? h - 12 : h);
                                return '$h12:${m.toString().padLeft(2, '0')} $ampm';
                              })(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.edit,
                                size: 16, color: colors.textTertiary),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Interval ──
                    Text('Repeat Every',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                        color: colors.background,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          _IntervalChip(
                            label: '30m',
                            selected: tempInterval == 0,
                            onTap: () => setDialogState(() => tempInterval = 0),
                            colors: colors,
                          ),
                          _IntervalChip(
                            label: '1h',
                            selected: tempInterval == 1,
                            onTap: () => setDialogState(() => tempInterval = 1),
                            colors: colors,
                          ),
                          _IntervalChip(
                            label: '2h',
                            selected: tempInterval == 2,
                            onTap: () => setDialogState(() => tempInterval = 2),
                            colors: colors,
                          ),
                          _IntervalChip(
                            label: '3h',
                            selected: tempInterval == 3,
                            onTap: () => setDialogState(() => tempInterval = 3),
                            colors: colors,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Repeat Count ──
                    Text('Number of Times',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _CountButton(
                          icon: Icons.remove,
                          onTap: tempRepeat > 1
                              ? () => setDialogState(() => tempRepeat--)
                              : null,
                          colors: colors,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$tempRepeat',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _CountButton(
                          icon: Icons.add,
                          onTap: tempRepeat < 12
                              ? () => setDialogState(() => tempRepeat++)
                              : null,
                          colors: colors,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'time${tempRepeat == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Preview ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.rose.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: AppTheme.rose),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (() {
                                final times = <String>[];
                                for (var i = 0; i < tempRepeat; i++) {
                                  int h = tempHour +
                                      (tempInterval == 0 ? 0 : i * tempInterval);
                                  int m = tempMinute +
                                      (tempInterval == 0 ? i * 30 : 0);
                                  while (m >= 60) {
                                    h += 1;
                                    m -= 60;
                                  }
                                  final ampm = h >= 12 ? 'PM' : 'AM';
                                  final h12 = h == 0
                                      ? 12
                                      : (h > 12 ? h - 12 : h);
                                  times.add(
                                      '$h12:${m.toString().padLeft(2, '0')} $ampm');
                                }
                                final advanceLabel = tempAdvance == 0
                                    ? ''
                                    : tempAdvance >= 1440
                                        ? ' (${tempAdvance ~/ 1440}d before due)'
                                        : ' (${tempAdvance ~/ 60}h before due)';
                                return 'Notifications at: ${times.join(', ')}$advanceLabel';
                              })(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.rose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel',
                      style: TextStyle(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.rose,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await _notifications.setDueDateSchedule(
                      startHour: tempHour,
                      startMinute: tempMinute,
                      intervalHours: tempInterval,
                      repeatCount: tempRepeat,
                      advanceMinutes: tempAdvance,
                    );
                    setState(() {
                      _dueDateStartHour = tempHour;
                      _dueDateStartMinute = tempMinute;
                      _dueDateIntervalHours = tempInterval;
                      _dueDateRepeatCount = tempRepeat;
                      _dueDateAdvanceMinutes = tempAdvance;
                    });
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportAnalyticsCsv() {
    final summary = context.read<AnalyticsProvider>().summary;
    return _exportCsv('taskflow_analytics.csv', {
      'productivity_score': summary?.productivityScore ?? 0,
      'current_streak': summary?.currentStreak ?? 0,
      'max_streak': summary?.maxStreak ?? 0,
      'completion_rate': (summary?.completionRate ?? 0).toStringAsFixed(1),
      'completed_this_week': summary?.completedThisWeek ?? 0,
      'completed_last_week': summary?.completedLastWeek ?? 0,
      'focus_minutes_this_week': summary?.focusMinutesThisWeek ?? 0,
    });
  }

  Future<void> _exportWeeklyReportCsv() {
    final summary = context.read<AnalyticsProvider>().summary;
    final delta =
        (summary?.completedThisWeek ?? 0) - (summary?.completedLastWeek ?? 0);
    return _exportCsv('taskflow_weekly_report.csv', {
      'week_start': DateFormat('yyyy-MM-dd').format(
          DateTime.now().subtract(const Duration(days: 6))),
      'week_end': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'completed_this_week': summary?.completedThisWeek ?? 0,
      'vs_last_week': delta,
      'focus_minutes': summary?.focusMinutesThisWeek ?? 0,
      'current_streak': summary?.currentStreak ?? 0,
      'productivity_score': summary?.productivityScore ?? 0,
    });
  }

  // ── Backup / Restore ──

  // ── JSON Backup / Restore ──

  Future<void> _backupDatabase() async {
    final json = await BackupService().exportJson();
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Backup database',
      fileName: 'taskflow_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (uri == null) return;
    if (!mounted) return;
    _snack('Backup exported successfully');
  }

  Future<void> _restoreDatabase() async {
    final result = await FilePicker.pickFile(
      dialogTitle: 'Restore database',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.path == null) {
      _snack('Selected file not found');
      return;
    }
    final pickedFile = File(result.path!);
    if (!await pickedFile.exists()) {
      _snack('Selected file not found');
      return;
    }
    final content = utf8.decode(await pickedFile.readAsBytes());
    final preview = await BackupService().preview(content);
    if (preview.isEmpty) {
      _snack('No data found in backup file');
      return;
    }
    if (!mounted) return;
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Restore Database'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will replace ALL current data with the backup. '
                'This action cannot be undone.'),
            const SizedBox(height: 12),
            Text('Preview:',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary)),
            const SizedBox(height: 4),
            for (final entry in preview.entries)
              Text('  ${entry.key}: ${entry.value} rows',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final counts = await BackupService().importJson(content);
    if (!mounted) return;
    // Fan out to every data provider (Tasks, Projects, Calendar, Routines,
    // Analytics, Focus) — they all re-query on this event.
    EventBus.instance.emit(AppEvent.dataReset);
    _snack('Restored ${counts.values.fold<int>(0, (a, b) => a + b)} rows across ${counts.length} tables');
  }

  // ── Reset Data (checkboxes) ──

  Future<void> _showResetDialog() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    bool resetCategories = false;
    bool resetProjects = false;
    bool resetTasks = false;
    bool resetRoutines = false;
    bool resetFocus = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              title: Row(
                children: [
                  const Icon(Icons.delete_sweep, color: AppTheme.amber, size: 22),
                  const SizedBox(width: 10),
                  const Text('Reset Data',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select which data to permanently delete. '
                    'This cannot be undone.',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  _ResetCheckbox(
                    label: 'Custom Categories',
                    subtitle: 'All custom task categories',
                    value: resetCategories,
                    onChanged: (v) => setDialogState(() => resetCategories = v ?? false),
                    colors: colors,
                  ),
                  _ResetCheckbox(
                    label: 'Projects',
                    subtitle: 'All projects and their statuses',
                    value: resetProjects,
                    onChanged: (v) => setDialogState(() => resetProjects = v ?? false),
                    colors: colors,
                  ),
                  _ResetCheckbox(
                    label: 'Tasks',
                    subtitle: 'All tasks, subtasks, and tags',
                    value: resetTasks,
                    onChanged: (v) => setDialogState(() => resetTasks = v ?? false),
                    colors: colors,
                  ),
                  _ResetCheckbox(
                    label: 'Routines',
                    subtitle: 'All routines and streaks',
                    value: resetRoutines,
                    onChanged: (v) => setDialogState(() => resetRoutines = v ?? false),
                    colors: colors,
                  ),
                  _ResetCheckbox(
                    label: 'Focus Sessions',
                    subtitle: 'All focus session history',
                    value: resetFocus,
                    onChanged: (v) => setDialogState(() => resetFocus = v ?? false),
                    colors: colors,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.rose,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (!resetCategories && !resetProjects && !resetTasks && !resetRoutines && !resetFocus)
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Delete Selected'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    // Perform the reset
    final db = await AppDatabase.database;
    await db.transaction((txn) async {
      if (resetTasks) {
        await txn.delete('task_tags');
        await txn.delete('subtasks');
        await txn.delete('tasks');
      }
      if (resetRoutines) {
        await txn.delete('routines');
      }
      if (resetProjects) {
        await txn.delete('project_statuses');
        await txn.delete('projects');
      }
      if (resetFocus) {
        await txn.delete('focus_sessions');
      }
      if (resetCategories) {
        await txn.delete('categories');
      }
    });
    if (!mounted) return;
    await context.read<TasksProvider>().refresh();
    _snack('Selected data has been deleted');
  }

  // ── Reset Tasks by Date ──

  Future<void> _showResetTasksDialog() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    DateTime? startDate;
    DateTime? endDate;

    Future<void> pickDate(bool isStart, StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,
        initialDate: isStart
            ? (startDate ?? DateTime.now())
            : (endDate ?? DateTime.now()),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context)
                  .colorScheme
                  .copyWith(primary: AppTheme.rose),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        setDialogState(() {
          if (isStart) {
            startDate = DateTime(picked.year, picked.month, picked.day);
          } else {
            endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
          }
        });
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: colors.surface,
              title: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppTheme.rose, size: 22),
                  const SizedBox(width: 10),
                  const Text('Reset Tasks by Date',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delete all tasks created within the selected date range.',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 18),
                  Text('Start Date',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => pickDate(true, setDialogState),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                        color: colors.background,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event, size: 18, color: AppTheme.rose),
                          const SizedBox(width: 10),
                          Text(
                            startDate != null
                                ? DateFormat('MMM dd, yyyy').format(startDate!)
                                : 'Pick start date',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: startDate != null ? colors.textPrimary : colors.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.edit, size: 16, color: colors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('End Date',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                  const SizedBox(height: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => pickDate(false, setDialogState),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.border),
                        color: colors.background,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event, size: 18, color: AppTheme.rose),
                          const SizedBox(width: 10),
                          Text(
                            endDate != null
                                ? DateFormat('MMM dd, yyyy').format(endDate!)
                                : 'Pick end date',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: endDate != null ? colors.textPrimary : colors.textTertiary,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.edit, size: 16, color: colors.textTertiary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.rose,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (startDate == null || endDate == null)
                      ? null
                      : () => Navigator.pop(ctx, true),
                  child: const Text('Delete Tasks'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || startDate == null || endDate == null) return;

    final db = await AppDatabase.database;
    // Find task IDs in the date range (created_at between start and end)
    final startStr = startDate!.toIso8601String();
    final endStr = endDate!.toIso8601String();
    final rows = await db.query(
      'tasks',
      columns: ['id'],
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [startStr, endStr],
    );
    if (rows.isEmpty) {
      _snack('No tasks found in the selected date range');
      return;
    }
    final ids = rows.map((r) => r['id'] as int).toList();
    final placeholders = ids.map((_) => '?').join(',');
    await db.transaction((txn) async {
      await txn.delete('task_tags', where: 'task_id IN ($placeholders)', whereArgs: ids);
      await txn.delete('subtasks', where: 'task_id IN ($placeholders)', whereArgs: ids);
      await txn.delete('tasks', where: 'id IN ($placeholders)', whereArgs: ids);
    });
    if (!mounted) return;
    await context.read<TasksProvider>().refresh();
    _snack('${ids.length} task${ids.length == 1 ? '' : 's'} deleted');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isCollapsed = AppTheme.isScreenCollapsed(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Column(
      children: [
        // Header
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: colors.background.withValues(alpha: 0.5),
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              if (isCollapsed) ...[
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Settings',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'App preferences',
                      style: TextStyle(
                          fontSize: 12, color: colors.textTertiary),
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
                // ── Theme Mode ──
                Text('Appearance',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.palette_outlined,
                            color: colors.primary),
                        title: const Text('Theme Mode',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _ThemeModeRadio(
                          mode: ThemeMode.dark,
                          label: 'Dark Mode',
                          icon: Icons.dark_mode_outlined,
                          groupValue: themeProvider.themeMode,
                          onChanged: themeProvider.setThemeMode,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _ThemeModeRadio(
                          mode: ThemeMode.light,
                          label: 'Light Mode',
                          icon: Icons.light_mode_outlined,
                          groupValue: themeProvider.themeMode,
                          onChanged: themeProvider.setThemeMode,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _ThemeModeRadio(
                          mode: ThemeMode.system,
                          label: 'System / Auto',
                          icon: Icons.phone_android,
                          groupValue: themeProvider.themeMode,
                          onChanged: themeProvider.setThemeMode,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.tune, color: colors.primary),
                        title: const Text('More Options',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          'Custom colors & fonts',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                        trailing: Icon(Icons.chevron_right,
                            color: colors.textTertiary),
                        onTap: widget.onOpenCustomization,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── General ──
                Text('General',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.label_outline,
                            color: colors.primary),
                        title: const Text('Categories and Tags',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Manage the categories and tags used to organize and filter your tasks'),
                        trailing:
                            Icon(Icons.chevron_right, color: colors.textTertiary),
                        onTap: widget.onOpenCategories,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.timer_outlined,
                            color: colors.primary),
                        title: const Text('Focus Preferences',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Pomodoro durations and auto-start settings'),
                        trailing:
                            Icon(Icons.chevron_right, color: colors.textTertiary),
                        onTap: widget.onOpenFocusPreferences,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.music_note_outlined,
                            color: colors.primary),
                        title: const Text('UI Sound & Customization',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Feedback sounds for actions and ongoing states'),
                        trailing:
                            Icon(Icons.chevron_right, color: colors.textTertiary),
                        onTap: widget.onOpenUiSound,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Relive the Experience ──
                Text('Relive the Experience', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.play_circle_outline, color: colors.primary),
                        title: const Text('Show Splash Screen', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Replay the app introduction'),
                        trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
                        onTap: () async { await SplashScreen.resetFlag(); if (context.mounted) { Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
          ); } },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.school_outlined, color: AppTheme.indigo),
                        title: const Text('Show Onboarding', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Replay the setup wizard'),
                        trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
                        onTap: () async { await OnboardingScreen.resetFlag(); if (context.mounted) { Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
          ); } },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── About ──
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Icon(Icons.help_outline,
                        color: colors.primary),
                    title: const Text('About',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text(
                        'Version, credits, and license'),
                    trailing:
                        Icon(Icons.chevron_right, color: colors.textTertiary),
                    onTap: widget.onOpenAbout,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Navigation ──
                Text('Navigation',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.view_agenda_outlined,
                            color: colors.primary),
                        title: const Text('Sidebar order',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Drag to rearrange the sidebar navigation buttons'),
                        trailing:
                            Icon(Icons.chevron_right, color: colors.textTertiary),
                        onTap: widget.onOpenNavOrder,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.keyboard, color: colors.primary),
                        title: const Text('Keyboard Shortcuts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('View and customize all keyboard shortcuts'),
                        trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
                        onTap: widget.onOpenShortcuts,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Notifications ──
                Text('Notifications',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.self_improvement,
                            color: AppTheme.emerald),
                        title: const Text('Break reminders',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Remind me to take a break after 2 hours of '
                            'continuous focus'),
                        value: _breakReminders,
                        onChanged: (v) async {
                          setState(() => _breakReminders = v);
                          await _notifications.setBreakEnabled(v);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.repeat,
                            color: AppTheme.amber),
                        title: const Text('Routine reminders',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Remind me once per day when a routine is due'),
                        value: _routineReminders,
                        onChanged: (v) async {
                          setState(() => _routineReminders = v);
                          await _notifications.setRoutinesEnabled(v);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.notification_important_outlined,
                            color: AppTheme.rose),
                        title: const Text('Due date reminders',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _dueDateReminders
                              ? _formatDueDateSummary()
                              : 'Show a popup and notification when a task is due',
                          style: TextStyle(
                            fontSize: 12,
                            color: _dueDateReminders
                                ? AppTheme.rose
                                : colors.textTertiary,
                          ),
                        ),
                        trailing: Switch(
                          value: _dueDateReminders,
                          onChanged: (v) async {
                            setState(() => _dueDateReminders = v);
                            await _notifications.setDueDateEnabled(v);
                          },
                        ),
                        onTap: _dueDateReminders
                            ? () => _showDueDateScheduleDialog(context)
                            : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.pending_actions_outlined,
                            color: AppTheme.indigo),
                        title: const Text('Pending tasks alerts',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _pendingTasksAlerts
                              ? _formatScheduleSummary()
                              : 'Show a popup listing all pending tasks',
                          style: TextStyle(
                            fontSize: 12,
                            color: _pendingTasksAlerts
                                ? AppTheme.indigo
                                : colors.textTertiary,
                          ),
                        ),
                        trailing: Switch(
                          value: _pendingTasksAlerts,
                          onChanged: (v) async {
                            setState(() => _pendingTasksAlerts = v);
                            await _notifications.setPendingTasksEnabled(v);
                          },
                        ),
                        onTap: _pendingTasksAlerts
                            ? () => _showPendingScheduleDialog(context)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.check_circle_outline,
                            color: AppTheme.emerald),
                        title: const Text('Completion confirmations',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Notify me when I mark a task as completed'),
                        value: _completionConfirmations,
                        onChanged: (v) async {
                          setState(() => _completionConfirmations = v);
                          await _notifications.setCompletionEnabled(v);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Data ──
                Text('Data',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.upload_file,
                            color: colors.primary),
                        title: const Text('Export tasks (CSV)',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Save all active tasks to a spreadsheet file'),
                        onTap: _exportTasksCsv,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.download,
                            color: colors.primary),
                        title: Text(
                            _importing ? 'Importing…' : 'Import tasks (CSV)',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Load tasks from an exported CSV file'),
                        onTap: _importing ? null : _importTasksCsv,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.bar_chart,
                            color: AppTheme.blue),
                        title: const Text('Export analytics (CSV)',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Productivity score, streaks, and weekly totals'),
                        onTap: _exportAnalyticsCsv,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.description_outlined,
                            color: AppTheme.blue),
                        title: const Text('Export weekly report (CSV)',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'This week vs last week summary'),
                        onTap: _exportWeeklyReportCsv,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Backup & Reset ──
                Text('Backup & Reset',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListenableBuilder(
                        listenable: context.read<AutoBackupService>(),
                        builder: (context, _) {
                          final auto = context.read<AutoBackupService>();
                          return ListTile(
                            leading: Icon(Icons.auto_awesome,
                                color: AppTheme.indigo),
                            title: const Text('Automatic Backup & Restore',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              auto.enabled
                                  ? 'On · backup ${auto.backupTimeLabel} · '
                                      'restore ${auto.restoreEnabled ? auto.restoreTimeLabel : 'off'}'
                                  : 'Off',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textTertiary),
                            ),
                            trailing: Switch(
                              value: auto.enabled,
                              onChanged: auto.setEnabled,
                            ),
                            onTap: widget.onOpenBackup,
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.settings_backup_restore,
                            color: colors.primary),
                        title: const Text('Backup & Restore Settings',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Schedules, backup folder, history, and manual '
                            'backup / restore'),
                        trailing: Icon(Icons.chevron_right,
                            color: colors.textTertiary),
                        onTap: widget.onOpenBackup,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _PillButton(
                        label: 'Backup',
                        icon: Icons.backup,
                        color: AppTheme.indigo,
                        onTap: _backupDatabase,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PillButton(
                        label: 'Restore',
                        icon: Icons.restore,
                        color: AppTheme.emerald,
                        onTap: _restoreDatabase,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.delete_sweep,
                            color: AppTheme.amber),
                        title: const Text('Reset Data',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Choose which data to clear'),
                        trailing: Icon(Icons.chevron_right,
                            color: colors.textTertiary),
                        onTap: _showResetDialog,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.calendar_today,
                            color: AppTheme.rose),
                        title: const Text('Reset Tasks by Date',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Delete all tasks within a date range'),
                        trailing: Icon(Icons.chevron_right,
                            color: colors.textTertiary),
                        onTap: _showResetTasksDialog,
                      ),
                    ],
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

/// Radio button row for a single theme mode option.
class _ThemeModeRadio extends StatelessWidget {
  const _ThemeModeRadio({
    required this.mode,
    required this.label,
    required this.icon,
    required this.groupValue,
    required this.onChanged,
  });

  final ThemeMode mode;
  final String label;
  final IconData icon;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final selected = mode == groupValue;

    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => onChanged(mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
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
              Icon(icon,
                  size: 20,
                  color: selected ? colors.primary : colors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected
                        ? colors.primary
                        : colors.textPrimary,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? colors.primary : colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small selectable chip for the interval picker.
class _IntervalChip extends StatelessWidget {
  const _IntervalChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.indigo.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.indigo : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Plus / minus button for the repeat-count picker.
class _CountButton extends StatelessWidget {
  const _CountButton({
    required this.icon,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap != null
          ? AppTheme.indigo.withValues(alpha: 0.10)
          : colors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 18,
            color: onTap != null ? AppTheme.indigo : colors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Checkbox row for the Reset Data dialog.
class _ResetCheckbox extends StatelessWidget {
  const _ResetCheckbox({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool?> onChanged;
  final AppThemeColors colors;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.rose,
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: colors.textTertiary)),
    );
  }
}

/// Pill-shaped button used in the Backup & Reset section.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
