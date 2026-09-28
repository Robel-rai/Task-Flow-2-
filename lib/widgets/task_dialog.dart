import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/subtask.dart';
import '../models/tag.dart';
import '../models/task.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tasks_provider.dart';
import '../repositories/subtask_repository.dart';
import '../repositories/tag_repository.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'subtask_editor.dart';
import 'tag_dialog.dart';
import 'tag_pill.dart';

/// Result of the task dialog: the saved task, subtasks, and tag ids.
class TaskDialogResult {
  const TaskDialogResult({
    required this.task,
    required this.subtasks,
    required this.tagIds,
  });

  final Task task;
  final List<Subtask> subtasks;
  final List<int> tagIds;
}

/// The one visual style for every dropdown in the task dialog.
///
/// [DropdownButtonFormField.isExpanded] is essential: without it the
/// internal Row sizes itself to the selected item's natural text width,
/// and a long project/category title overflows the field and throws a
/// RenderFlex overflow. The selected label is ellipsized instead.
class TaskDropdown<T> extends StatelessWidget {
  const TaskDropdown({
    super.key,
    required this.labelText,
    required this.items,
    required this.onChanged,
    this.initialValue,
  });

  final String labelText;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final T? initialValue;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: initialValue,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      decoration: InputDecoration(labelText: labelText, isDense: true),
      items: items,
      onChanged: onChanged,
    );
  }
}

/// Create/edit dialog for a task. Pass [task] = null to create.
class TaskDialog extends StatefulWidget {
  const TaskDialog({super.key, this.task});

  final Task? task;

  @override
  State<TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<TaskDialog> {
  static const List<String> _priorities = ['High', 'Medium', 'Low'];
  static const List<String> _defaultStatuses = [
    'Pending',
    'In Progress',
    'Completed',
  ];

  /// Custom status names of the selected project (empty = use defaults).
  List<String> _projectStatuses = const [];
  late final Task _live;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late List<Subtask> _subtasks;
  int? _categoryId;
  int? _projectId;
  late String _priority;
  late String _status;
  DateTime? _scheduledDate;
  String? _scheduledTime;
  DateTime? _dueDate;

  bool _loadingSubtasks = false;

  // ─── Tags ───
  List<Tag> _allTags = [];
  final Set<int> _selectedTagIds = {};
  bool _loadingTags = false;

  @override
  void initState() {
    super.initState();
    _live = widget.task ?? Task(title: '');
    _titleController = TextEditingController(text: _live.title);
    _descriptionController = TextEditingController(text: _live.description);
    _categoryId = _live.categoryId;
    _projectId = _live.projectId;
    _priority = _live.priority;
    _status = _live.status;
    _scheduledDate = _live.scheduledDate;
    _scheduledTime = _live.scheduledTime;
    _dueDate = _live.dueDate;
    _subtasks = [];
    _loadSubtasks();
    _loadTags();
    if (_projectId != null) _loadProjectStatuses();
  }

  /// Status options for the Status dropdown: the selected project's custom
  /// columns when it has any, otherwise the built-in defaults. The task's
  /// current status is always included, so the dropdown never builds
  /// without a matching item (custom statuses load asynchronously).
  List<String> get _statusOptions {
    final base = _projectStatuses.isEmpty ? _defaultStatuses : _projectStatuses;
    if (base.contains(_status)) return base;
    return [if (_status.isNotEmpty) _status, ...base];
  }

  Future<void> _loadProjectStatuses() async {
    final projectId = _projectId;
    final names = projectId == null
        ? const <String>[]
        : (await context.read<ProjectsProvider>().statusesFor(projectId))
            .map((s) => s.name)
            .toList();
    if (!mounted) return;
    setState(() {
      _projectStatuses = names;
      // A brand-new task defaults to 'Pending' — snap it to the project's
      // first column when the project has custom columns, so the saved
      // task is never hidden from the kanban. Editing keeps the task's
      // current status (it's still offered in the dropdown).
      if (_live.id == null) {
        final options = names.isEmpty ? _defaultStatuses : names;
        if (!options.contains(_status)) _status = options.first;
      }
    });
  }

  Future<void> _loadSubtasks() async {
    if (_live.id == null) return;
    setState(() => _loadingSubtasks = true);
    final list = await SubtaskRepository().getForTask(_live.id!);
    if (mounted) {
      setState(() {
        _subtasks = list;
        _loadingSubtasks = false;
      });
    }
  }

  Future<void> _loadTags() async {
    setState(() => _loadingTags = true);
    final tags = await TagRepository().getAll();
    // Load currently assigned tags for existing tasks.
    Set<int> selected = {};
    if (_live.id != null) {
      final assigned = await TagRepository().getTagIdsForTask(_live.id!);
      selected = assigned.toSet();
    }
    if (mounted) {
      setState(() {
        _allTags = tags;
        _selectedTagIds.addAll(selected);
        _loadingTags = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ─── Timer helpers (operate on the live task via the provider) ───

  Future<void> _startTimer() async {
    final updated = await context.read<TasksProvider>().startTimer(_live);
    if (mounted) setState(() => _live = updated);
  }

  Future<void> _stopTimer() async {
    final updated = await context.read<TasksProvider>().stopTimer(_live);
    if (mounted) setState(() => _live = updated);
  }

  Future<void> _deleteTask() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final tasksProvider = context.read<TasksProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Move to Trash'),
        content: Text('Move "${_live.title}" to trash? You can restore it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && _live.id != null) {
      await tasksProvider.trashTask(_live);
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    final result = TaskDialogResult(
      task: _live.copyWith(
        title: title,
        description: _descriptionController.text.trim(),
        categoryId: _categoryId,
        projectId: _projectId,
        priority: _priority,
        status: _status,
        scheduledDate: _scheduledDate,
        scheduledTime: _scheduledTime,
        dueDate: _dueDate,
        clearCategoryId: _categoryId == null,
        clearProjectId: _projectId == null,
        clearScheduledDate: _scheduledDate == null,
        clearScheduledTime: _scheduledTime == null,
        clearDueDate: _dueDate == null,
      ),
      subtasks: _subtasks,
      tagIds: _selectedTagIds.toList(),
    );
    Navigator.of(context).pop(result);
  }

  // ─── Pickers ───

  Future<void> _pickScheduledDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
  }

  Future<void> _pickScheduledTime() async {
    var hour = TimeOfDay.now().hour;
    var minute = TimeOfDay.now().minute;
    if (_scheduledTime != null) {
      final parts = _scheduledTime!.split(':');
      hour = int.parse(parts[0]);
      minute = int.parse(parts[1]);
    }
    final picked = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: hour, minute: minute));
    if (picked != null) {
      setState(() =>
          _scheduledTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _showAddTagDialog() async {
    final result = await showDialog<Tag>(
      context: context,
      builder: (_) => const TagDialog(),
    );
    if (result == null || !mounted) return;
    final tagRepo = TagRepository();
    final id = await tagRepo.insert(result);
    final saved = (await tagRepo.getById(id)) ?? result;
    setState(() {
      _allTags = [..._allTags, saved];
      _selectedTagIds.add(id);
    });
  }

  /// Deletes a tag everywhere (its task links are cleaned up first), then
  /// drops it from the dialog's lists so the chip disappears immediately.
  Future<void> _deleteTag(Tag tag) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Delete Tag'),
        content: Text(
            'Delete "${tag.name}"? It will be removed from every task that uses it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await TagRepository().deleteCompletely(tag.id!);
    if (!mounted) return;
    setState(() {
      _allTags.removeWhere((t) => t.id == tag.id);
      _selectedTagIds.remove(tag.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final settings = context.watch<SettingsProvider>();
    final projects = context.watch<ProjectsProvider>();
    final isEditing = _live.id != null;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
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
                      isEditing ? 'Edit Task' : 'New Task',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (isEditing)
                    IconButton(
                      tooltip: 'Delete task',
                      icon: Icon(Icons.delete_outline, color: AppTheme.rose),
                      onPressed: _deleteTask,
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
                    Text('Task Title',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      autofocus: !isEditing,
                      decoration: const InputDecoration(
                        hintText: 'Task title',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Description',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Description (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category / Priority / Status / Project
                    Row(
                      children: [
                        Expanded(
                          child: TaskDropdown<int?>(
                            initialValue: _categoryId,
                            labelText: 'Category',
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('General')),
                              ...settings.categoryList
                                  .map((c) => DropdownMenuItem<int?>(
                                        value: c.id,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _CategoryColorDot(
                                                colorKey: c.color),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(c.name,
                                                  maxLines: 1,
                                                  overflow: TextOverflow
                                                      .ellipsis),
                                            ),
                                          ],
                                        ),
                                      )),
                            ],
                            onChanged: (v) => setState(() => _categoryId = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TaskDropdown<String>(
                            initialValue: _priority,
                            labelText: 'Priority',
                            items: _priorities
                                .map((p) => DropdownMenuItem<String>(
                                    value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _priority = v ?? 'Medium'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TaskDropdown<String>(
                            // Recreate when the status changes
                            // programmatically (project switch / snap) so
                            // the dropdown always shows the current value.
                            key: ValueKey('status-$_status'),
                            initialValue: _status,
                            labelText: 'Status',
                            items: _statusOptions
                                .map((s) => DropdownMenuItem<String>(
                                    value: s, child: Text(s)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _status = v ?? 'Pending'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TaskDropdown<int?>(
                            initialValue: _projectId,
                            labelText: 'Project',
                            items: [
                              const DropdownMenuItem<int?>(
                                  value: null, child: Text('No project')),
                              ...projects.projectList
                                  .map((p) => DropdownMenuItem<int?>(
                                        value: p.id,
                                        child: Text(p.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                      )),
                            ],
                            onChanged: (v) {
                              setState(() => _projectId = v);
                              _loadProjectStatuses();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Schedule
                    Text('Schedule',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ScheduleChip(
                          icon: Icons.event,
                          label: _scheduledDate != null
                              ? DateFormat('MMM d, yyyy')
                                  .format(_scheduledDate!)
                              : 'Scheduled date',
                          onTap: _pickScheduledDate,
                          onClear: _scheduledDate != null
                              ? () => setState(() => _scheduledDate = null)
                              : null,
                        ),
                        _ScheduleChip(
                          icon: Icons.schedule,
                          label: _scheduledTime ?? 'Time',
                          onTap: _pickScheduledTime,
                          onClear: _scheduledTime != null
                              ? () => setState(() => _scheduledTime = null)
                              : null,
                        ),
                        _ScheduleChip(
                          icon: Icons.flag_outlined,
                          label: _dueDate != null
                              ? 'Due ${DateFormat('MMM d, yyyy').format(_dueDate!)}'
                              : 'Due date',
                          onTap: _pickDueDate,
                          onClear: _dueDate != null
                              ? () => setState(() => _dueDate = null)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Subtasks
                    Text('Subtasks',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    if (_loadingSubtasks)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    else
                      SubtaskEditor(
                        initial: _subtasks,
                        onChanged: (list) => _subtasks = list,
                      ),
                    if (_subtasks.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${_subtasks.where((s) => s.isCompleted).length}/${_subtasks.length} completed',
                        style: TextStyle(
                            fontSize: 12, color: colors.textTertiary),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Tags
                    Row(
                      children: [
                        Text('Tags',
                            style: Theme.of(context).textTheme.labelLarge),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _showAddTagDialog,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('New tag', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_loadingTags)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    else if (_allTags.isEmpty)
                      Text(
                        'No tags yet — create one to get started',
                        style: TextStyle(fontSize: 12, color: colors.textTertiary),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in _allTags)
                            TagPill(
                              tag: tag,
                              selected: _selectedTagIds.contains(tag.id),
                              onToggle: () {
                                setState(() {
                                  if (_selectedTagIds.contains(tag.id)) {
                                    _selectedTagIds.remove(tag.id);
                                  } else {
                                    _selectedTagIds.add(tag.id!);
                                  }
                                });
                              },
                              onDelete: () => _deleteTag(tag),
                            ),
                        ],
                      ),

                    // Timer
                    if (isEditing) ...[
                      const SizedBox(height: 16),
                      Text('Time tracker',
                          style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _live.isTimerRunning
                                  ? Icons.timer
                                  : Icons.timer_outlined,
                              color: _live.isTimerRunning
                                  ? AppTheme.emerald
                                  : colors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _live.formattedTimeSpent,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: colors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              onPressed:
                                  _live.isTimerRunning ? _stopTimer : _startTimer,
                              icon: Icon(
                                _live.isTimerRunning
                                    ? Icons.stop
                                    : Icons.play_arrow,
                                size: 18,
                              ),
                              label: Text(
                                  _live.isTimerRunning ? 'Stop' : 'Start'),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                    child: Text('Cancel',
                        style: TextStyle(color: colors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'Save Changes' : 'Create Task'),
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

/// Small colored circle showing a category's color in the dropdown.
class _CategoryColorDot extends StatelessWidget {
  const _CategoryColorDot({required this.colorKey});

  final String colorKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: AppTheme.getRoutineColor(colorKey),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Small tappable chip for a schedule field with an optional clear (×).
class _ScheduleChip extends StatelessWidget {
  const _ScheduleChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Material(
      color: colors.surfaceVariant.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: colors.textSecondary),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13)),
              if (onClear != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  onTap: onClear,
                  child: Icon(Icons.close,
                      size: 14, color: colors.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
