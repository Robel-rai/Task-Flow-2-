import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../components/analytics/category_bars.dart';
import '../components/analytics/completion_trend_chart.dart';
import '../components/analytics/day_heatmap.dart';
import '../components/analytics/empty_analytics.dart';
import '../components/analytics/focus_time_chart.dart';
import '../components/analytics/motivational_insight.dart';
import '../components/analytics/recent_activity.dart';
import '../components/analytics/stat_card.dart';
import '../components/analytics/task_count_card.dart';
import '../components/analytics/time_summary_card.dart';
import '../components/analytics/weekly_report_preview.dart';
import '../core/app_navigator.dart';
import '../providers/analytics_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Analytics dashboard: productivity score, streaks, completion rate,
/// focus-time chart, category bars, completion trend, day heatmap,
/// weekly report preview, and recent activity feed.
class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;
    final isCollapsed = AppTheme.isScreenCollapsed(context);
    final analytics = context.watch<AnalyticsProvider>();

    return Column(
      children: [
        _buildHeader(context, colors, isCollapsed, analytics),
        Expanded(
          child: analytics.summary == null
              ? const Center(child: CircularProgressIndicator())
              : analytics.totalTasks == 0
                  ? EmptyAnalytics(
                      onCreateTask: () => AppNavigator.instance.goTo(1),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: _buildContent(context, analytics),
                    ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, AnalyticsProvider analytics) {
    final summary = analytics.summary!;
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    // ─── Motivational insight ───
    final insightBanner = MotivationalInsight(insight: summary.insight);

    // ─── KPI cards (animated, responsive row/wrap) ───
    final kpiCards = StatCardRow(
      cards: [
        StatCard(
          label: 'Productivity Score',
          targetValue: summary.productivityScore.toDouble(),
          icon: Icons.bolt,
          color: colors.primary,
          formatter: (v) => '${v.round()}/100',
        ),
        StatCard(
          label: 'Current Streak',
          targetValue: summary.currentStreak.toDouble(),
          icon: Icons.local_fire_department,
          color: AppTheme.emerald,
          formatter: (v) {
            final n = v.round();
            return '$n day${n == 1 ? '' : 's'}';
          },
        ),
        StatCard(
          label: 'Best Streak',
          targetValue: summary.maxStreak.toDouble(),
          icon: Icons.trending_up,
          color: AppTheme.amber,
          formatter: (v) {
            final n = v.round();
            return '$n day${n == 1 ? '' : 's'}';
          },
        ),
        StatCard(
          label: 'Completion Rate',
          targetValue: summary.completionRate,
          icon: Icons.check_circle_outline,
          color: AppTheme.blue,
          formatter: (v) => '${v.round()}%',
        ),
        StatCard(
          label: 'Avg / Day (7d)',
          targetValue: summary.averageTasksPerDay,
          icon: Icons.speed,
          color: AppTheme.sky,
          formatter: (v) => v.toStringAsFixed(1),
        ),
        StatCard(
          label: 'Overdue',
          targetValue: summary.overdueCount.toDouble(),
          icon: Icons.warning_amber_rounded,
          color: summary.overdueCount > 0 ? AppTheme.rose : AppTheme.emerald,
        ),
        StatCard(
          label: 'Due This Week',
          targetValue: summary.dueThisWeekCount.toDouble(),
          icon: Icons.event_available_outlined,
          color:
              summary.dueThisWeekCount > 0 ? AppTheme.amber : AppTheme.emerald,
        ),
        StatCard(
          label: 'Hours Logged',
          targetValue: analytics.hoursLogged,
          icon: Icons.hourglass_bottom,
          color: AppTheme.indigo,
          formatter: (v) => '${v.toStringAsFixed(1)}h',
        ),
      ],
    );

    // ─── Summary / time row ───
    final summaryRow = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final taskCount = TaskCountCard(
          total: analytics.totalTasks,
          completed: analytics.completedTasks,
          pending: analytics.pendingTasks,
        );
        final timeSummary = TimeSummaryCard(
          totalHours: analytics.hoursLogged,
          completedTasks: analytics.completedTasks,
          mostTimeTaskTitle: summary.mostTimeConsumingTaskTitle,
          mostTimeTaskSeconds: summary.mostTimeConsumingTaskSeconds,
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: taskCount),
              const SizedBox(width: 12),
              Expanded(child: timeSummary),
            ],
          );
        }
        return Column(
          children: [
            taskCount,
            const SizedBox(height: 12),
            timeSummary,
          ],
        );
      },
    );

    // ─── Trend + heatmap row ───
    final trendRow = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: CompletionTrendChart(
                    completionPerDay: summary.completionPerDay),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DayHeatmap(
                    dayOfWeekCompletion: summary.dayOfWeekCompletion),
              ),
            ],
          );
        }
        return Column(
          children: [
            CompletionTrendChart(completionPerDay: summary.completionPerDay),
            const SizedBox(height: 12),
            DayHeatmap(dayOfWeekCompletion: summary.dayOfWeekCompletion),
          ],
        );
      },
    );

    // ─── Focus + category row ───
    final chartsRow = LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child:
                    FocusTimeChart(minutesPerDay: summary.focusMinutesPerDay),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: CategoryBars(
                    performance: summary.categoryPerformance),
              ),
            ],
          );
        }
        return Column(
          children: [
            FocusTimeChart(minutesPerDay: summary.focusMinutesPerDay),
            const SizedBox(height: 12),
            CategoryBars(performance: summary.categoryPerformance),
          ],
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        insightBanner,
        const SizedBox(height: 12),
        kpiCards,
        const SizedBox(height: 12),
        summaryRow,
        const SizedBox(height: 12),
        trendRow,
        const SizedBox(height: 12),
        chartsRow,
        const SizedBox(height: 12),
        WeeklyReportPreview(summary: summary),
        const SizedBox(height: 12),
        RecentActivity(tasks: analytics.recentTasks),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppThemeColors colors,
      bool isCollapsed, AnalyticsProvider analytics) {
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
                Text('Analytics',
                    style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${analytics.totalTasks} tasks · '
                  '${analytics.hoursLogged.toStringAsFixed(1)}h logged',
                  style:
                      TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
