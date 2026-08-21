import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/project.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Project card: colored icon, title, description, task progress bar,
/// due date, and a Completed chip. Tap opens the kanban detail view.
class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.progress,
    required this.onOpen,
  });

  final Project project;
  final (int, int) progress; // (completed, total)
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final (done, total) = progress;
    final pct = total > 0 ? (done / total * 100) : 0.0;
    final color = project.displayColor;
    final isCompleted = project.status == 'Completed';
    final isInProgress = project.status == 'In Progress';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder_outlined,
                        size: 18, color: color),
                  ),
                  const Spacer(),
                  if (isCompleted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle,
                              size: 12, color: AppTheme.emerald),
                          SizedBox(width: 4),
                          Text(
                            'Done',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.emerald),
                          ),
                        ],
                      ),
                    )
                  else if (isInProgress)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outline,
                              size: 12, color: AppTheme.blue),
                          SizedBox(width: 4),
                          Text(
                            'In Progress',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.blue),
                          ),
                        ],
                      ),
                    )
                  else
                    Icon(Icons.chevron_right,
                        size: 18, color: colors.textTertiary),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                project.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 12, color: colors.textTertiary),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    total == 0
                        ? 'No tasks yet'
                        : '$done of $total tasks done',
                    style: TextStyle(
                        fontSize: 11, color: colors.textSecondary),
                  ),
                  const Spacer(),
                  Text(
                    total == 0 ? '' : '${pct.round()}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : pct / 100,
                  minHeight: 6,
                  backgroundColor: colors.surfaceVariant,
                  color: isCompleted
                      ? AppTheme.emerald
                      : (isInProgress ? AppTheme.blue : color),
                ),
              ),
              if (project.dueDate != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.event,
                        size: 13, color: colors.textTertiary),
                    const SizedBox(width: 4),
                    Text(
                      'Due ${DateFormat('MMM d, yyyy').format(project.dueDate!)}',
                      style: TextStyle(
                          fontSize: 11, color: colors.textTertiary),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
