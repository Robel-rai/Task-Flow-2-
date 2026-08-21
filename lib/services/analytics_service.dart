import '../repositories/focus_session_repository.dart';
import '../repositories/task_repository.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

String _dayKey(DateTime d) => d.toIso8601String().split('T').first;

/// All metrics shown on the Analytics screen, loaded in one batched pass.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.productivityScore,
    required this.currentStreak,
    required this.maxStreak,
    required this.completionRate,
    required this.completedThisWeek,
    required this.completedLastWeek,
    required this.focusMinutesPerDay,
    required this.categoryPerformance,
    required this.overdueCount,
    required this.dueThisWeekCount,
    required this.averageTasksPerDay,
    required this.dayOfWeekCompletion,
    required this.completionPerDay,
    this.mostTimeConsumingTaskTitle,
    this.mostTimeConsumingTaskSeconds = 0,
    required this.insight,
  });

  /// Composite 0–100: half completion rate, half focus consistency.
  final int productivityScore;

  /// Consecutive days (ending today or yesterday) with ≥1 completion.
  final int currentStreak;
  final int maxStreak;

  /// Completed / total tasks, 0–100.
  final double completionRate;

  final int completedThisWeek;
  final int completedLastWeek;

  /// Focus minutes per calendar day, keyed `yyyy-MM-dd` (last 30 days).
  final Map<String, int> focusMinutesPerDay;

  /// (category name, total tasks, completed tasks), largest first.
  final List<(String, int, int)> categoryPerformance;

  /// Tasks whose due date has passed and are not completed.
  final int overdueCount;

  /// Tasks due within the next 7 days (not completed).
  final int dueThisWeekCount;

  /// Average tasks completed per day over the last 7 days.
  final double averageTasksPerDay;

  /// Completed task count per day-of-week (0=Mon … 6=Sun).
  final Map<int, int> dayOfWeekCompletion;

  /// Completed task count per day for the last 30 days, keyed yyyy-MM-dd.
  final Map<String, int> completionPerDay;

  /// Title of the task with the most time spent, if any.
  final String? mostTimeConsumingTaskTitle;

  /// Time spent on the most time-consuming task, in seconds.
  final int mostTimeConsumingTaskSeconds;

  /// Dynamic motivational insight based on data patterns.
  final String insight;

  int get focusMinutesThisWeek {
    var total = 0;
    final today = _dateOnly(DateTime.now());
    for (var i = 6; i >= 0; i--) {
      total += focusMinutesPerDay[_dayKey(_addDays(today, -i))] ?? 0;
    }
    return total;
  }
}

/// Batched analytics queries — one SQL statement per metric, run in
/// parallel, with pure Dart helpers for the derived math (streaks, score).
class AnalyticsService {
  AnalyticsService({TaskRepository? tasks, FocusSessionRepository? sessions})
      : _tasks = tasks ?? TaskRepository(),
        _sessions = sessions ?? FocusSessionRepository();

  final TaskRepository _tasks;
  final FocusSessionRepository _sessions;

  /// Loads every analytics metric in one parallel pass (no N+1).
  Future<AnalyticsSummary> loadSummary({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final weekStart = _addDays(today, -6);
    final lastWeekStart = _addDays(today, -13);
    final lastWeekEnd = _addDays(today, -7);

    // Batch 1: queries that fit in a 9-tuple (Dart limit).
    final (
      completedDays,
      weekCounts,
      lastWeekCounts,
      categories,
      total,
      completed,
      focusSeconds,
    ) = await (
      _tasks.completedDates(),
      _tasks.completionCountsForRange(weekStart, today),
      _tasks.completionCountsForRange(lastWeekStart, lastWeekEnd),
      _tasks.categoryPerformance(),
      _tasks.countAll(),
      _tasks.countByStatus('Completed'),
      _sessions.focusSecondsPerDay(_addDays(today, -29), today),
    ).wait;

    // Batch 2: remaining queries.
    final (overdue, dueThisWeek, mostTimeTask) = await (
      _tasks.countOverdue(now: today),
      _tasks.countDueThisWeek(now: today),
      _tasks.mostTimeConsumingTask(),
    ).wait;

    final completionRate = total > 0 ? (completed / total) * 100 : 0.0;

    // Focus consistency: share of the last 7 days with ≥1 focus session.
    var focusedDays = 0;
    for (var i = 0; i < 7; i++) {
      if ((focusSeconds[_dayKey(_addDays(today, -i))] ?? 0) > 0) focusedDays++;
    }
    final focusConsistency = (focusedDays / 7) * 100;
    final productivity =
        (completionRate * 0.5 + focusConsistency * 0.5).round().clamp(0, 100);

    // Average tasks per day (last 7 days).
    final completedThisWeek = weekCounts.values.fold(0, (a, b) => a + b);
    final avgTasksPerDay = completedThisWeek / 7.0;

    // Day-of-week completion distribution (last 90 days for significance).
    final dayOfWeek = <int, int>{};
    final cutoff = _addDays(today, -89);
    final allDates = completedDays; // reuse from batch 1
    for (final d in allDates) {
      if (d.isBefore(cutoff)) continue;
      final dow = d.weekday - 1; // 0=Mon … 6=Sun
      dayOfWeek[dow] = (dayOfWeek[dow] ?? 0) + 1;
    }

    // 30-day completion trend.
    final thirtyDaysAgo = _addDays(today, -29);
    final completionPerDay = <String, int>{};
    for (final d in allDates) {
      if (d.isBefore(thirtyDaysAgo)) continue;
      final key = _dayKey(d);
      completionPerDay[key] = (completionPerDay[key] ?? 0) + 1;
    }

    // Motivational insight.
    final focusThisWeek =
        (await _sessions.totalSecondsForRange(weekStart, today)) ~/ 60;
    final focusLastWeek =
        (await _sessions.totalSecondsForRange(lastWeekStart, lastWeekEnd)) ~/
            60;
    final insight = _computeInsight(
      avgTasksPerDay: avgTasksPerDay,
      overdue: overdue,
      currentStreak:
          currentStreak(completedDays.map(_dateOnly).toSet(), today: today),
      focusMinutesThisWeek: focusThisWeek,
      focusMinutesLastWeek: focusLastWeek,
      dayOfWeek: dayOfWeek,
    );

    return AnalyticsSummary(
      productivityScore: productivity,
      currentStreak:
          currentStreak(completedDays.map(_dateOnly).toSet(), today: today),
      maxStreak: maxStreak(completedDays.map(_dateOnly).toSet()),
      completionRate: completionRate,
      completedThisWeek: completedThisWeek,
      completedLastWeek: lastWeekCounts.values.fold(0, (a, b) => a + b),
      focusMinutesPerDay: {
        for (final e in focusSeconds.entries)
          e.key: (e.value / 60).round(),
      },
      categoryPerformance: categories,
      overdueCount: overdue,
      dueThisWeekCount: dueThisWeek,
      averageTasksPerDay: avgTasksPerDay,
      dayOfWeekCompletion: dayOfWeek,
      completionPerDay: completionPerDay,
      mostTimeConsumingTaskTitle: mostTimeTask?.title,
      mostTimeConsumingTaskSeconds: mostTimeTask?.timeSpentSeconds ?? 0,
      insight: insight,
    );
  }

  /// Generates a dynamic motivational insight string.
  static String _computeInsight({
    required double avgTasksPerDay,
    required int overdue,
    required int currentStreak,
    required int focusMinutesThisWeek,
    required int focusMinutesLastWeek,
    required Map<int, int> dayOfWeek,
  }) {
    // Most productive day of the week.
    if (dayOfWeek.isNotEmpty) {
      final bestDow =
          dayOfWeek.entries.reduce((a, b) => a.value > b.value ? a : b);
      final dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      if (bestDow.value >= 3) {
        return "You're most productive on ${dayNames[bestDow.key]}s — schedule big tasks then!";
      }
    }

    // Focus time trend.
    if (focusMinutesLastWeek > 0) {
      final change = ((focusMinutesThisWeek - focusMinutesLastWeek) /
              focusMinutesLastWeek *
              100)
          .round();
      if (change > 15) {
        return "Your focus time is up $change% this week — great momentum! 🔥";
      }
      if (change < -15) {
        return "Focus time dipped $change% this week — try a short session to get back on track.";
      }
    }

    // Overdue warning.
    if (overdue > 0) {
      return "You have $overdue overdue task${overdue == 1 ? '' : 's'} — clear them to boost your streak!";
    }

    // Streak encouragement.
    if (currentStreak >= 7) {
      return "Amazing $currentStreak-day streak! You're building a powerful habit. 💪";
    }
    if (currentStreak >= 3) {
      return "$currentStreak-day streak — keep going, consistency is key!";
    }

    // Default.
    if (avgTasksPerDay >= 3) {
      return "You're averaging ${avgTasksPerDay.toStringAsFixed(1)} tasks/day — solid productivity!";
    }

    return "Complete tasks consistently to unlock personalized insights.";
  }

  /// Consecutive days with ≥1 completion, counting back from [today]; if
  /// today has none yet the streak is measured from yesterday (so an
  /// early-morning streak isn't "broken").
  static int currentStreak(Set<DateTime> completedDays, {DateTime? today}) {
    final days = completedDays.map(_dateOnly).toSet();
    var cursor = _dateOnly(today ?? DateTime.now());
    if (!days.contains(cursor)) cursor = _addDays(cursor, -1);
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = _addDays(cursor, -1);
    }
    return streak;
  }

  /// Longest run of consecutive days with ≥1 completion in all history.
  static int maxStreak(Set<DateTime> completedDays) {
    final days = completedDays.map(_dateOnly).toSet().toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? prev;
    for (final day in days) {
      run = (prev != null && day.difference(prev).inDays == 1) ? run + 1 : 1;
      if (run > best) best = run;
      prev = day;
    }
    return best;
  }
}
