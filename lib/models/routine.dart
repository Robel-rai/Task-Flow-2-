import 'package:flutter/material.dart';

/// A recurring daily habit.
///
/// [daysOfWeek] uses Dart's `DateTime.weekday` numbering: 1 = Monday …
/// 7 = Sunday. Stored as a comma-separated string like `'1,3,5'`.
class Routine {
  static const String allDays = '1,2,3,4,5,6,7';

  /// Time-of-day groups shown on the routines page, in display order.
  static const List<String> timeGroups = [
    'Morning',
    'Noon',
    'Afternoon',
    'Evening',
  ];

  final int? id;
  final String title;
  final String description;
  final String scheduledTime; // "HH:mm"
  final Set<int> daysOfWeek;
  final String color;
  final int streak;
  final bool isCompletedToday;
  final DateTime? lastCompletedDate;
  final bool notificationEnabled;
  final DateTime createdAt;

  Routine({
    this.id,
    required this.title,
    this.description = '',
    required this.scheduledTime,
    Set<int>? daysOfWeek,
    this.color = 'primary',
    this.streak = 0,
    this.isCompletedToday = false,
    this.lastCompletedDate,
    this.notificationEnabled = true,
    DateTime? createdAt,
  })  : daysOfWeek = daysOfWeek ?? {1, 2, 3, 4, 5, 6, 7},
        createdAt = createdAt ?? DateTime.now();

  /// Whether this routine applies on [day].
  bool isActiveOn(DateTime day) => daysOfWeek.contains(day.weekday);

  /// Derives a broad time-of-day category from the scheduled hour:
  /// Morning 5–11 · Noon 12–13 · Afternoon 14–16 · Evening 17–4.
  String get timeCategory {
    try {
      final hour = int.parse(scheduledTime.split(':')[0]);
      if (hour >= 5 && hour < 12) return 'Morning';
      if (hour >= 12 && hour < 14) return 'Noon';
      if (hour >= 14 && hour < 17) return 'Afternoon';
      return 'Evening';
    } catch (_) {
      return 'Anytime';
    }
  }

  /// Parses the scheduled time into a [TimeOfDay].
  TimeOfDay get timeOfDay {
    try {
      final parts = scheduledTime.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  String get daysOfWeekString {
    final days = daysOfWeek.toList()..sort();
    return days.join(',');
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'scheduled_time': scheduledTime,
      'days_of_week': daysOfWeekString,
      'color': color,
      'streak': streak,
      'is_completed_today': isCompletedToday ? 1 : 0,
      'last_completed_date': lastCompletedDate?.toIso8601String(),
      'notification_enabled': notificationEnabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Routine.fromMap(Map<String, dynamic> map) {
    final days = <int>{};
    for (final part in ((map['days_of_week'] as String?) ?? allDays).split(',')) {
      final d = int.tryParse(part.trim());
      if (d != null && d >= 1 && d <= 7) days.add(d);
    }
    if (days.isEmpty) days.addAll({1, 2, 3, 4, 5, 6, 7});

    return Routine(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      scheduledTime: map['scheduled_time'] as String? ?? '08:00',
      daysOfWeek: days,
      color: (map['color'] as String?) ?? 'primary',
      streak: (map['streak'] as int?) ?? 0,
      isCompletedToday: (map['is_completed_today'] as int?) == 1,
      lastCompletedDate: map['last_completed_date'] != null
          ? DateTime.tryParse(map['last_completed_date'] as String)
          : null,
      notificationEnabled: (map['notification_enabled'] as int?) != 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  Routine copyWith({
    int? id,
    String? title,
    String? description,
    String? scheduledTime,
    Set<int>? daysOfWeek,
    String? color,
    int? streak,
    bool? isCompletedToday,
    DateTime? lastCompletedDate,
    bool? notificationEnabled,
    DateTime? createdAt,
    bool clearLastCompletedDate = false,
  }) {
    return Routine(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      color: color ?? this.color,
      streak: streak ?? this.streak,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      lastCompletedDate: clearLastCompletedDate
          ? null
          : (lastCompletedDate ?? this.lastCompletedDate),
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
