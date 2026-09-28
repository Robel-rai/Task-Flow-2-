import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/auto_backup_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Sub-setting page: "Backup & Restore" (automatic backups).
///
/// Full control surface for the automatic backup & restore feature:
/// master toggle, exact times and days-of-week, backup folder picker,
/// manual actions, backup history with per-file restore/delete, retention,
/// and a status card with last-run timestamps.
class BackupPage extends StatefulWidget {
  const BackupPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  static const _dayLong = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  bool _busy = false;
  bool _historyExpanded = false;

  void _setBusy(bool v) {
    if (mounted) setState(() => _busy = v);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final service = context.watch<AutoBackupService>();

    return Column(
      children: [
        // ── Header — same pattern as the other settings sub-pages ──
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
                    Text('Backup & Restore',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Automatic backups, scheduled restores, and your '
                      'backup history',
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
                // ── General ──
                Text('General', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary:
                            Icon(Icons.backup_outlined, color: colors.primary),
                        title: const Text('Automatic backups',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Create a backup file automatically at the '
                            'scheduled time'),
                        value: service.enabled,
                        onChanged: service.setEnabled,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: Icon(Icons.restore_outlined,
                            color: AppTheme.emerald),
                        title: const Text('Automatic restore',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Replace current data with the newest backup at '
                            'the scheduled time — a safety backup is taken '
                            'first'),
                        value: service.restoreEnabled,
                        onChanged:
                            service.enabled ? service.setRestoreEnabled : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading:
                            Icon(Icons.folder_open, color: colors.primary),
                        title: const Text('Backup folder',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          service.folder.isEmpty
                              ? 'Not set — backups cannot be created until a '
                                  'folder is chosen'
                              : service.folder,
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                        trailing: TextButton.icon(
                          onPressed: _busy ? null : _pickFolder,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Change'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Backup schedule ──
                Text('Backup Schedule',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        enabled: service.enabled,
                        leading: Icon(Icons.schedule, color: colors.primary),
                        title: const Text('Backup time',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text('Time of day to create a backup'),
                        trailing: Text(
                          service.backupTimeLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: service.enabled
                                ? colors.primary
                                : colors.textTertiary,
                          ),
                        ),
                        onTap: service.enabled
                            ? () => _pickTime(isRestore: false)
                            : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        enabled: service.enabled,
                        leading:
                            Icon(Icons.event_repeat, color: colors.primary),
                        title: const Text('Backup days',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _daysLabel(service.backupDays),
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                        onTap: service.enabled
                            ? () => _pickDays(isRestore: false)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Restore schedule ──
                Text('Restore Schedule',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        enabled: service.enabled && service.restoreEnabled,
                        leading:
                            Icon(Icons.schedule, color: AppTheme.emerald),
                        title: const Text('Restore time',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Time of day to restore from the newest backup'),
                        trailing: Text(
                          service.restoreTimeLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                service.enabled && service.restoreEnabled
                                    ? AppTheme.emerald
                                    : colors.textTertiary,
                          ),
                        ),
                        onTap: service.enabled && service.restoreEnabled
                            ? () => _pickTime(isRestore: true)
                            : null,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        enabled: service.enabled && service.restoreEnabled,
                        leading: Icon(Icons.event_repeat,
                            color: AppTheme.emerald),
                        title: const Text('Restore days',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _daysLabel(service.restoreDays),
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                        onTap: service.enabled && service.restoreEnabled
                            ? () => _pickDays(isRestore: true)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Manual actions ──
                Text('Manual Actions',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _PillButton(
                                label: 'Backup now',
                                icon: Icons.backup,
                                color: AppTheme.indigo,
                                onTap: _busy || !service.folderReady
                                    ? null
                                    : () => _doBackup(service),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PillButton(
                                label: 'Restore latest',
                                icon: Icons.restore,
                                color: AppTheme.emerald,
                                onTap: _busy || !service.folderReady
                                    ? null
                                    : () => _confirmRestore(service),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          service.folderReady
                              ? 'Backups are written as JSON files into the '
                                  'selected folder.'
                              : 'Choose a backup folder first — then use '
                                  '"Backup now" or pick a file below to '
                                  'restore.',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Backup history ──
                Text('Backup History',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: _buildHistory(context, service),
                ),
                const SizedBox(height: 24),

                // ── Status ──
                Text('Status', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading:
                            Icon(Icons.info_outline, color: colors.primary),
                        title: const Text('Last backup',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        trailing: Text(
                          _formatStamp(service.lastBackupAt),
                          style: TextStyle(
                              fontSize: 13, color: colors.textSecondary),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading:
                            Icon(Icons.info_outline, color: AppTheme.emerald),
                        title: const Text('Last restore',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: service.lastRestoreSource != null
                            ? Text('From: ${service.lastRestoreSource}',
                                style: TextStyle(
                                    fontSize: 12, color: colors.textTertiary))
                            : null,
                        trailing: Text(
                          _formatStamp(service.lastRestoreAt),
                          style: TextStyle(
                              fontSize: 13, color: colors.textSecondary),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.tune, color: colors.primary),
                        title: const Text('Keep last',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Older backup files are deleted automatically'),
                        trailing: SizedBox(
                          width: 150,
                          child: DropdownButton<int>(
                            value: service.keep,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            items: [
                              for (final n in [5, 10, 15, 30, 60, 90, 365])
                                DropdownMenuItem(
                                    value: n, child: Text('$n backups')),
                            ],
                            onChanged: (v) {
                              if (v != null) service.setKeep(v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── Safety note ──
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading:
                        Icon(Icons.shield_outlined, color: colors.primary),
                    title: const Text('Safety first',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      'Before any restore, TaskFlow saves a fresh safety '
                      'backup of your current data (at most one per 6 '
                      'hours) so you can always undo.',
                      style:
                          TextStyle(fontSize: 12, color: colors.textTertiary),
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

  // ─── History ───

  Widget _buildHistory(BuildContext context, AutoBackupService service) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final files = service.listBackups();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _historyExpanded = !_historyExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.history, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${files.length} backup file${files.length == 1 ? '' : 's'} '
                    'in the selected folder',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  _historyExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (_historyExpanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              children: [
                if (files.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No backup files yet. Create one with "Backup now" or '
                      'wait for the next scheduled backup.',
                      style:
                          TextStyle(fontSize: 12, color: colors.textTertiary),
                    ),
                  )
                else
                  for (var i = 0; i < files.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _buildFileTile(context, service, files[i]),
                  ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFileTile(
      BuildContext context, AutoBackupService service, AutoBackupFile file) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return ListTile(
      dense: true,
      leading: Icon(Icons.description_outlined, color: colors.primary),
      title: Text(file.name,
          style:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${DateFormat('d MMM yyyy, HH:mm').format(file.modified)} · '
        '${file.sizeLabel}',
        style: TextStyle(fontSize: 11, color: colors.textTertiary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Restore from this file',
            icon: Icon(Icons.restore, color: AppTheme.emerald),
            onPressed:
                _busy ? null : () => _confirmRestore(service, path: file.path),
          ),
          IconButton(
            tooltip: 'Delete this backup',
            icon: Icon(Icons.delete_outline, color: AppTheme.rose),
            onPressed: _busy ? null : () => _deleteFile(service, file),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───

  String _formatStamp(DateTime? dt) {
    if (dt == null) return 'Never';
    return DateFormat('d MMM yyyy, HH:mm').format(dt);
  }

  String _daysLabel(Set<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.isEmpty) return 'Never (no days selected)';
    if (days.containsAll({1, 2, 3, 4, 5}) && days.length == 5) {
      return 'Weekdays';
    }
    if (days.containsAll({6, 7}) && days.length == 2) return 'Weekends';
    return [for (final d in days.toList()..sort()) _dayLong[d - 1]]
        .join(', ');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ─── Actions ───

  Future<void> _pickFolder() async {
    final service = context.read<AutoBackupService>();
    final dir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Choose where backups are stored',
      initialDirectory: service.folder.isEmpty ? null : service.folder,
    );
    if (dir == null) return;
    await service.setFolder(dir);
    _snack('Backup folder updated');
  }

  Future<void> _pickTime({required bool isRestore}) async {
    final service = context.read<AutoBackupService>();
    final label =
        isRestore ? service.restoreTimeLabel : service.backupTimeLabel;
    final parts = label.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? (isRestore ? 8 : 20),
        minute: int.tryParse(parts[1]) ?? 0,
      ),
      helpText: isRestore ? 'Restore time' : 'Backup time',
    );
    if (picked == null) return;
    final hhmm = '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    if (isRestore) {
      await service.setRestoreTime(hhmm);
    } else {
      await service.setBackupTime(hhmm);
    }
  }

  Future<void> _pickDays({required bool isRestore}) async {
    final service = context.read<AutoBackupService>();
    final current = isRestore ? service.restoreDays : service.backupDays;
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (_) => _DaysDialog(initial: current),
    );
    if (result == null) return;
    if (isRestore) {
      await service.setRestoreDays(result);
    } else {
      await service.setBackupDays(result);
    }
  }

  Future<void> _doBackup(AutoBackupService service) async {
    _setBusy(true);
    try {
      await service.backupNow();
      _snack('Backup created');
    } catch (e) {
      _snack('Backup failed: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _confirmRestore(AutoBackupService service,
      {String? path}) async {
    final files = service.listBackups();
    final AutoBackupFile file;
    if (path != null) {
      final match = files.where((f) => f.path == path).toList();
      if (match.isEmpty) {
        _snack('That backup file no longer exists');
        return;
      }
      file = match.first;
    } else if (files.isNotEmpty) {
      file = files.first;
    } else {
      _snack('No backup files found in the folder');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: Text(
          'Your current data will be REPLACED by "${file.name}".\n\n'
          'A safety backup of your current data is taken first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _setBusy(true);
    try {
      final result = await service.restoreNow(path: file.path);
      _snack(result == null
          ? 'Restore failed — no data imported'
          : 'Restored ${result.rowsImported} rows from ${result.backupName}');
    } catch (e) {
      _snack('Restore failed: $e');
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _deleteFile(AutoBackupService service, AutoBackupFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete backup?'),
        content:
            Text('"${file.name}" will be removed from disk. This cannot be '
                'undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await service.deleteBackup(file.path);
    _snack('Backup deleted');
  }
}

/// Day-of-week multi-select dialog.
class _DaysDialog extends StatefulWidget {
  const _DaysDialog({required this.initial});

  final Set<int> initial;

  @override
  State<_DaysDialog> createState() => _DaysDialogState();
}

class _DaysDialogState extends State<_DaysDialog> {
  late final Set<int> _selected = Set.of(widget.initial);

  static const _long = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Days of week'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 7; i++)
            CheckboxListTile(
              dense: true,
              title: Text(_long[i]),
              value: _selected.contains(i + 1),
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(i + 1);
                } else {
                  _selected.remove(i + 1);
                }
              }),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Outlined pill button matching the settings home's action buttons.
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
