import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/category.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import 'category_dialog.dart';

/// The Categories sub-setting: full category management (create, rename,
/// recolor, delete). Opened from the Settings home via [onBack] to return.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key, required this.onBack});

  final VoidCallback onBack;

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

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
                onPressed: onBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Categories',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'Used when creating tasks and filtering. '
                      'Create your own or rename and recolor the defaults.',
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
