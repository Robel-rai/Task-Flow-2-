import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/category.dart';
import '../../models/tag.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../repositories/tag_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tag_dialog.dart';
import '../../widgets/tag_pill.dart';
import 'category_dialog.dart';

/// The "Categories and Tags" sub-setting: full category management
/// (create, rename, recolor, delete) plus tag management (create, delete)
/// rendered as pill-shaped chips below the categories section.
/// Opened from the Settings home via [onBack] to return.
class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  List<Tag> _tags = [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await TagRepository().getAll();
    if (mounted) setState(() => _tags = tags);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  // ─── Categories ───

  Future<void> _addCategory(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final result = await showDialog<Category>(
      context: context,
      builder: (_) => const CategoryDialog(),
    );
    if (result == null || !context.mounted) return;
    try {
      await settings.addCategory(result.name, color: result.color);
    } on DatabaseException {
      if (!context.mounted) return;
      _showMessage(context, 'A category with that name already exists');
    }
  }

  Future<void> _editCategory(
      BuildContext context, Category category) async {
    final settings = context.read<SettingsProvider>();
    final result = await showDialog<Category>(
      context: context,
      builder: (_) => CategoryDialog(category: category),
    );
    if (result == null || !context.mounted) return;
    try {
      await settings.updateCategory(
          category.copyWith(name: result.name, color: result.color));
    } on DatabaseException {
      if (!context.mounted) return;
      _showMessage(context, 'A category with that name already exists');
    }
  }

  Future<void> _deleteCategory(
      BuildContext context, Category category) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final settings = context.read<SettingsProvider>();

    if (category.name == 'General') {
      _showMessage(
          context, "General is the default category and can't be deleted.");
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Delete Category'),
        content: Text(
            'Delete "${category.name}"? Tasks using it will move to General.'),
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
    if (confirmed != true || !context.mounted) return;

    await settings.deleteCategory(category.id!);
    if (!context.mounted) return;

    // A filter pointing at the deleted category would leave the tasks
    // filter dropdown with no matching item — clear it.
    final tasks = context.read<TasksProvider>();
    if (tasks.categoryFilter == category.id) {
      tasks.setCategoryFilter(null);
    }
  }

  // ─── Tags ───

  Future<void> _addTag() async {
    final result = await showDialog<Tag>(
      context: context,
      builder: (_) => const TagDialog(),
    );
    if (result == null) return;
    try {
      await TagRepository().insert(result);
      await _loadTags();
    } on DatabaseException {
      if (!mounted) return;
      _showMessage(context, 'A tag with that name already exists');
    }
  }

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

    // A filter pointing at the deleted tag would leave the tasks filter
    // dropdown with no matching item — clear it.
    if (mounted) {
      final tasks = context.read<TasksProvider>();
      if (tasks.tagFilter == tag.id) {
        tasks.setTagFilter(null);
      }
    }
    await _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final settings = context.watch<SettingsProvider>();
    final categories = settings.categoryList;

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
                onPressed: widget.onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Categories and Tags',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Categories group your tasks; tags label them with '
                      'flexible keywords you can search and filter by.',
                      style: TextStyle(
                          fontSize: 12, color: colors.textTertiary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => _addCategory(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add category'),
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
                // ── Categories section ──
                Text('Categories',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < categories.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _CategoryRow(
                          category: categories[i],
                          onEdit: () => _editCategory(context, categories[i]),
                          onDelete: () =>
                              _deleteCategory(context, categories[i]),
                        ),
                      ],
                      if (categories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No categories yet',
                              style: TextStyle(
                                  color: colors.textTertiary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Tags section ──
                Text('Tags',
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
                              child: Text(
                                'Pill-shaped labels you can attach to tasks '
                                'and use as filters',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colors.textTertiary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _addTag,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add tag'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_tags.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'No tags yet — click "Add tag" to create one',
                              style: TextStyle(color: colors.textTertiary),
                            ),
                          )
                        else
                          // Pills sit side by side filling the row width and
                          // wrap downward automatically.
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in _tags)
                                TagPill(
                                  tag: tag,
                                  onDelete: () => _deleteTag(tag),
                                ),
                            ],
                          ),
                      ],
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
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final canDelete = category.name != 'General';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: AppTheme.getRoutineColor(category.color),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(category.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Rename category',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, color: colors.textSecondary),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: canDelete
                ? 'Delete category'
                : 'General is the default category',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline,
                color: canDelete ? AppTheme.rose : colors.textTertiary),
            onPressed: canDelete ? onDelete : null,
          ),
        ],
      ),
    );
  }
}
