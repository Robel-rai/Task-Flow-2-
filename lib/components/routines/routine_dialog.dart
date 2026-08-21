import 'package:flutter/material.dart';

import '../../models/routine.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/color_wheel_picker.dart';

/// Result of the routine dialog: the saved routine, or a delete request.
class RoutineDialogResult {
  const RoutineDialogResult({required this.routine, this.delete = false});

  final Routine routine;
  final bool delete;
}

/// Create/edit dialog for a routine habit. Pass [routine] = null to create.
class RoutineDialog extends StatefulWidget {
  const RoutineDialog({super.key, this.routine});

  final Routine? routine;

  @override
  State<RoutineDialog> createState() => _RoutineDialogState();
}

class _RoutineDialogState extends State<RoutineDialog> {
  static const List<String> _dayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  late final Routine _live;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late TimeOfDay _time;
  late Set<int> _daysOfWeek;
  late String _color;
  late bool _notifications;

  @override
  void initState() {
    super.initState();
    _live = widget.routine ?? Routine(title: '', scheduledTime: '08:00');
    _titleController = TextEditingController(text: _live.title);
    _descriptionController = TextEditingController(text: _live.description);
    _time = _live.timeOfDay;
    _daysOfWeek = Set.of(_live.daysOfWeek);
    _color = _live.color;
    _notifications = _live.notificationEnabled;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  static String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _deleteRoutine() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Delete Routine'),
        content: Text('Delete "${_live.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(
        context,
      ).pop(RoutineDialogResult(routine: _live, delete: true));
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Title is required')));
      return;
    }
    if (_daysOfWeek.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick at least one day')));
      return;
    }

    final result = RoutineDialogResult(
      routine: _live.copyWith(
        title: title,
        description: _descriptionController.text.trim(),
        scheduledTime:
            '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
        daysOfWeek: _daysOfWeek,
        color: _color,
        notificationEnabled: _notifications,
      ),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isEditing = _live.id != null;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Routine' : 'New Routine',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (isEditing)
                    IconButton(
                      tooltip: 'Delete routine',
                      icon: Icon(Icons.delete_outline, color: AppTheme.rose),
                      onPressed: _deleteRoutine,
                    ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      autofocus: !isEditing,
                      decoration: const InputDecoration(
                        hintText: 'Routine title',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Description (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Time', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Material(
                      color: colors.surfaceVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 16,
                                color: colors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatTime(_time),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Repeat on',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (var i = 0; i < 7; i++)
                          FilterChip(
                            label: Text(_dayLabels[i]),
                            visualDensity: VisualDensity.compact,
                            selected: _daysOfWeek.contains(i + 1),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                _daysOfWeek.add(i + 1);
                              } else {
                                _daysOfWeek.remove(i + 1);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Color',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in AppTheme.routineColors.entries)
                          GestureDetector(
                            onTap: () => setState(() => _color = entry.key),
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: entry.value,
                                shape: BoxShape.circle,
                                border: _color == entry.key
                                    ? Border.all(
                                        color: colors.textPrimary,
                                        width: 2,
                                      )
                                    : null,
                              ),
                              child: _color == entry.key
                                  ? const Icon(
                                      Icons.check,
                                      size: 15,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Custom color',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    ColorWheel(
                      color: AppTheme.getRoutineColor(_color),
                      onChanged: (c) =>
                          setState(() => _color = AppTheme.colorToHex(c)),
                    ),
                    const SizedBox(height: 8),

                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Remind me'),
                      subtitle: const Text('In-app and toast notifications'),
                      value: _notifications,
                      onChanged: (v) => setState(() => _notifications = v),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'Save Changes' : 'Create Routine'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
