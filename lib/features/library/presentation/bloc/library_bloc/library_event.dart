import 'package:equatable/equatable.dart';

abstract class LibraryEvent extends Equatable {
  const LibraryEvent();

  @override
  List<Object?> get props => [];
}

class LoadTracks extends LibraryEvent {}

class LoadAlbums extends LibraryEvent {}

class LoadArtists extends LibraryEvent {}

class SwitchView extends LibraryEvent {
  final String view;
  const SwitchView(this.view);

  @override
  List<Object?> get props => [view];
}

class SearchLibrary extends LibraryEvent {
  final String query;
  const SearchLibrary(this.query);

  @override
  List<Object?> get props => [query];
}

class SortBy extends LibraryEvent {
  final String sortKey;
  const SortBy(this.sortKey);

  @override
  List<Object?> get props => [sortKey];
}

class FilterBy extends LibraryEvent {
  final String filter;
  const FilterBy(this.filter);

  @override
  List<Object?> get props => [filter];
}
