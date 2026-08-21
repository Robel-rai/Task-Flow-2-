import 'package:intl/intl.dart';

/// Shared helpers for the calendar views.

/// `yyyy-MM-dd` key used by the provider's per-day task caches.
String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Formats a stored `HH:mm` value as `h:mm AM/PM`. Returns '' when null.
String formatTime(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return '';
  final parts = hhmm.split(':');
  if (parts.length != 2) return hhmm;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final period = hour >= 12 ? 'PM' : 'AM';
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$h12:${minute.toString().padLeft(2, '0')} $period';
}
