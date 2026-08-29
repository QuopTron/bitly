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

/// Fuentes cuyas BUSQUEDAS requieren la sesion firmada para devolver
/// resultados: qobuz-web da 403 y amazon devuelve 0 sin verificar. Deezer y
/// pandora buscan de forma anonima -- un resultado vacio ahi casi siempre es
/// rate-limit (429) o "sin resultados", NUNCA un problema de sesion, asi que
/// abrir el modal de Cloudflare desde la busqueda es inutil y molesto.
final _verifyOnEmptySources = <String>{'qobuz-web', 'amazon'};

/// Resultado de intentar verificar una fuente con sesion firmada.
enum _VerifyOutcome { verified, notNeeded, failed }

/// Entrada del cache de resultados en memoria: resultados + momento en que se
/// guardaron. Resultados vacios se cachean con un TTL mucho mas corto para no
/// "congelar" un falso negativo (timeout/verificacion) durante minutos.
class _CachedSearch {
  final List<FeedItem> results;
  final DateTime at;
  const _CachedSearch(this.results, this.at);
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final BackendService _backend;
  final SearchCache _searchCache;

  final Map<String, DateTime> _lastVerifyAttempt = {};
  static const _verifyCooldown = Duration(minutes: 5);

  final Map<String, _CachedSearch> _resultCache = {};
  static const _searchTtl = Duration(minutes: 5);
  static const _emptyTtl = Duration(seconds: 20);
  static const _maxCacheEntries = 40;

  int _streamGeneration = 0;

  static String _cacheKey(String query, String source, String type, int limit) =>
      '$query\u0001$source\u0001$type\u0001$limit';

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

      final cacheKey = _cacheKey(event.query, event.source, event.type, event.limit);
      final hit = _resultCache[cacheKey];
      if (hit != null) {
        final ttl = hit.results.isEmpty ? _emptyTtl : _searchTtl;
        if (DateTime.now().difference(hit.at) < ttl) {
          final recents = List<String>.from(state.recentSearches);
          recents.remove(event.query);
          recents.insert(0, event.query);
          if (recents.length > 10) recents.removeLast();
          emit(state.copyWith(
            results: hit.results,
            loading: false,
            hasSearched: true,
            recentSearches: recents,
          ));
          return;
        }
        _resultCache.remove(cacheKey);
      }

      try {
        var gen = await _backend.searchStreaming(
          query: event.query, source: event.source,
          type: event.type, limit: event.limit,
        );
        _streamGeneration = gen;

        // If streaming init failed, retry once after a short delay (the native
        // bridge may have been busy with a prior RPC).
        if (gen == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (isClosed) return;
          gen = await _backend.searchStreaming(
            query: event.query, source: event.source,
            type: event.type, limit: event.limit,
          );
          _streamGeneration = gen;
        }

        if (gen == 0) {
          // Streaming truly unavailable — fall back to non-streaming search.
          await _finishSearch(event.query, event.source, event.type, event.limit, emit);
          return;
        }

        var lastEmittedCount = 0;
        const maxPolls = 100;
        for (var i = 0; i < maxPolls; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          if (isClosed) return;

          try {
            final poll = await _backend.getSearchStreamResults();
            if (poll.generation != _streamGeneration) return;

            if (poll.items.length > lastEmittedCount) {
              lastEmittedCount = poll.items.length;
              // Hide the spinner as soon as the FIRST batch of results
              // arrives — don't wait for all providers to finish. This makes
              // search feel instant (like SpotiFLAC) while remaining providers
              // continue streaming results in the background.
              emit(state.copyWith(
                results: poll.items,
                loading: poll.done,
                hasSearched: true,
              ));
            }

            if (poll.done) {
              await _cacheAndFinalize(event.query, event.source, event.type, event.limit, poll.items, emit);
              return;
            }
          } catch (_) {
            break;
          }
        }

        // Polling exhausted — emit whatever we have so far.
        if (lastEmittedCount > 0) {
          await _cacheAndFinalize(event.query, event.source, event.type, event.limit, state.results, emit);
        } else {
          await _finishSearch(event.query, event.source, event.type, event.limit, emit);
        }
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

  Future<List<FeedItem>> _searchAll(String query, String source, String type, int limit) async {
    try {
      return await _backend.search(query: query, source: source, type: type, limit: limit);
    } catch (e) {
      _log.w('[search] Busqueda combinada fallo para $source: $e');
      return const [];
    }
  }

  Future<bool> _sourceSessionUsable(String source) async {
    try {
      final status = await _backend.getSignedSessionStatus(source);
      return status.authenticated;
    } catch (_) {
      return true;
    }
  }

  Future<void> _cacheAndFinalize(
    String query, String source, String type, int limit,
    List<FeedItem> results, Emitter<SearchState> emit,
  ) async {
    final cacheKey = _cacheKey(query, source, type, limit);

    if (results.isEmpty && _verifyOnEmptySources.contains(source)) {
      final last = _lastVerifyAttempt[source];
      final inCooldown = last != null &&
          DateTime.now().difference(last) < _verifyCooldown;
      final sessionUsable = await _sourceSessionUsable(source);
      if (!inCooldown && !sessionUsable) {
        _lastVerifyAttempt[source] = DateTime.now();
        _log.i('[search] Fuente $source vacia -- intentando verificacion');
        switch (await _verifySource(source)) {
          case _VerifyOutcome.verified:
            _log.i('[search] Verificacion OK -- reintentando busqueda');
            results = await _searchAll(query, source, type, limit);
          case _VerifyOutcome.failed:
            emit(state.copyWith(
              loading: false,
              hasSearched: true,
              error: 'Verificacion requerida para ${sourceDisplayName(source)}. Abrela desde Configuracion y reintenta.',
            ));
            return;
          case _VerifyOutcome.notNeeded:
            break;
        }
      }
    }

    if (_resultCache.length >= _maxCacheEntries) {
      String? oldestKey;
      DateTime? oldestAt;
      _resultCache.forEach((k, v) {
        if (oldestAt == null || v.at.isBefore(oldestAt!)) {
          oldestKey = k;
          oldestAt = v.at;
        }
      });
      if (oldestKey != null) _resultCache.remove(oldestKey);
    }
    _resultCache[cacheKey] = _CachedSearch(results, DateTime.now());

    final recents = List<String>.from(state.recentSearches);
    recents.remove(query);
    recents.insert(0, query);
    if (recents.length > 10) recents.removeLast();
    unawaited(_searchCache.saveRecentSearch(query));
    emit(state.copyWith(
      results: results,
      loading: false,
      hasSearched: true,
      recentSearches: recents,
    ));
  }

  Future<void> _finishSearch(
    String query, String source, String type, int limit,
    Emitter<SearchState> emit,
  ) async {
    try {
      var results = await _searchAll(query, source, type, limit);
      await _cacheAndFinalize(query, source, type, limit, results, emit);
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: e.toString(),
      ));
    }
  }

  Future<_VerifyOutcome> _verifySource(String source) async {
    try {
      final url = await _backend.getPendingVerificationUrl(source);
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
      _log.e('[search] Error de verificacion para $source: $e');
      return _VerifyOutcome.failed;
    }
  }

  void _loadRecents() {
    _searchCache.getRecentSearches().then((searches) {
      if (!isClosed) add(RecentSearchesLoaded(searches));
    });
  }

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
