import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../components/projects/kanban_board.dart';
import '../core/app_navigator.dart';
import '../components/projects/project_card.dart';
import '../components/projects/project_dialog.dart';
import '../components/projects/status_columns_dialog.dart';
import '../models/project.dart';
import '../models/project_status.dart';
import '../providers/projects_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Projects: colored cards with progress, and a kanban board detail view
/// for the selected project.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  @override
  void initState() {
    super.initState();
    AppNavigator.instance.addListener(_handleNavigationIntent);
  }

  @override
  void dispose() {
    AppNavigator.instance.removeListener(_handleNavigationIntent);
    super.dispose();
  }

  /// Opens the project requested by a dashboard search result: once the
  /// shell has switched to this screen, select it so the kanban detail
  /// view shows.
  void _handleNavigationIntent() {
    final projectId = AppNavigator.instance.projectToOpen;
    if (projectId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AppNavigator.instance.index != 3) {
        _handleNavigationIntent(); // shell hasn't switched yet; retry
        return;
      }
      context.read<ProjectsProvider>().select(projectId);
      AppNavigator.instance.consumeProjectToOpen();
    });
  }

  Future<void> _openDialog(Project? project) async {
    final result = await showDialog<ProjectDialogResult>(
      context: context,
      builder: (_) => ProjectDialog(project: project),
    );
    if (result == null || !mounted) return;
    final provider = context.read<ProjectsProvider>();
    if (result.delete) {
      await provider.delete(result.project.id!);
      return;
    }
    if (project == null) {
      await provider.create(result.project);
    } else {
      await provider.update(result.project);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isCollapsed = AppTheme.isScreenCollapsed(context);
    final provider = context.watch<ProjectsProvider>();
    final active = provider.activeProject;

    return Column(
      children: [
        active == null
            ? _buildListHeader(context, colors, isCollapsed, provider)
            : _buildDetailHeader(
                context, colors, isCollapsed, provider, active),
        Expanded(
          child: active == null
              ? _buildProjectList(context, provider)
              : _buildDetail(context, provider, active),
        ),
      ],
    );
  }

  // ─── List view ───

  Widget _buildListHeader(BuildContext context, AppThemeColors colors,
      bool isCollapsed, ProjectsProvider provider) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (isCollapsed) ...[
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Projects',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${provider.projectList.length} project${provider.projectList.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _openDialog(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Project'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList(BuildContext context, ProjectsProvider provider) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    if (provider.projectList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined,
                size: 64, color: colors.textTertiary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textTertiary),
            ),
            const SizedBox(height: 8),
            Text(
              'Group tasks into projects and track them on a kanban board',
              style: TextStyle(fontSize: 13, color: colors.textTertiary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        // Fixed tile height so card content never overflows when the
        // window shrinks; capped width keeps cards constant in full screen.
        mainAxisExtent: 210,
      ),
      itemCount: provider.projectList.length,
      itemBuilder: (context, index) {
        final project = provider.projectList[index];
        return ProjectCard(
          project: project,
          progress: provider.progressOf(project.id) ?? (0, 0),
          onOpen: () => provider.select(project.id),
        );
      },
    );
  }

  // ─── Detail (kanban) view ───

  Widget _buildDetailHeader(BuildContext context, AppThemeColors colors,
      bool isCollapsed, ProjectsProvider provider, Project project) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to projects',
            icon: Icon(Icons.arrow_back, color: colors.textSecondary),
            onPressed: () => provider.select(null),
          ),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: project.displayColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        project.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusChip(project.status),
                  ],
                ),
                if (project.dueDate != null)
                  Text(
                    'Due ${DateFormat('MMM d, yyyy').format(project.dueDate!)}',
                    style:
                        TextStyle(fontSize: 12, color: colors.textTertiary),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit columns',
            icon: Icon(Icons.tune, color: colors.textSecondary),
            onPressed: () => _openStatusColumns(context, provider, project),
          ),
          IconButton(
            tooltip: 'Edit project',
            icon: Icon(Icons.edit_outlined, color: colors.textSecondary),
            onPressed: () => _openDialog(project),
          ),
          IconButton(
            tooltip: 'Delete project',
            icon: Icon(Icons.delete_outline, color: AppTheme.rose),
            onPressed: () => _openDialog(project),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(BuildContext context, ProjectsProvider provider,
      Project project) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final (done, total) = provider.progressOf(project.id) ?? (0, 0);
    final pct = total > 0 ? (done / total * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        total == 0
                            ? 'No tasks yet'
                            : '$done of $total tasks done',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Drag tasks between columns to update status',
                        style: TextStyle(
                            fontSize: 12, color: colors.textTertiary),
                      ),
                    ],
                  ),
                ),
                if (total > 0)
                  Text(
                    '$pct%',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.getStatusColor(project.status),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: KanbanBoard(
              tasks: provider.kanbanTasks,
              columns: _resolveColumns(provider),
              onMoveTask: (task, status) =>
                  provider.moveTaskStatus(task.id!, status),
            ),
          ),
        ],
      ),
    );
  }

  /// The active project's kanban columns: its custom statuses when it has
  /// any, otherwise the built-in defaults.
  List<({String name, String colorKey})> _resolveColumns(
      ProjectsProvider provider) {
    final custom = provider.activeStatuses;
    if (custom.isEmpty) return KanbanBoard.defaultColumns;
    return [
      for (final s in custom)
        (name: s.name, colorKey: s.color),
    ];
  }

  /// Opens the per-project column manager; saves the edited list via the
  /// provider (which reconciles tasks of removed statuses).
  Future<void> _openStatusColumns(BuildContext context,
      ProjectsProvider provider, Project project) async {
    final current = provider.activeStatuses;
    final initial = current.isEmpty
        ? [
            for (final c in KanbanBoard.defaultColumns)
              ProjectStatus(name: c.name, color: c.colorKey),
          ]
        : current.map((s) => s.copyWith()).toList();

    final result = await showDialog<List<ProjectStatus>>(
      context: context,
      builder: (_) => StatusColumnsDialog(initial: initial),
    );
    if (result == null || !context.mounted) return;

    final reassigned = await provider.saveStatuses(result);
    if (context.mounted && reassigned != null && reassigned > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '$reassigned task${reassigned == 1 ? '' : 's'} moved to the '
              'first column'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Small live status pill (Pending / In Progress / Completed) shown in
  /// the kanban detail header.
  Widget _statusChip(String status) {
    final color = AppTheme.getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
