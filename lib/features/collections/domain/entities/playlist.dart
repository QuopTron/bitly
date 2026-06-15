import 'collection.dart';

class Playlist extends Collection {
  final List<String> trackIds;

  const Playlist({
    required super.id,
    required super.name,
    super.description,
    super.itemCount,
    required super.createdAt,
    required super.updatedAt,
    this.trackIds = const [],
  }) : super(type: 'playlist');
}
