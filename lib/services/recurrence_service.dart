/// Expands simple recurrence rules into concrete dates.
///
/// Supported rule formats (RFC 5545 subset):
///   FREQ=DAILY
///   FREQ=WEEKLY;BYDAY=MO,WE,FR     (MO TU WE TH FR SA SU)
///   FREQ=MONTHLY
///
/// Instances are computed on read — no rows are stored per occurrence.
class RecurrenceService {
  RecurrenceService._();

  static const Map<String, int> _weekdayCodes = {
    'MO': 1,
    'TU': 2,
    'WE': 3,
    'TH': 4,
    'FR': 5,
    'SA': 6,
    'SU': 7,
  };

  static String _freq(String rule) {
    final match = RegExp(r'FREQ=(\w+)').firstMatch(rule);
    return match?.group(1)?.toUpperCase() ?? '';
  }

  static Set<int> _byDays(String rule) {
    final match = RegExp(r'BYDAY=([\w,]+)').firstMatch(rule);
    if (match == null) return {};
    return match
        .group(1)!
        .split(',')
        .map((d) => _weekdayCodes[d.trim().toUpperCase()])
        .whereType<int>()
        .toSet();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The next occurrence strictly after [after], or null when the rule is
  /// unsupported or the recurrence window ended.
  static DateTime? nextOccurrence(
    String rule,
    DateTime after, {
    DateTime? endDate,
  }) {
    final freq = _freq(rule);
    final byDays = _byDays(rule);
    if (freq.isEmpty) return null;

    final afterDay = _dateOnly(after);
    if (endDate != null && afterDay.isAfter(_dateOnly(endDate))) return null;

    var candidate = afterDay.add(const Duration(days: 1));
    for (var i = 0; i < 400; i++) {
      if (endDate != null && candidate.isAfter(_dateOnly(endDate))) {
        return null;
      }
      if (_matches(candidate, freq, byDays, afterDay.day)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
    return null;
  }

  /// All occurrence dates within [rangeStart]..[rangeEnd] (inclusive).
  ///
  /// [from] anchors the rule (the master task's scheduled date or the
  /// date it was last spawned from); occurrences before [rangeStart] or
  /// after [endDate] are excluded.
  static List<DateTime> instancesInRange(
    String rule,
    DateTime rangeStart,
    DateTime rangeEnd, {
    DateTime? from,
    DateTime? endDate,
  }) {
    final freq = _freq(rule);
    if (freq.isEmpty) return [];

    final byDays = _byDays(rule);
    final start = _dateOnly(rangeStart);
    final end = _dateOnly(rangeEnd);
    if (end.isBefore(start)) return [];

    // Monthly rules anchor to the day of month of the rule's origin.
    final dayOfMonth = from?.day ?? start.day;
    var candidate = from != null ? _dateOnly(from) : start;
    if (candidate.isBefore(start)) candidate = start;

    final result = <DateTime>[];
    for (var i = 0; i < 1000; i++) {
      if (candidate.isAfter(end)) break;
      if (endDate != null && candidate.isAfter(_dateOnly(endDate))) break;
      if (_matches(candidate, freq, byDays, dayOfMonth)) {
        result.add(candidate);
      }
      candidate = candidate.add(const Duration(days: 1));
    }
    return result;
  }

  static bool _matches(
      DateTime day, String freq, Set<int> byDays, int dayOfMonth) {
    switch (freq) {
      case 'DAILY':
        return true;
      case 'WEEKLY':
        return byDays.isEmpty || byDays.contains(day.weekday);
      case 'MONTHLY':
        // Clamp day-of-month to the month length (e.g. the 31st in Feb).
        final lastDay = DateTime(day.year, day.month + 1, 0).day;
        return day.day == (dayOfMonth > lastDay ? lastDay : dayOfMonth);
      default:
        return false;
    }
  }
}
