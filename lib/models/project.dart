import 'dart:ui';

import '../theme/app_theme.dart';

/// A group of related tasks.
class Project {
  final int? id;
  final String title;
  final String description;
  final String color; // color key: 'primary', 'blue', 'amber', 'rose', ...
  final String status; // Pending | In Progress | Completed
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  Project({
    this.id,
    required this.title,
    this.description = '',
    this.color = 'primary',
    this.status = 'Pending',
    this.startDate,
    this.dueDate,
    DateTime? createdAt,
    this.updatedAt,
    this.deletedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'color': color,
      'status': status,
      'start_date': startDate?.toIso8601String(),
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      color: (map['color'] as String?) ?? 'primary',
      status: (map['status'] as String?) ?? 'Pending',
      startDate: map['start_date'] != null
          ? DateTime.tryParse(map['start_date'] as String)
          : null,
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'] as String)
          : null,
    );
  }

  Project copyWith({
    int? id,
    String? title,
    String? description,
    String? color,
    String? status,
    DateTime? startDate,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearStartDate = false,
    bool clearDueDate = false,
    bool clearDeletedAt = false,
  }) {
    return Project(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      status: status ?? this.status,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  /// Helper to convert the stored color key into a [Color].
  Color get displayColor => AppTheme.getRoutineColor(color);
}
