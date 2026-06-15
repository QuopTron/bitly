import 'package:equatable/equatable.dart';
import 'download_status.dart';

class DownloadItem extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final String quality;
  final DownloadStatus status;
  final double progress;
  final int fileSize;
  final DateTime addedAt;

  const DownloadItem({
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl = '',
    this.quality = '320',
    this.status = DownloadStatus.pending,
    this.progress = 0,
    this.fileSize = 0,
    required this.addedAt,
  });

  @override
  List<Object?> get props =>
      [id, title, artist, coverUrl, quality, status, progress, fileSize, addedAt];
}
