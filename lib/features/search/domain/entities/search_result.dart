import 'package:equatable/equatable.dart';

class SearchResult extends Equatable {
  final String id;
  final String title;
  final String source;
  final String quality;
  final int duration;

  const SearchResult({
    required this.id,
    required this.title,
    required this.source,
    this.quality = '',
    this.duration = 0,
  });

  @override
  List<Object?> get props => [id, title, source, quality, duration];
}
