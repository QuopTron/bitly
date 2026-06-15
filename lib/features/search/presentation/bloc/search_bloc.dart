import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'search_event.dart';
import 'search_state.dart';
import '../../data/repositories/search_repository.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final SearchRepository _repository;
  Timer? _debounce;

  SearchBloc(this._repository) : super(const SearchState()) {
    on<QueryChanged>(_onQueryChanged);
    on<SearchByUrlEvent>(_onSearchByUrl);
    on<TypeFilterChanged>(_onTypeFilterChanged);
    on<SourceFilterChanged>(_onSourceFilterChanged);
    on<ClearRecent>(_onClearRecent);
    on<LoadMore>(_onLoadMore);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  Future<void> _onQueryChanged(
      QueryChanged event, Emitter<SearchState> emit) async {
    emit(state.copyWith(query: event.query, error: null));
    _debounce?.cancel();
    if (event.query.length < 2) {
      emit(state.copyWith(
          tracks: [], albums: [], artists: [], hasMore: false));
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      emit(state.copyWith(isLoading: true, currentPage: 1));
      try {
        final response = await _repository.searchTracks(event.query);
        emit(state.copyWith(
          tracks: response,
          isLoading: false,
          hasMore: response.length >= 20,
          currentPage: 1,
        ));
      } catch (e) {
        emit(state.copyWith(isLoading: false, error: e.toString()));
      }
    });
  }

  Future<void> _onSearchByUrl(
      SearchByUrlEvent event, Emitter<SearchState> emit) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final results = await _repository.searchByUrl(event.url);
      emit(state.copyWith(isLoading: false, tracks: [results]));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onTypeFilterChanged(
      TypeFilterChanged event, Emitter<SearchState> emit) async {
    emit(state.copyWith(type: event.type));
  }

  Future<void> _onSourceFilterChanged(
      SourceFilterChanged event, Emitter<SearchState> emit) async {
    // source filter logic
  }

  Future<void> _onClearRecent(
      ClearRecent event, Emitter<SearchState> emit) async {
    emit(state.copyWith(recentSearches: []));
  }

  Future<void> _onLoadMore(
      LoadMore event, Emitter<SearchState> emit) async {
    if (state.isLoading || !state.hasMore) return;
    final nextPage = state.currentPage + 1;
    emit(state.copyWith(isLoading: true));
    try {
      final results = await _repository.searchTracks(state.query);
      emit(state.copyWith(
        tracks: [...state.tracks, ...results],
        isLoading: false,
        hasMore: results.length >= 20,
        currentPage: nextPage,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }
}
