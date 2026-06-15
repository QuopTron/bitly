class DownloadItemModel {
  final String id;
  final String title;
  final String artist;
  final String url;
  final String quality;
  final String status;
  final double progress;
  final int fileSize;
  final DateTime addedAt;

  const DownloadItemModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    this.quality = '320',
    this.status = 'pending',
    this.progress = 0,
    this.fileSize = 0,
    required this.addedAt,
  });

  factory DownloadItemModel.fromJson(Map<String, dynamic> json) =>
      DownloadItemModel(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String? ?? '',
        url: json['url'] as String? ?? '',
        quality: json['quality'] as String? ?? '320',
        status: json['status'] as String? ?? 'pending',
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
        fileSize: json['file_size'] as int? ?? 0,
        addedAt: json['added_at'] != null
            ? DateTime.parse(json['added_at'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'url': url,
        'quality': quality,
        'status': status,
        'progress': progress,
        'file_size': fileSize,
        'added_at': addedAt.toIso8601String(),
      };

  DownloadItemModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? url,
    String? quality,
    String? status,
    double? progress,
    int? fileSize,
    DateTime? addedAt,
  }) =>
      DownloadItemModel(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        url: url ?? this.url,
        quality: quality ?? this.quality,
        status: status ?? this.status,
        progress: progress ?? this.progress,
        fileSize: fileSize ?? this.fileSize,
        addedAt: addedAt ?? this.addedAt,
      );
}
