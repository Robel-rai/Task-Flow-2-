/// A custom kanban column (task progress state) for one project.
///
/// A project with no custom statuses falls back to the built-in defaults
/// (Pending / In Progress / Completed). Rows are created when the user
/// customizes a project's columns in the kanban header.
class ProjectStatus {
  final int? id;
  final int? projectId;
  final String name;
  final String color; // color key or '#RRGGBB' hex (see AppTheme)
  final int sortOrder;
  final DateTime createdAt;

  ProjectStatus({
    this.id,
    this.projectId,
    required this.name,
    this.color = 'primary',
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'project_id': projectId,
      'name': name,
      'color': color,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ProjectStatus.fromMap(Map<String, dynamic> map) {
    return ProjectStatus(
      id: map['id'] as int?,
      projectId: map['project_id'] as int?,
      name: map['name'] as String,
      color: (map['color'] as String?) ?? 'primary',
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  ProjectStatus copyWith({
    int? id,
    int? projectId,
    String? name,
    String? color,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return ProjectStatus(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
