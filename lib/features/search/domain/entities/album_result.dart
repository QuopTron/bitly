import 'package:equatable/equatable.dart';

class AlbumResult extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String coverUrl;
  final int trackCount;
  final int year;

  const AlbumResult({
    required this.id,
    required this.title,
    required this.artist,
    this.coverUrl = '',
    this.trackCount = 0,
    this.year = 0,
  });

  @override
  List<Object?> get props => [id, title, artist, coverUrl, trackCount, year];
}
