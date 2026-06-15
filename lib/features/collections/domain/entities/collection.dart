class Collection {
  final String id;
  final String name;
  final String? description;
  final String type;
  final int itemCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Collection({
    required this.id,
    required this.name,
    this.description,
    this.type = 'playlist',
    this.itemCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Collection copyWith({
    String? id,
    String? name,
    String? description,
    String? type,
    int? itemCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      itemCount: itemCount ?? this.itemCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
