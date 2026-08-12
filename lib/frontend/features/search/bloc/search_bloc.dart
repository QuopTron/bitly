import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import '../../../../backend/rpc/backend_service.dart';
import '../../../../backend/cache/search_cache.dart';
import '../../../../backend/services/verification_service.dart';
import '../../../shared/models/feed_models.dart';
import '../../../shared/constants/source_constants.dart';
import 'search_event.dart';
import 'search_state.dart';

final _log = Logger();

/// Fuentes que usan sesión firmada (signed session v2 / Cloudflare).
/// Si una búsqueda devuelve vacío en estas fuentes, probablemente hace falta
/// verificar primero (Qobuz lanza VERIFY_REQUIRED).
final _signedSessionSources = VerificationService.signedSessionSources.toSet();

/// Resultado de intentar verificar una fuente con sesión firmada.
enum _VerifyOutcome { verified, notNeeded, failed }

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final BackendService _backend;
  final SearchCache _searchCache;

  SearchBloc(this._backend, this._searchCache) : super(const SearchState()) {
    _loadRecents();
    _loadSearchConfig();

    on<SearchConfigLoaded>((event, emit) {
      emit(state.copyWith(searchConfig: event.config));
    });

    on<SearchQueryChanged>((event, emit) {
      emit(state.copyWith(query: event.query));
    });

    on<SearchSourceChanged>((event, emit) {
      emit(state.copyWith(source: event.source));
    });

    on<SearchTypeChanged>((event, emit) {
      emit(state.copyWith(type: event.type));
    });

    on<PerformSearch>((event, emit) async {
      emit(state.copyWith(loading: true, error: null, query: event.query, source: event.source));
      try {
        var results = await _searchAll(event.query, event.source, event.type, event.limit);

        // backend haya respondido VERIFY_REQUIRED (Qobuz). Verificamos y
        // reintentamos una sola vez.
        if (results.isEmpty && _signedSessionSources.contains(event.source)) {
          _log.i('[search] Fuente ${event.source} vacía — intentando verificación');
          switch (await _verifySource(event.source)) {
              case _VerifyOutcome.verified:
              _log.i('[search] Verificación OK — reintentando búsqueda');
              results = await _searchAll(event.query, event.source, event.type, event.limit);
            case _VerifyOutcome.failed:
              emit(state.copyWith(
                loading: false,
                hasSearched: true,
                error: 'Verificación requerida para ${sourceDisplayName(event.source)}. Ábrela desde Configuración y reintenta.',
              ));
              return;
            case _VerifyOutcome.notNeeded:
              break; // no hubo verificación → mostrar vacío normal
          }
        }

        final recents = List<String>.from(state.recentSearches);
        recents.remove(event.query);
        recents.insert(0, event.query);
        if (recents.length > 10) recents.removeLast();
        unawaited(_searchCache.saveRecentSearch(event.query));
        emit(state.copyWith(
          results: results,
          loading: false,
          hasSearched: true,
          recentSearches: recents,
        ));
      } catch (e) {
        emit(state.copyWith(
          loading: false,
          error: e.toString(),
        ));
      }
    });

    on<AddRecentSearch>((event, emit) {
      final recents = List<String>.from(state.recentSearches);
      recents.remove(event.query);
      recents.insert(0, event.query);
      if (recents.length > 10) recents.removeLast();
      unawaited(_searchCache.saveRecentSearch(event.query));
      emit(state.copyWith(recentSearches: recents));
    });

    on<ClearRecentSearches>((event, emit) {
      unawaited(_searchCache.clearRecentSearches());
      emit(state.copyWith(recentSearches: const []));
    });

    on<RemoveRecentSearch>((event, emit) {
      final recents = List<String>.from(state.recentSearches);
      recents.remove(event.query);
      unawaited(_searchCache.removeRecentSearch(event.query));
      emit(state.copyWith(recentSearches: recents));
    });

    on<RecentSearchesLoaded>((event, emit) {
      emit(state.copyWith(recentSearches: event.searches));
    });

    on<ClearSearch>((event, emit) {
      emit(state.copyWith(
        query: '',
        results: const [],
        loading: false,
        error: null,
        hasSearched: false,
      ));
    });
  }

    /// Runs a search for the given source. With [type]="all" the backend performs
  /// a single unfiltered customSearch and returns the capped combined mix
  /// (SpotiFLAC principle). With a category [type] (e.g. "tracks", "albums") it
  /// re-queries that category with a higher [limit] so the user sees many more
  /// results than the mix — matching how SpotiFLAC expands a category on tap.
  Future<List<FeedItem>> _searchAll(String query, String source, String type, int limit) async {
    try {
      return await _backend.search(query: query, source: source, type: type, limit: limit);
    } catch (e) {
      _log.w('[search] Búsqueda combinada falló para $source: $e');
      return const [];
    }
  }

  /// Ejecuta el flujo completo de verificación (WebView → grant → complete)
  /// para una fuente con sesión firmada.
  Future<_VerifyOutcome> _verifySource(String source) async {
    try {
      var url = await _backend.getPendingVerificationUrl(source);
      if (url.isEmpty) {
        url = await _backend.triggerExtensionVerification(source);
      }
      if (url.isEmpty) return _VerifyOutcome.notNeeded;

      final service = VerificationService();
      if (!service.isReady) {
        _log.w('[search] VerificationService no inicializado');
        return _VerifyOutcome.failed;
      }

      final grant = await service.showVerification(
        extId: source,
        displayName: sourceDisplayName(source),
        authUrl: url,
      );
      if (grant == null || grant.isEmpty) return _VerifyOutcome.failed;
      final ok = await _backend.completeSignedSessionGrant(source, grant);
      return ok ? _VerifyOutcome.verified : _VerifyOutcome.failed;
    } catch (e) {
      _log.e('[search] Error de verificación para $source: $e');
      return _VerifyOutcome.failed;
    }
  }

  void _loadRecents() {
    _searchCache.getRecentSearches().then((searches) {
      if (!isClosed) add(RecentSearchesLoaded(searches));
    });
  }

  /// Loads each source's search category bubbles (manifest searchBehavior) once,
  /// so the chips render per-source labels/icons like SpotiFLAC. Non-fatal.
  void _loadSearchConfig() {
    _backend.getSearchConfig().then((list) {
      if (isClosed) return;
      final map = <String, SourceSearchConfig>{
        for (final c in list) c.source: c,
      };
      add(SearchConfigLoaded(map));
    }).catchError((_) {});
  }
}


