import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Shows a month-calendar dialog where the user picks a start and end day
/// (inclusive range). Returns the chosen `(start, end)` or null on cancel.
Future<(DateTime, DateTime)?> showDateRangePickerDialog(
  BuildContext context, {
  DateTime? initialStart,
  DateTime? initialEnd,
}) {
  return showDialog<(DateTime, DateTime)>(
    context: context,
    builder: (context) => _DateRangePickerDialog(
      initialStart: initialStart,
      initialEnd: initialEnd,
    ),
  );
}

/// A single-month calendar with a tappable inclusive range selection:
/// first tap sets the start, second tap the end (earlier taps restart),
/// and later taps begin a new range. Mirrors the app's design: a pill
/// spans the selected days with filled circles at both endpoints.
class _DateRangePickerDialog extends StatefulWidget {
  const _DateRangePickerDialog({this.initialStart, this.initialEnd});

  final DateTime? initialStart;
  final DateTime? initialEnd;

  @override
  State<_DateRangePickerDialog> createState() => _DateRangePickerDialogState();
}

class _DateRangePickerDialogState extends State<_DateRangePickerDialog> {
  /// First day of the month currently displayed.
  late DateTime _visibleMonth;

  DateTime? _start;
  DateTime? _end;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// End of the selected range; falls back to the start while only one
  /// day has been picked (single-day ranges are valid).
  DateTime? get _effectiveEnd => _end ?? _start;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart != null ? _dateOnly(widget.initialStart!) : null;
    _end = widget.initialEnd != null ? _dateOnly(widget.initialEnd!) : null;
    final anchor = _start ?? widget.initialEnd ?? DateTime.now();
    _visibleMonth = DateTime(anchor.year, anchor.month, 1);
  }

  void _tapDay(DateTime day) {
    setState(() {
      final s = _start;
      final e = _end;
      if (s == null) {
        _start = day;
        _end = null;
      } else if (e == null) {
        if (day.isBefore(s)) {
          _start = day; // picked before the start → restart the range
        } else {
          _end = day;
        }
      } else {
        _start = day; // range complete → begin a new one
        _end = null;
      }
    });
  }

  void _apply() {
    final start = _start;
    if (start == null) return;
    Navigator.of(context).pop((start, _end ?? start));
  }

  String _rangeLabel() {
    final s = _start;
    if (s == null) return 'Select a start date';
    final e = _end ?? s;
    if (_sameDay(s, e)) return DateFormat('MMM d, yyyy').format(s);
    return '${DateFormat('MMM d, yyyy').format(s)} — '
        '${DateFormat('MMM d, yyyy').format(e)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppThemeColors>()!;

    return Dialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(colors),
              const SizedBox(height: 4),
              _buildWeekdayHeader(colors),
              const SizedBox(height: 4),
              _buildGrid(colors),
              const SizedBox(height: 16),
              _buildRangeBox(colors),
              const SizedBox(height: 16),
              _buildActions(colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppThemeColors colors) {
    return Row(
      children: [
        Text(
          DateFormat('MMMM yyyy').format(_visibleMonth),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          color: colors.textSecondary,
          visualDensity: VisualDensity.compact,
          tooltip: 'Previous month',
          onPressed: () => setState(() => _visibleMonth =
              DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          color: colors.textSecondary,
          visualDensity: VisualDensity.compact,
          tooltip: 'Next month',
          onPressed: () => setState(() => _visibleMonth =
              DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1)),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader(AppThemeColors colors) {
    return Row(
      children: [
        for (final w in const ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'])
          Expanded(
            child: Center(
              child: Text(
                w,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textTertiary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(AppThemeColors colors) {
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Monday-first: weekday 1 (Mon) → 0 blanks.
    final leadingBlanks = _visibleMonth.weekday - DateTime.monday;
    final start = _start;
    final effectiveEnd = _effectiveEnd;

    final rows = <Widget>[];
    for (var row = 0; row < 6; row++) {
      final days = <DateTime?>[];
      for (var col = 0; col < 7; col++) {
        final dayNumber = row * 7 + col - leadingBlanks + 1;
        days.add((dayNumber >= 1 && dayNumber <= daysInMonth)
            ? DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber)
            : null);
      }
      final inRange = days
          .map((d) =>
              d != null &&
              start != null &&
              effectiveEnd != null &&
              !d.isBefore(start) &&
              !d.isAfter(effectiveEnd))
          .toList();
      final firstInRange = inRange.indexOf(true);
      final lastInRange = inRange.lastIndexOf(true);

      rows.add(Row(
        children: [
          for (var col = 0; col < 7; col++)
            Expanded(
              child: _buildDayCell(
                colors,
                days[col],
                inRange: inRange[col],
                firstInRange: col == firstInRange,
                lastInRange: col == lastInRange,
              ),
            ),
        ],
      ));
    }
    return Column(children: rows);
  }

  Widget _buildDayCell(
    AppThemeColors colors,
    DateTime? date, {
    required bool inRange,
    required bool firstInRange,
    required bool lastInRange,
  }) {
    final effectiveEnd = _effectiveEnd;
    final isStart = date != null && _start != null && _sameDay(date, _start!);
    final isEnd =
        date != null && effectiveEnd != null && _sameDay(date, effectiveEnd);
    final isToday = date != null && _sameDay(date, DateTime.now());

    final Widget content;
    if (date == null) {
      content = const SizedBox.shrink();
    } else if (isStart || isEnd) {
      // Endpoint: solid filled circle.
      content = Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration:
            const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
        child: Text(
          '${date.day}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    } else if (inRange) {
      // Inside the range: the pill (rounded only at the range's ends).
      content = Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.16),
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(firstInRange ? 16 : 0),
            right: Radius.circular(lastInRange ? 16 : 0),
          ),
        ),
        child: Text(
          '${date.day}',
          style: TextStyle(fontSize: 13, color: colors.textPrimary),
        ),
      );
    } else {
      content = Text(
        '${date.day}',
        style: TextStyle(
          fontSize: 13,
          color: isToday ? AppTheme.primary : colors.textPrimary,
          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
        ),
      );
    }

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: date == null ? null : () => _tapDay(date),
        child: SizedBox(width: 40, height: 40, child: Center(child: content)),
      ),
    );
  }

  Widget _buildRangeBox(AppThemeColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 15, color: AppTheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _rangeLabel(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(AppThemeColors colors) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textPrimary,
              side: BorderSide(color: colors.border),
              backgroundColor: colors.surfaceVariant.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _start == null ? null : _apply,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Apply',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
