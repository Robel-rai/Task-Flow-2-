import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/color_wheel_picker.dart';

/// Result of the project dialog: the saved project, or a delete request.
class ProjectDialogResult {
  const ProjectDialogResult({required this.project, this.delete = false});

  final Project project;
  final bool delete;
}

/// Create/edit dialog for a project. Pass [project] = null to create.
class ProjectDialog extends StatefulWidget {
  const ProjectDialog({super.key, this.project});

  final Project? project;

  @override
  State<ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<ProjectDialog> {
  late final Project _live;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _color;
  DateTime? _startDate;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _live = widget.project ?? Project(title: '');
    _titleController = TextEditingController(text: _live.title);
    _descriptionController = TextEditingController(text: _live.description);
    _color = _live.color;
    _startDate = _live.startDate;
    _dueDate = _live.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDue) async {
    final current = isDue ? _dueDate : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (isDue) {
        _dueDate = picked;
      } else {
        _startDate = picked;
      }
    });
  }

  Future<void> _deleteProject() async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Delete Project'),
        content: Text('Delete "${_live.title}" permanently? '
            'Its tasks stay in your task list.'),
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
    if (confirmed == true && mounted) {
      Navigator.of(context)
          .pop(ProjectDialogResult(project: _live, delete: true));
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

    final result = ProjectDialogResult(
      project: _live.copyWith(
        title: title,
        description: _descriptionController.text.trim(),
        color: _color,
        startDate: _startDate,
        dueDate: _dueDate,
        clearStartDate: _startDate == null,
        clearDueDate: _dueDate == null,
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
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Project' : 'New Project',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (isEditing)
                    IconButton(
                      tooltip: 'Delete project',
                      icon: Icon(Icons.delete_outline, color: AppTheme.rose),
                      onPressed: _deleteProject,
                    ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      autofocus: !isEditing,
                      decoration: const InputDecoration(hintText: 'Project title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Description (optional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text('Color', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in AppTheme.routineColors.entries)
                          GestureDetector(
                            onTap: () => setState(() => _color = entry.key),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: entry.value,
                                shape: BoxShape.circle,
                                border: _color == entry.key
                                    ? Border.all(
                                        color: colors.textPrimary, width: 2)
                                    : null,
                              ),
                              child: _color == entry.key
                                  ? const Icon(Icons.check,
                                      size: 13, color: Colors.white)
                                  : null,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Custom color',
                        style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    ColorWheel(
                      color: AppTheme.getRoutineColor(_color),
                      onChanged: (c) =>
                          setState(() => _color = AppTheme.colorToHex(c)),
                    ),
                    const SizedBox(height: 16),

                    Text('Dates', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _dateChip(
                          colors,
                          icon: Icons.event,
                          label: _startDate != null
                              ? 'Start ${DateFormat('MMM d, yyyy').format(_startDate!)}'
                              : 'Start date',
                          onTap: () => _pickDate(false),
                          onClear: _startDate != null
                              ? () => setState(() => _startDate = null)
                              : null,
                        ),
                        _dateChip(
                          colors,
                          icon: Icons.flag_outlined,
                          label: _dueDate != null
                              ? 'Due ${DateFormat('MMM d, yyyy').format(_dueDate!)}'
                              : 'Due date',
                          onTap: () => _pickDate(true),
                          onClear: _dueDate != null
                              ? () => setState(() => _dueDate = null)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),

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
                    child: Text(isEditing ? 'Save Changes' : 'Create Project'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(
    AppThemeColors colors, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
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
