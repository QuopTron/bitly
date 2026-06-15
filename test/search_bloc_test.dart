import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bitly/features/search/presentation/bloc/search_bloc.dart';
import 'package:bitly/features/search/presentation/bloc/search_event.dart';
import 'package:bitly/features/search/presentation/bloc/search_state.dart';
import 'package:bitly/features/search/data/repositories/search_repository.dart';

class MockSearchRepository extends Mock implements SearchRepository {}

void main() {
  late SearchRepository repository;
  late SearchBloc searchBloc;

  setUp(() {
    repository = MockSearchRepository();
    searchBloc = SearchBloc(repository);
  });

  tearDown(() {
    searchBloc.close();
  });

  group('SearchBloc', () {
    test('initial state is correct', () {
      expect(searchBloc.state, const SearchState());
    });

    blocTest<SearchBloc, SearchState>(
      'emits empty results when query has less than 2 characters',
      build: () => searchBloc,
      act: (bloc) => bloc.add(const QueryChanged('a')),
      expect: () => [
        const SearchState(
          query: 'a',
          tracks: [],
          albums: [],
          artists: [],
          hasMore: false,
        ),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'clears recent searches on ClearRecent',
      build: () => searchBloc,
      seed: () => const SearchState(recentSearches: ['query1', 'query2']),
      act: (bloc) => bloc.add(const ClearRecent()),
      expect: () => [
        const SearchState(recentSearches: []),
      ],
    );

    group('SearchByUrlEvent', () {
      const testUrl = 'https://open.spotify.com/track/123';
      const testResult = {'id': 'track-123', 'title': 'Test Track'};

      blocTest<SearchBloc, SearchState>(
        'emits [loading, loaded] when search by URL succeeds',
        build: () => searchBloc,
        setUp: () {
          when(() => repository.searchByUrl(testUrl))
              .thenAnswer((_) async => testResult);
        },
        act: (bloc) => bloc.add(const SearchByUrlEvent(testUrl)),
        expect: () => [
          const SearchState(isLoading: true),
          const SearchState(isLoading: false, tracks: [testResult]),
        ],
      );

      blocTest<SearchBloc, SearchState>(
        'emits [loading, error] when search by URL fails',
        build: () => searchBloc,
        setUp: () {
          when(() => repository.searchByUrl(testUrl))
              .thenThrow(Exception('Invalid URL'));
        },
        act: (bloc) => bloc.add(const SearchByUrlEvent(testUrl)),
        expect: () => [
          const SearchState(isLoading: true),
          const SearchState(isLoading: false, error: 'Exception: Invalid URL'),
        ],
      );
    });

    group('TypeFilterChanged', () {
      blocTest<SearchBloc, SearchState>(
        'updates the type filter',
        build: () => searchBloc,
        act: (bloc) => bloc.add(const TypeFilterChanged('album')),
        expect: () => [
          const SearchState(type: 'album'),
        ],
      );
    });

    group('LoadMore', () {
      const testResults = [{'id': '1', 'title': 'Track 1'}];

      blocTest<SearchBloc, SearchState>(
        'does not load more when already loading',
        build: () => searchBloc,
        seed: () => const SearchState(isLoading: true, hasMore: true),
        act: (bloc) => bloc.add(const LoadMore()),
        expect: () => [],
      );

      blocTest<SearchBloc, SearchState>(
        'does not load more when hasMore is false',
        build: () => searchBloc,
        seed: () => const SearchState(hasMore: false, query: 'test'),
        act: (bloc) => bloc.add(const LoadMore()),
        expect: () => [],
      );

      blocTest<SearchBloc, SearchState>(
        'loads next page when available',
        build: () => searchBloc,
        setUp: () {
          when(() => repository.searchTracks(any(),
                  type: any(named: 'type'),
                  page: any(named: 'page'),
                  limit: any(named: 'limit')))
              .thenAnswer((_) async => testResults);
        },
        seed: () => const SearchState(
          query: 'test',
          hasMore: true,
          tracks: [],
        ),
        act: (bloc) => bloc.add(const LoadMore()),
        expect: () => [
          const SearchState(
            query: 'test',
            hasMore: true,
            isLoading: true,
            tracks: [],
          ),
          const SearchState(
            query: 'test',
            tracks: testResults,
            hasMore: false,
            isLoading: false,
            currentPage: 2,
          ),
        ],
      );

      blocTest<SearchBloc, SearchState>(
        'emits error state when LoadMore fails',
        build: () => searchBloc,
        setUp: () {
          when(() => repository.searchTracks(any(),
                  type: any(named: 'type'),
                  page: any(named: 'page'),
                  limit: any(named: 'limit')))
              .thenThrow(Exception('Load failed'));
        },
        seed: () => const SearchState(
          query: 'test',
          hasMore: true,
          tracks: [],
          currentPage: 1,
        ),
        act: (bloc) => bloc.add(const LoadMore()),
        expect: () => [
          const SearchState(
            query: 'test', hasMore: true,
            tracks: [], currentPage: 1,
            isLoading: true,
          ),
          const SearchState(
            query: 'test', hasMore: true,
            tracks: [], currentPage: 1,
            isLoading: false,
            error: 'Exception: Load failed',
          ),
        ],
      );
    });

    // Nota: el debounce de 300ms usa Timer + emit dentro del callback,
    // lo cual no es testeable con blocTest (emit fuera del event handler).
    // La lógica de búsqueda en sí (searchTracks, errores, paginación)
    // está cubierta por los tests de LoadMore y SearchByUrl.
  });
}
