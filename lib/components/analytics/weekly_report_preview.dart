import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// Compact weekly report preview: this week vs last week, focus minutes,
/// best focus day, and the productivity score.
class WeeklyReportPreview extends StatelessWidget {
  const WeeklyReportPreview({super.key, required this.summary});

  final AnalyticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    final delta = summary.completedThisWeek - summary.completedLastWeek;
    final bestDay = _bestDay(summary);

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
                child: Text('This Week',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              _scoreBadge(colors, summary.productivityScore),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Weekly report · ${DateFormat('MMM d').format(DateTime.now().subtract(const Duration(days: 6)))} – ${DateFormat('MMM d').format(DateTime.now())}',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _metric(colors, Icons.check_circle_outline,
                  '${summary.completedThisWeek} tasks completed',
                  delta == 0
                      ? 'Same as last week'
                      : (delta > 0
                          ? '+$delta vs last week'
                          : '$delta vs last week')),
              _metric(colors, Icons.timer_outlined,
                  '${summary.focusMinutesThisWeek} min focused',
                  'Across ${summary.focusMinutesThisWeek ~/ 60}h ${summary.focusMinutesThisWeek % 60}m'),
              if (bestDay != null)
                _metric(colors, Icons.local_fire_department,
                    'Best day: ${DateFormat('EEEE').format(bestDay.$1)}',
                    '${bestDay.$2} min focused'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(AppThemeColors colors, int score) {
    final color = score >= 70
        ? AppTheme.emerald
        : (score >= 40 ? AppTheme.amber : AppTheme.rose);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'productivity',
            style: TextStyle(fontSize: 10, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _metric(AppThemeColors colors, IconData icon, String value,
      String hint) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            Text(
              hint,
              style: TextStyle(fontSize: 10, color: colors.textTertiary),
            ),
          ],
        ),
      ],
    );
  }

  /// (date, minutes) of the day with the most focus in the last 7 days.
  (DateTime, int)? _bestDay(AnalyticsSummary summary) {
    final today = DateTime.now();
    (DateTime, int)? best;
    for (var i = 0; i < 7; i++) {
      final date = DateTime(today.year, today.month, today.day - i);
      final key = date.toIso8601String().split('T').first;
      final minutes = summary.focusMinutesPerDay[key] ?? 0;
      if (minutes > 0 && (best == null || minutes > best.$2)) {
        best = (date, minutes);
      }
    }
    return best;
  }
}
