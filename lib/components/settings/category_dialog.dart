import 'package:flutter/material.dart';

import '../../models/category.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/color_wheel_picker.dart';

/// Create/edit dialog for a task category. Pass [category] = null to
/// create a new one. On save it pops with the [Category] (name + color
/// filled in, id preserved when editing), or null when cancelled.
class CategoryDialog extends StatefulWidget {
  const CategoryDialog({super.key, this.category});

  final Category? category;

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  late final TextEditingController _nameController;
  late String _color;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.category?.name ?? '');
    _color = widget.category?.color ?? 'primary';
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
        const SnackBar(content: Text('Category name is required')),
      );
      return;
    }
    if (name.length > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Category name must be 12 characters or fewer')),
      );
      return;
    }
    final base = widget.category ?? Category(name: name);
    Navigator.of(context).pop(base.copyWith(name: name, color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isEditing = widget.category != null;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
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
                      isEditing ? 'Edit Category' : 'New Category',
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

            // Body
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: !isEditing,
                    maxLength: 12,
                    decoration: const InputDecoration(
                      hintText: 'Category name',
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
                    child: Text(isEditing ? 'Save Changes' : 'Add Category'),
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
