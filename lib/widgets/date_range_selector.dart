import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'date_range_picker.dart';

/// Dropdown trigger for a date-range filter: "Custom range…" (opens the
/// calendar range dialog) or "All dates".
///
/// Pure view — the caller owns the range state via [start], [end] and
/// [onRangeSelected], so the same widget drives both the Tasks and the
/// Focus page filters.
class DateRangeSelector extends StatelessWidget {
  const DateRangeSelector({
    super.key,
    required DateTime? start,
    required DateTime? end,
    required this.onRangeSelected,
  })  : _start = start,
        _end = end;

  final DateTime? _start;
  final DateTime? _end;
  final Future<void> Function(DateTime? start, DateTime? end) onRangeSelected;

  @override
  Widget build(BuildContext context) {
    final start = _start;
    final end = _end;

    final String value;
    if (start == null && end == null) {
      value = 'all';
    } else {
      value = 'custom';
    }

    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Date', isDense: true),
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        isDense: true,
        borderRadius: BorderRadius.circular(12),
        underline: const SizedBox.shrink(),
        selectedItemBuilder: (context) => [
          Text(_customLabel(_start, _end), overflow: TextOverflow.ellipsis),
          const Text('All dates'),
        ],
        items: const [
          DropdownMenuItem<String>(
              value: 'custom', child: Text('Custom range…')),
          DropdownMenuItem<String>(value: 'all', child: Text('All dates')),
        ],
        onChanged: (v) => _onChanged(context, v),
      ),
    );
  }

  Future<void> _onChanged(BuildContext context, String? value) async {
    if (value == 'all') {
      await onRangeSelected(null, null);
    } else if (value == 'custom') {
      final picked = await showDateRangePickerDialog(
        context,
        initialStart: _start,
        initialEnd: _end,
      );
      if (picked == null) return; // canceled — range stays as-is
      await onRangeSelected(picked.$1, picked.$2);
    }
  }

  /// The label shown when a custom range is selected, e.g. "Jun 1 – Jun 15".
  String _customLabel(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'Custom range…';
    if (start != null && end != null) {
      if (_sameDay(start, end)) {
        return DateFormat('MMM d, yyyy').format(start);
      }
      if (start.year == end.year) {
        return '${DateFormat('MMM d').format(start)} – '
            '${DateFormat('MMM d').format(end)}';
      }
      return '${DateFormat('MMM d, yyyy').format(start)} – '
          '${DateFormat('MMM d, yyyy').format(end)}';
    }
    return DateFormat('MMM d, yyyy').format(start ?? end!);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
