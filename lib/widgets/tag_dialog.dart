import 'package:flutter/material.dart';

import '../models/tag.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Create / edit dialog for a tag.  Returns the saved [Tag] on confirm.
class TagDialog extends StatefulWidget {
  const TagDialog({super.key, this.tag});

  /// Existing tag to edit; null = create new.
  final Tag? tag;

  @override
  State<TagDialog> createState() => _TagDialogState();
}

class _TagDialogState extends State<TagDialog> {
  late final TextEditingController _nameController;
  late String _color;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.tag?.name ?? '');
    _color = widget.tag?.color ?? 'primary';
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
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    Navigator.of(context).pop(
      Tag(id: widget.tag?.id, name: name, color: _color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isEditing = widget.tag != null;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Tag' : 'New Tag',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Text('Name', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                autofocus: !isEditing,
                decoration: const InputDecoration(hintText: 'Tag name'),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 16),
              Text('Color', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _tagColors.entries)
                    GestureDetector(
                      onTap: () => setState(() => _color = entry.key),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: entry.value,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == entry.key
                                ? colors.textPrimary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: _color == entry.key
                            ? Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
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
                    child: Text(isEditing ? 'Save Changes' : 'Create Tag'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Named color presets for tags, matching the app's palette.
Map<String, Color> get _tagColors => AppTheme.routineColors;
