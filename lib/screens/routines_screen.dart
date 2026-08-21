import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../components/routines/routine_card.dart';
import '../components/routines/routine_dialog.dart';
import '../models/routine.dart';
import '../providers/routines_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Routines: today's checklist grouped by time of day (as 4:3 cards with
/// the routine description and a built-in streak counter), plus the full
/// weekly schedule grouped the same way.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  Future<void> _openDialog(Routine? routine) async {
    final result = await showDialog<RoutineDialogResult>(
      context: context,
      builder: (_) => RoutineDialog(routine: routine),
    );
    if (result == null || !mounted) return;
    final provider = context.read<RoutinesProvider>();
    if (result.delete) {
      await provider.delete(result.routine.id!);
      return;
    }
    if (routine == null) {
      await provider.create(result.routine);
    } else {
      await provider.update(result.routine);
    }
  }

  Future<void> _confirmDelete(Routine routine) async {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: const Text('Delete Routine'),
        content: Text('Delete "${routine.title}" permanently?'),
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
      await context.read<RoutinesProvider>().delete(routine.id!);
    }
  }

  /// Splits [routines] into the four time-of-day groups (Morning, Noon,
  /// Afternoon, Evening), sorted by scheduled time within each group.
  List<Widget> _buildGroups(
    List<Routine> routines, {
    required bool asCards,
    required void Function(Routine) onToggle,
  }) {
    final grouped = <String, List<Routine>>{};
    for (final r in routines) {
      grouped.putIfAbsent(r.timeCategory, () => []).add(r);
    }

    final widgets = <Widget>[];
    for (final group in Routine.timeGroups) {
      final list = grouped[group];
      if (list == null || list.isEmpty) continue;
      list.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

      widgets.add(_TimeGroupHeader(
          group: group, count: list.length));
      widgets.add(const SizedBox(height: 8));

      if (asCards) {
        widgets.add(GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // Bounded card size: 4:3 cards capped at 360px wide; extra
          // columns appear as the window widens instead of inflating cards.
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 4 / 3,
          ),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final routine = list[index];
            return _TodayCard(
              key: ValueKey('today-card-${routine.id}'),
              routine: routine,
              onToggle: () => onToggle(routine),
            );
          },
        ));
      } else {
        widgets.addAll([
          for (final routine in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RoutineCard(
                routine: routine,
                activeToday: routine.isActiveOn(DateTime.now()),
                onToggle: () => onToggle(routine),
                onEdit: () => _openDialog(routine),
                onDelete: () => _confirmDelete(routine),
              ),
            ),
        ]);
      }
      widgets.add(const SizedBox(height: 20));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isCollapsed = AppTheme.isScreenCollapsed(context);

    return Column(
      children: [
        _buildHeader(context, colors, isCollapsed),
        Expanded(
          child: Consumer<RoutinesProvider>(
            builder: (context, provider, _) {
              final now = DateTime.now();
              final activeToday =
                  provider.routines.where((r) => r.isActiveOn(now)).toList();
              final doneToday =
                  activeToday.where((r) => r.isCompletedToday).length;
              final bestStreak = provider.routines.fold<int>(
                  0, (m, r) => r.streak > m ? r.streak : m);

              if (provider.loading && provider.routines.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryCard(
                      dateLabel: DateFormat('EEEE, MMMM d').format(now),
                      doneToday: doneToday,
                      activeTodayCount: activeToday.length,
                      bestStreak: bestStreak,
                    ),
                    const SizedBox(height: 24),
                    Text("Today's Checklist",
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (activeToday.isEmpty)
                      _emptyBox(colors,
                          'Nothing scheduled today — add a routine or check its days.')
                    else
                      ..._buildGroups(
                        activeToday,
                        asCards: true,
                        onToggle: (r) => provider.toggleCompletion(r),
                      ),
                    const SizedBox(height: 4),
                    Text('All Routines',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (provider.routines.isEmpty)
                      _emptyBox(colors,
                          'No routines yet — create your first habit.')
                    else
                      ..._buildGroups(
                        provider.routines,
                        asCards: false,
                        onToggle: (r) => provider.toggleCompletion(r),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeColors colors,
      bool isCollapsed) {
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
            child: Consumer<RoutinesProvider>(
              builder: (context, provider, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Routines', style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '${provider.routines.length} routine${provider.routines.length == 1 ? '' : 's'}',
                    style: TextStyle(fontSize: 12, color: colors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => _openDialog(null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New Routine'),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(AppThemeColors colors, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Center(
        child: Text(
          message,
          style: TextStyle(fontSize: 13, color: colors.textTertiary),
        ),
      ),
    );
  }
}

/// Today's progress: X of Y done, a progress bar, and the best streak.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.dateLabel,
    required this.doneToday,
    required this.activeTodayCount,
    required this.bestStreak,
  });

  final String dateLabel;
  final int doneToday;
  final int activeTodayCount;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final progress =
        activeTodayCount == 0 ? 0.0 : doneToday / activeTodayCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateLabel,
                        style: TextStyle(
                            fontSize: 12, color: colors.textTertiary)),
                    const SizedBox(height: 4),
                    Text(
                      activeTodayCount == 0
                          ? 'Nothing scheduled today'
                          : '$doneToday of $activeTodayCount done today',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              if (bestStreak > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department,
                          size: 15, color: AppTheme.amber),
                      const SizedBox(width: 4),
                      Text(
                        'Best streak: $bestStreak',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.amber),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colors.surfaceVariant,
              color: AppTheme.emerald,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small section header for one time-of-day group (Morning / Noon / …).
class _TimeGroupHeader extends StatelessWidget {
  const _TimeGroupHeader({required this.group, required this.count});

  final String group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final (icon, color) = switch (group) {
      'Morning' => (Icons.wb_twilight, AppTheme.amber),
      'Noon' => (Icons.light_mode, AppTheme.orange),
      'Afternoon' => (Icons.wb_sunny, AppTheme.sky),
      'Evening' => (Icons.nights_stay, AppTheme.indigo),
      _ => (Icons.schedule, colors.textSecondary),
    };

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          group,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style:
                TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// 4:3 today card: title, description, time, tap-to-complete toggle, and a
/// built-in streak counter.
class _TodayCard extends StatelessWidget {
  const _TodayCard({
    super.key,
    required this.routine,
    required this.onToggle,
  });

  final Routine routine;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final routineColor = AppTheme.getRoutineColor(routine.color);
    final isCompleted = routine.isCompletedToday;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCompleted
                  ? routineColor.withValues(alpha: 0.6)
                  : colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 26,
                    decoration: BoxDecoration(
                      color: routineColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      routine.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color:
                        isCompleted ? routineColor : colors.textTertiary,
                  ),
                ],
              ),
              if (routine.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    routine.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: colors.textSecondary),
                  ),
                ),
              ] else
                const Spacer(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.schedule,
                      size: 12, color: colors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    RoutineCard.formatTime(routine),
                    style: TextStyle(
                        fontSize: 11, color: colors.textTertiary),
                  ),
                  const Spacer(),
                  // Built-in streak counter for this routine.
                  const Icon(Icons.local_fire_department,
                      size: 14, color: AppTheme.amber),
                  const SizedBox(width: 3),
                  Text(
                    '${routine.streak}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                  if (routine.streak == 1)
                    Text(
                      ' day',
                      style: TextStyle(
                          fontSize: 11, color: colors.textTertiary),
                    )
                  else if (routine.streak > 1)
                    Text(
                      ' days',
                      style: TextStyle(
                          fontSize: 11, color: colors.textTertiary),
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
