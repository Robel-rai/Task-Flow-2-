import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/tag.dart';
import '../../providers/settings_provider.dart';
import '../../providers/tasks_provider.dart';
import '../../repositories/tag_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/date_range_selector.dart';

/// Stacked filters + view toggle for the tasks list.
class FilterChipBar extends StatefulWidget {
  const FilterChipBar({
    super.key,
    required this.gridView,
    required this.onViewChanged,
  });

  final bool gridView;
  final ValueChanged<bool> onViewChanged;

  @override
  State<FilterChipBar> createState() => _FilterChipBarState();
}

class _FilterChipBarState extends State<FilterChipBar> {
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final tasks = context.watch<TasksProvider>();
    final settings = context.watch<SettingsProvider>();

    final hasActiveFilters = tasks.searchQuery.isNotEmpty ||
        tasks.categoryFilter != null ||
        tasks.statusFilter != null ||
        tasks.priorityFilter != null ||
        tasks.startDateFilter != null ||
        tasks.tagFilter != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final categoryDropdown = DropdownButtonFormField<int?>(
            initialValue: tasks.categoryFilter,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Category', isDense: true),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All')),
              ...settings.categoryList
                  .map((c) => DropdownMenuItem<int?>(
                      value: c.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CategoryColorDot(colorKey: c.color),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(c.name,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ))),
            ],
            onChanged: tasks.setCategoryFilter,
          );

          final statusDropdown = DropdownButtonFormField<String?>(
            initialValue: tasks.statusFilter,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Status', isDense: true),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All')),
              for (final s in ['Pending', 'In Progress', 'Completed'])
                DropdownMenuItem<String?>(value: s, child: Text(s)),
            ],
            onChanged: tasks.setStatusFilter,
          );

          final priorityDropdown = DropdownButtonFormField<String?>(
            initialValue: tasks.priorityFilter,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Priority', isDense: true),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('All')),
              for (final p in ['High', 'Medium', 'Low'])
                DropdownMenuItem<String?>(value: p, child: Text(p)),
            ],
            onChanged: tasks.setPriorityFilter,
          );

          final tagDropdown = DropdownButtonFormField<int?>(
            initialValue: tasks.tagFilter,
            borderRadius: BorderRadius.circular(12),
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: 'Tag', isDense: true),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All')),
              for (final tag in _tags)
                DropdownMenuItem<int?>(
                  value: tag.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle,
                          size: 10,
                          color: AppTheme.getRoutineColor(tag.color)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(tag.name, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: tasks.setTagFilter,
          );

          final dateDropdown = DateRangeSelector(
            start: tasks.startDateFilter,
            end: tasks.endDateFilter,
            onRangeSelected: tasks.setDateRangeFilter,
          );

          final clearButton = IconButton(
            tooltip: 'Clear all filters',
            icon: Icon(Icons.filter_alt_off, color: colors.textSecondary),
            onPressed: tasks.clearFilters,
          );

          final viewToggle = IconButton(
            tooltip: widget.gridView ? 'Switch to list view' : 'Switch to grid view',
            icon: Icon(
              widget.gridView ? Icons.view_list : Icons.grid_view,
              color: colors.textSecondary,
            ),
            onPressed: () => widget.onViewChanged(!widget.gridView),
          );

          final filterRow = Row(
            children: [
              Expanded(child: categoryDropdown),
              const SizedBox(width: 12),
              Expanded(child: statusDropdown),
              const SizedBox(width: 12),
              Expanded(child: priorityDropdown),
              const SizedBox(width: 12),
              if (_tags.isNotEmpty) ...[
                Expanded(child: tagDropdown),
                const SizedBox(width: 12),
              ],
              Expanded(child: dateDropdown),
              if (hasActiveFilters) ...[const SizedBox(width: 8), clearButton],
              const SizedBox(width: 8),
              viewToggle,
            ],
          );

          // Narrow windows: filters wrap onto two lines.
          if (constraints.maxWidth < 700) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: (constraints.maxWidth - 20) / 2,
                  child: categoryDropdown,
                ),
                SizedBox(
                  width: (constraints.maxWidth - 20) / 2,
                  child: statusDropdown,
                ),
                SizedBox(
                  width: (constraints.maxWidth - 20) / 2,
                  child: priorityDropdown,
                ),
                if (_tags.isNotEmpty)
                  SizedBox(
                    width: (constraints.maxWidth - 20) / 2,
                    child: tagDropdown,
                  ),
                SizedBox(
                  width: (constraints.maxWidth - 20) / 2,
                  child: dateDropdown,
                ),
                if (hasActiveFilters) clearButton,
                viewToggle,
              ],
            );
          }

          return filterRow;
        },
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
