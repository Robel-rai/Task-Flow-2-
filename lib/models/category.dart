/// A task category (normalized table in v2, unlike v1's free-text strings).
class Category {
  final int? id;
  final String name;
  final String color;
  final String? icon;
  final int sortOrder;
  final DateTime createdAt;

  Category({
    this.id,
    required this.name,
    this.color = 'primary',
    this.icon,
    this.sortOrder = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'color': color,
      'icon': icon,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: (map['color'] as String?) ?? 'primary',
      icon: map['icon'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? color,
    String? icon,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
