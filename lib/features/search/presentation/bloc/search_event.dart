import 'package:equatable/equatable.dart';

abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

class QueryChanged extends SearchEvent {
  final String query;

  const QueryChanged(this.query);

  @override
  List<Object?> get props => [query];
}

class SearchByUrlEvent extends SearchEvent {
  final String url;

  const SearchByUrlEvent(this.url);

  @override
  List<Object?> get props => [url];
}

class TypeFilterChanged extends SearchEvent {
  final String type;

  const TypeFilterChanged(this.type);

  @override
  List<Object?> get props => [type];
}

class SourceFilterChanged extends SearchEvent {
  final List<String> sources;

  const SourceFilterChanged(this.sources);

  @override
  List<Object?> get props => [sources];
}

class ClearRecent extends SearchEvent {
  const ClearRecent();
}

class LoadMore extends SearchEvent {
  const LoadMore();
}
