/// A checklist item belonging to a task.
class Subtask {
  final int? id;
  final int? taskId;
  final String title;
  final bool isCompleted;
  final int sortOrder;
  final DateTime createdAt;

  Subtask({
    this.id,
    this.taskId,
    required this.title,
    this.isCompleted = false,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      'title': title,
      'is_completed': isCompleted ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'] as int?,
      taskId: map['task_id'] as int?,
      title: map['title'] as String,
      isCompleted: (map['is_completed'] as int?) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  Subtask copyWith({
    int? id,
    int? taskId,
    String? title,
    bool? isCompleted,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
