import 'package:flutter/material.dart';

import '../../models/project_status.dart';
import '../../repositories/project_status_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/color_wheel_picker.dart';

/// Manager for a project's kanban columns. Edits a local copy of the
/// column list; pops with the saved [ProjectStatus] list (order preserved)
/// on Save, or null on Cancel. An empty list means "use the defaults".
class StatusColumnsDialog extends StatefulWidget {
  const StatusColumnsDialog({super.key, required this.initial});

  /// Current custom statuses of the project (empty = defaults in use).
  final List<ProjectStatus> initial;

  @override
  State<StatusColumnsDialog> createState() => _StatusColumnsDialogState();
}

class _StatusColumnsDialogState extends State<StatusColumnsDialog> {
  late final List<ProjectStatus> _statuses = List.of(widget.initial);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _addStatus() async {
    final result = await showDialog<ProjectStatus>(
      context: context,
      builder: (_) => const _StatusEditDialog(),
    );
    if (result == null || !mounted) return;
    setState(() {
      _statuses.add(ProjectStatus(
        name: result.name,
        color: result.color,
        sortOrder: _statuses.length,
      ));
    });
  }

  Future<void> _editStatus(int index) async {
    final result = await showDialog<ProjectStatus>(
      context: context,
      builder: (_) => _StatusEditDialog(status: _statuses[index]),
    );
    if (result == null || !mounted) return;
    setState(() {
      _statuses[index] = _statuses[index]
          .copyWith(name: result.name, color: result.color);
    });
  }

  void _removeStatus(int index) {
    setState(() => _statuses.removeAt(index));
  }

  void _resetToDefaults() {
    setState(() => _statuses.clear());
    _showMessage('Columns reset to the defaults (Pending, In Progress, '
        'Completed). Save to apply.');
  }

  void _save() {
    final trimmed = _statuses
        .map((s) => s.copyWith(name: s.name.trim()))
        .toList();
    if (trimmed.any((s) => s.name.isEmpty)) {
      _showMessage('Status name is required');
      return;
    }
    final names = trimmed.map((s) => s.name).toList();
    if (names.toSet().length != names.length) {
      _showMessage("Duplicate status names aren't allowed");
      return;
    }
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isEmpty = _statuses.isEmpty;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Columns',
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          'Drag to reorder. Empty = use the defaults.',
                          style: TextStyle(
                              fontSize: 12, color: colors.textTertiary),
                        ),
                      ],
                    ),
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
              child: isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Using the default columns:\n'
                          'Pending  ·  In Progress  ·  Completed\n\n'
                          'Add a custom status below, or press Save to '
                          'keep the defaults.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: colors.textTertiary),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      buildDefaultDragHandles: false,
                      itemCount: _statuses.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _statuses.removeAt(oldIndex);
                          _statuses.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final status = _statuses[index];
                        return ReorderableDragStartListener(
                          key: ValueKey(
                              '${status.id ?? 'new'}-${status.name}-$index'),
                          index: index,
                          child: _StatusRow(
                            status: status,
                            onEdit: () => _editStatus(index),
                            onDelete: () => _removeStatus(index),
                          ),
                        );
                      },
                    ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  onPressed: _resetToDefaults,
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset to defaults'),
                  style: TextButton.styleFrom(
                      foregroundColor: colors.textSecondary),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: TextStyle(color: colors.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addStatus,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add status'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.onEdit,
    required this.onDelete,
  });

  final ProjectStatus status;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.getRoutineColor(status.color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Rename status',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, color: colors.textSecondary),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete status',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline, color: AppTheme.rose),
            onPressed: onDelete,
          ),
          const SizedBox(width: 4),
          Icon(Icons.drag_handle, size: 18, color: colors.textTertiary),
        ],
      ),
    );
  }
}

/// Create/edit dialog for a single status: name + color (presets + wheel).
class _StatusEditDialog extends StatefulWidget {
  const _StatusEditDialog({this.status});

  final ProjectStatus? status;

  @override
  State<_StatusEditDialog> createState() => _StatusEditDialogState();
}

class _StatusEditDialogState extends State<_StatusEditDialog> {
  late final TextEditingController _nameController;
  late String _color;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.status?.name ?? '');
    _color = widget.status?.color ?? 'primary';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status name is required')),
      );
      return;
    }
    Navigator.of(context)
        .pop(ProjectStatus(name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isEditing = widget.status != null;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Status' : 'New Status',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: !isEditing,
                    maxLength: ProjectStatusRepository.maxNameLength,
                    decoration: const InputDecoration(
                      hintText: 'Status name',
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
                            width: 26,
                            height: 26,
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
                                    size: 15, color: Colors.white)
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
                ],
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
                    child: Text(isEditing ? 'Save Changes' : 'Add Status'),
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
