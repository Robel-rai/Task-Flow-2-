import 'package:flutter/material.dart';

import '../../models/project.dart';
import '../../models/task.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// The body of a search dropdown: a searching indicator, result sections
/// (Tasks then Projects) with a keyboard highlight, a "Recent searches"
/// section when the field is focused but empty, and quick-create actions
/// when nothing matches. Shared by the dashboard dropdown and the global
/// sidebar search panel so both look and behave identically.
class SearchResultsContent extends StatefulWidget {
  const SearchResultsContent({
    super.key,
    required this.searching,
    required this.query,
    required this.taskResults,
    required this.projectResults,
    required this.selectedIndex,
    required this.onSelect,
    required this.onCreateTask,
    required this.onCreateProject,
    this.showRecents = false,
    this.recentQueries = const [],
    this.onRecentTap,
  });

  final bool searching;
  final String query;
  final List<Task> taskResults;
  final List<Project> projectResults;

  /// Index into the flattened task-then-project list, or -1.
  final int selectedIndex;

  /// Called with the flattened index of the tapped result.
  final void Function(int index) onSelect;
  final VoidCallback onCreateTask;
  final VoidCallback onCreateProject;

  /// When true and [query] is empty, the recent searches section shows.
  final bool showRecents;
  final List<String> recentQueries;
  final ValueChanged<String>? onRecentTap;

  @override
  State<SearchResultsContent> createState() => _SearchResultsContentState();
}

class _SearchResultsContentState extends State<SearchResultsContent> {
  final ScrollController _scroll = ScrollController();
  final Map<int, GlobalKey> _optionKeys = {};
  int _lastSelected = -1;

  GlobalKey _optionKey(int index) =>
      _optionKeys.putIfAbsent(index, () => GlobalKey());

  @override
  void didUpdateWidget(SearchResultsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _lastSelected && widget.selectedIndex >= 0) {
      _lastSelected = widget.selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _optionKey(widget.selectedIndex).currentContext;
        if (ctx != null && _scroll.hasClients) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 150),
            alignment: 0.5,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final Widget content;
    if (widget.searching) {
      content = Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Searching…',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ),
      );
    } else if (widget.query.isEmpty && widget.showRecents) {
      content = _buildRecents(context);
    } else if (widget.taskResults.isEmpty && widget.projectResults.isEmpty) {
      content = _buildCreateActions(context);
    } else {
      content = _buildResults(context);
    }

    return Material(
      elevation: 8,
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: content,
      ),
    );
  }

  // ─── Sections ───

  Widget _buildResults(BuildContext context) {
    final taskCount = widget.taskResults.length;

    return SingleChildScrollView(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.taskResults.isNotEmpty) ...[
            _sectionHeader(context, 'Tasks'),
            for (var i = 0; i < widget.taskResults.length; i++)
              _taskTile(context, widget.taskResults[i], i),
          ],
          if (widget.projectResults.isNotEmpty) ...[
            _sectionHeader(context, 'Projects'),
            for (var i = 0; i < widget.projectResults.length; i++)
              _projectTile(context, widget.projectResults[i], taskCount + i),
          ],
        ],
      ),
    );
  }

  Widget _buildRecents(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    if (widget.recentQueries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Start typing to search tasks and projects',
          style: TextStyle(fontSize: 13, color: colors.textTertiary),
        ),
      );
    }
    return SingleChildScrollView(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _sectionHeader(context, 'Recent searches'),
          for (final query in widget.recentQueries)
            ListTile(
              dense: true,
              leading: Icon(Icons.history, size: 18, color: colors.textTertiary),
              title: Text(query,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Icon(Icons.north_west,
                  size: 16, color: colors.textTertiary),
              onTap: () => widget.onRecentTap?.call(query),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateActions(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return SingleChildScrollView(
      controller: _scroll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No matches for "${widget.query}"',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ),
            ),
            ListTile(
              dense: true,
              leading: Icon(Icons.add_task, color: AppTheme.primary),
              title: Text('Create task "${widget.query}"'),
              onTap: widget.onCreateTask,
            ),
            ListTile(
              dense: true,
              leading:
                  Icon(Icons.create_new_folder_outlined, color: AppTheme.blue),
              title: Text('Create project "${widget.query}"'),
              onTap: widget.onCreateProject,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: colors.textTertiary,
        ),
      ),
    );
  }

  Widget _taskTile(BuildContext context, Task task, int index) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final selected = index == widget.selectedIndex;
    return ListTile(
      key: _optionKey(index),
      dense: true,
      selected: selected,
      selectedTileColor: colors.surfaceVariant,
      leading: Icon(
        Icons.check_circle_outline,
        color: AppTheme.getPriorityColor(task.priority),
      ),
      title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${task.status} · ${task.priority}',
        style: TextStyle(fontSize: 11, color: colors.textTertiary),
      ),
      trailing: Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
      onTap: () => widget.onSelect(index),
    );
  }

  Widget _projectTile(BuildContext context, Project project, int index) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final selected = index == widget.selectedIndex;
    return ListTile(
      key: _optionKey(index),
      dense: true,
      selected: selected,
      selectedTileColor: colors.surfaceVariant,
      leading: Icon(Icons.folder_outlined, color: project.displayColor),
      title: Text(project.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        project.description.isEmpty ? project.status : project.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, color: colors.textTertiary),
      ),
      trailing: Icon(Icons.chevron_right, size: 18, color: colors.textTertiary),
      onTap: () => widget.onSelect(index),
    );
  }
}
