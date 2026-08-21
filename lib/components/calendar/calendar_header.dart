import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../providers/calendar_provider.dart';
import '../../theme/app_colors.dart';

/// Calendar toolbar: previous/next navigation, a label that reflects the
/// active view, a Today button, and the Month/Week/Day/Agenda toggle.
class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    super.key,
    required this.provider,
    this.onMenu,
  });

  final CalendarProvider provider;
  final VoidCallback? onMenu;

  String get _label {
    switch (provider.viewMode) {
      case CalendarViewMode.month:
      case CalendarViewMode.agenda:
        return DateFormat('MMMM yyyy').format(provider.viewingMonth);
      case CalendarViewMode.week:
        final start = provider.weekStart;
        final end = start.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(start)} – '
            '${DateFormat('MMM d, yyyy').format(end)}';
      case CalendarViewMode.day:
        return DateFormat('EEEE, MMM d, yyyy').format(provider.selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          if (onMenu != null) ...[
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: onMenu,
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            tooltip: 'Previous',
            icon: Icon(Icons.chevron_left, color: colors.textSecondary),
            onPressed: () => provider.navigate(-1),
          ),
          IconButton(
            tooltip: 'Next',
            icon: Icon(Icons.chevron_right, color: colors.textSecondary),
            onPressed: () => provider.navigate(1),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: provider.goToToday,
            child: const Text('Today'),
          ),
          const SizedBox(width: 8),
          SegmentedButton<CalendarViewMode>(
            segments: const [
              ButtonSegment(
                value: CalendarViewMode.month,
                label: Text('Month'),
                icon: Icon(Icons.calendar_view_month, size: 16),
              ),
              ButtonSegment(
                value: CalendarViewMode.week,
                label: Text('Week'),
                icon: Icon(Icons.calendar_view_week, size: 16),
              ),
              ButtonSegment(
                value: CalendarViewMode.day,
                label: Text('Day'),
                icon: Icon(Icons.view_day_outlined, size: 16),
              ),
              ButtonSegment(
                value: CalendarViewMode.agenda,
                label: Text('Agenda'),
                icon: Icon(Icons.view_agenda_outlined, size: 16),
              ),
            ],
            selected: {provider.viewMode},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ),
            onSelectionChanged: (selection) =>
                provider.setViewMode(selection.first),
          ),
        ],
      ),
    );
  }
}
