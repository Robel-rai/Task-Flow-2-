/// A free-form tag attached to tasks (many-to-many via task_tags).
class Tag {
  final int? id;
  final String name;
  final String color;

  Tag({this.id, required this.name, this.color = 'primary'});

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color,
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: (map['color'] as String?) ?? 'primary',
    );
  }

  Tag copyWith({int? id, String? name, String? color}) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }
}
