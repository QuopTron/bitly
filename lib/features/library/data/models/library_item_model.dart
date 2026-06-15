class LibraryItemModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final int fileSize;
  final String format;
  final DateTime addedAt;
  final String? coverPath;

  LibraryItemModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.fileSize,
    required this.format,
    required this.addedAt,
    this.coverPath,
  });

  factory LibraryItemModel.fromJson(Map<String, dynamic> json) {
    return LibraryItemModel(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      duration: json['duration'] as int,
      fileSize: json['file_size'] as int,
      format: json['format'] as String,
      addedAt: DateTime.parse(json['added_at'] as String),
      coverPath: json['cover_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'file_size': fileSize,
      'format': format,
      'added_at': addedAt.toIso8601String(),
      'cover_path': coverPath,
    };
  }
}
