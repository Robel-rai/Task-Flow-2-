/// The core task entity for TaskFlow v2.
class Task {
  final int? id;
  final String title;
  final String description;
  final int? categoryId;
  final int? projectId;
  final String priority; // High | Medium | Low
  final String status; // Pending | In Progress | Completed
  final DateTime? scheduledDate; // yyyy-MM-dd
  final String? scheduledTime; // HH:mm
  final DateTime? dueDate; // deadline
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;
  final int timeSpentSeconds;
  final DateTime? timerStartedAt;
  final int sortOrder; // manual order within a day
  final String? recurrenceRule; // e.g. 'FREQ=WEEKLY;BYDAY=MO,WE'
  final DateTime? recurrenceEndDate;
  final int? parentTaskId; // recurring instances reference the master
  final DateTime? deletedAt; // soft delete -> trash
  final DateTime? archivedAt;

  Task({
    this.id,
    required this.title,
    this.description = '',
    this.categoryId,
    this.projectId,
    this.priority = 'Medium',
    this.status = 'Pending',
    this.scheduledDate,
    this.scheduledTime,
    this.dueDate,
    DateTime? createdAt,
    this.updatedAt,
    this.completedAt,
    this.timeSpentSeconds = 0,
    this.timerStartedAt,
    this.sortOrder = 0,
    this.recurrenceRule,
    this.recurrenceEndDate,
    this.parentTaskId,
    this.deletedAt,
    this.archivedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'project_id': projectId,
      'priority': priority,
      'status': status,
      'scheduled_date': scheduledDate?.toIso8601String().split('T').first,
      'scheduled_time': scheduledTime,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'time_spent_seconds': timeSpentSeconds,
      'timer_started_at': timerStartedAt?.toIso8601String(),
      'sort_order': sortOrder,
      'recurrence_rule': recurrenceRule,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
      'parent_task_id': parentTaskId,
      'deleted_at': deletedAt?.toIso8601String(),
      'archived_at': archivedAt?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      categoryId: map['category_id'] as int?,
      projectId: map['project_id'] as int?,
      priority: (map['priority'] as String?) ?? 'Medium',
      status: (map['status'] as String?) ?? 'Pending',
      scheduledDate: map['scheduled_date'] != null
          ? DateTime.tryParse(map['scheduled_date'] as String)
          : null,
      scheduledTime: map['scheduled_time'] as String?,
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
      timeSpentSeconds: (map['time_spent_seconds'] as int?) ?? 0,
      timerStartedAt: map['timer_started_at'] != null
          ? DateTime.tryParse(map['timer_started_at'] as String)
          : null,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      recurrenceRule: map['recurrence_rule'] as String?,
      recurrenceEndDate: map['recurrence_end_date'] != null
          ? DateTime.tryParse(map['recurrence_end_date'] as String)
          : null,
      parentTaskId: map['parent_task_id'] as int?,
      deletedAt: map['deleted_at'] != null
          ? DateTime.tryParse(map['deleted_at'] as String)
          : null,
      archivedAt: map['archived_at'] != null
          ? DateTime.tryParse(map['archived_at'] as String)
          : null,
    );
  }

  Task copyWith({
    int? id,
    String? title,
    String? description,
    int? categoryId,
    int? projectId,
    String? priority,
    String? status,
    DateTime? scheduledDate,
    String? scheduledTime,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    int? timeSpentSeconds,
    DateTime? timerStartedAt,
    int? sortOrder,
    String? recurrenceRule,
    DateTime? recurrenceEndDate,
    int? parentTaskId,
    DateTime? deletedAt,
    DateTime? archivedAt,
    bool clearCategoryId = false,
    bool clearProjectId = false,
    bool clearScheduledDate = false,
    bool clearScheduledTime = false,
    bool clearDueDate = false,
    bool clearCompletedAt = false,
    bool clearTimerStartedAt = false,
    bool clearRecurrenceRule = false,
    bool clearParentTaskId = false,
    bool clearDeletedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: clearCategoryId ? null : (categoryId ?? this.categoryId),
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      priority: priority ?? this.priority,
      status: status ?? this.status,
      scheduledDate:
          clearScheduledDate ? null : (scheduledDate ?? this.scheduledDate),
      scheduledTime:
          clearScheduledTime ? null : (scheduledTime ?? this.scheduledTime),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      timerStartedAt:
          clearTimerStartedAt ? null : (timerStartedAt ?? this.timerStartedAt),
      sortOrder: sortOrder ?? this.sortOrder,
      recurrenceRule:
          clearRecurrenceRule ? null : (recurrenceRule ?? this.recurrenceRule),
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      parentTaskId:
          clearParentTaskId ? null : (parentTaskId ?? this.parentTaskId),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  // ─── Helpers ───

  /// Formatted time spent as HH:MM:SS
  String get formattedTimeSpent {
    final h = (timeSpentSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((timeSpentSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (timeSpentSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Formatted time as Xh Ym
  String get formattedTimeFriendly {
    final hours = timeSpentSeconds ~/ 3600;
    final minutes = (timeSpentSeconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '0m';
  }

  bool get isTimerRunning => timerStartedAt != null;

  /// Current time spent including live timer.
  int get currentTimeSpentSeconds {
    if (timerStartedAt != null) {
      return timeSpentSeconds +
          DateTime.now().difference(timerStartedAt!).inSeconds;
    }
    return timeSpentSeconds;
  }

  bool get isDeleted => deletedAt != null;
}
