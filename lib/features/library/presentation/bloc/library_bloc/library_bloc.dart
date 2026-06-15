import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'library_event.dart';
import 'library_state.dart';
import '../../../domain/usecases/get_library_tracks.dart';
import '../../../domain/usecases/get_library_albums.dart';
import '../../../domain/usecases/get_library_artists.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final GetLibraryTracks _getTracks;
  final GetLibraryAlbums _getAlbums;
  final GetLibraryArtists _getArtists;

  LibraryBloc()
      : _getTracks = GetIt.instance<GetLibraryTracks>(),
        _getAlbums = GetIt.instance<GetLibraryAlbums>(),
        _getArtists = GetIt.instance<GetLibraryArtists>(),
        super(const LibraryState()) {
    on<LoadTracks>(_onLoadTracks);
    on<LoadAlbums>(_onLoadAlbums);
    on<LoadArtists>(_onLoadArtists);
    on<SwitchView>(_onSwitchView);
    on<SearchLibrary>(_onSearch);
    on<SortBy>(_onSortBy);
    on<FilterBy>(_onFilterBy);
  }

  Future<void> _onLoadTracks(LoadTracks event, Emitter<LibraryState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final tracks = await _getTracks.call();
      emit(state.copyWith(tracks: tracks, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadAlbums(LoadAlbums event, Emitter<LibraryState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final albums = await _getAlbums.call();
      emit(state.copyWith(albums: albums, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadArtists(LoadArtists event, Emitter<LibraryState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final artists = await _getArtists.call();
      emit(state.copyWith(artists: artists, isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onSwitchView(SwitchView event, Emitter<LibraryState> emit) {
    emit(state.copyWith(currentView: event.view));
  }

  void _onSearch(SearchLibrary event, Emitter<LibraryState> emit) {
    emit(state.copyWith(searchQuery: event.query));
  }

  void _onSortBy(SortBy event, Emitter<LibraryState> emit) {
    emit(state.copyWith(sortBy: event.sortKey));
  }

  void _onFilterBy(FilterBy event, Emitter<LibraryState> emit) {
    emit(state.copyWith(sortBy: event.filter));
  }
}
