class QueueItemModel {
  final String id;
  final String downloadItemId;
  final int priority;
  final DateTime addedAt;
  final String status;

  const QueueItemModel({
    required this.id,
    required this.downloadItemId,
    this.priority = 0,
    required this.addedAt,
    this.status = 'pending',
  });

  factory QueueItemModel.fromJson(Map<String, dynamic> json) =>
      QueueItemModel(
        id: json['id'] as String,
        downloadItemId: json['download_item_id'] as String,
        priority: json['priority'] as int? ?? 0,
        addedAt: json['added_at'] != null
            ? DateTime.parse(json['added_at'] as String)
            : DateTime.now(),
        status: json['status'] as String? ?? 'pending',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'download_item_id': downloadItemId,
        'priority': priority,
        'added_at': addedAt.toIso8601String(),
        'status': status,
      };

  QueueItemModel copyWith({
    String? id,
    String? downloadItemId,
    int? priority,
    DateTime? addedAt,
    String? status,
  }) =>
      QueueItemModel(
        id: id ?? this.id,
        downloadItemId: downloadItemId ?? this.downloadItemId,
        priority: priority ?? this.priority,
        addedAt: addedAt ?? this.addedAt,
        status: status ?? this.status,
      );
}
