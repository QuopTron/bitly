class Extension {
  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final bool isEnabled;
  final String type;
  final int priority;

  const Extension({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    this.description = '',
    required this.isEnabled,
    required this.type,
    this.priority = 0,
  });

  Extension copyWith({
    String? id,
    String? name,
    String? version,
    String? author,
    String? description,
    bool? isEnabled,
    String? type,
    int? priority,
  }) {
    return Extension(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      author: author ?? this.author,
      description: description ?? this.description,
      isEnabled: isEnabled ?? this.isEnabled,
      type: type ?? this.type,
      priority: priority ?? this.priority,
    );
  }
}
