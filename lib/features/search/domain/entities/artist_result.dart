import 'package:equatable/equatable.dart';

class ArtistResult extends Equatable {
  final String id;
  final String name;
  final String imageUrl;
  final String genre;
  final int albumCount;

  const ArtistResult({
    required this.id,
    required this.name,
    this.imageUrl = '',
    this.genre = '',
    this.albumCount = 0,
  });

  @override
  List<Object?> get props => [id, name, imageUrl, genre, albumCount];
}
