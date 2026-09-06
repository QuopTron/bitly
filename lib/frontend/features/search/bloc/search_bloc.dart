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
  // Empty results are cached briefly so a genuine "no results" isn't re-run
  // on every keystroke — but short enough that a false empty (provider still
  // cooling / first attempt raced) doesn't poison retries for long.
  static const _emptyTtl = Duration(seconds: 6);
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

      await _attemptSearch(event, emit, allowRetry: true);
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

  /// Runs one streaming search attempt (init + poll until done or window).
  /// [allowRetry] is true for the user's attempt: if the poll window expires
  /// with ZERO results and the backend never said "done", the search silently
  /// re-runs once — the first attempt often races startup RPC congestion on
  /// the native bridge (home feed, stream pre-warm, session verification all
  /// serialize on one thread), and a bare "no results" there is a false
  /// negative that makes the FIRST search of a session look dead while the
  /// second works. The retry starts after that congestion has drained, so it
  /// typically returns within the normal 1-3s.
  ///
  /// The same false negative happens when the backend DOES answer "done" but
  /// fast and empty: on the first cold search the source's anonymous session
  /// (Spotify sp_t cookie, etc.) is fetched on the critical path and can fail
  /// or time out once, then succeed on the retry once the session is warm.
  /// So a quick empty answer also triggers one silent re-run (single-source
  /// only — "Todas" has other providers streaming in, so a fast empty there
  /// is a genuine no-results).
  Future<void> _attemptSearch(
    PerformSearch event, Emitter<SearchState> emit, {
    required bool allowRetry,
  }) async {
    try {
      final attemptStarted = DateTime.now();
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
      var lastItems = <FeedItem>[];
      const maxPolls = 160; // ~16s per attempt; the retry covers the rest.
      var backendDone = false;
      for (var i = 0; i < maxPolls; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (isClosed) return;

        try {
          final poll = await _backend.getSearchStreamResults();
          if (poll.generation != _streamGeneration) return;

          if (poll.items.length > lastEmittedCount) {
            lastEmittedCount = poll.items.length;
            lastItems = poll.items;
            // Hide the spinner as soon as the FIRST batch of results
            // arrives — don't wait for all providers to finish. This makes
            // search feel instant (like SpotiFLAC) while remaining providers
            // continue streaming results in the background.
            emit(state.copyWith(
              results: poll.items,
              loading: false,
              hasSearched: true,
            ));
          }

          if (poll.done) {
            backendDone = true;
            final elapsedMs =
                DateTime.now().difference(attemptStarted).inMilliseconds;
            final singleSource =
                event.source.isNotEmpty && event.source != 'all';
            // Fast empty answer on the first attempt = cold session false
            // negative (see [_attemptSearch] doc). Re-run once after a beat
            // so the source's session warm-up lands before the retry.
            if (poll.items.isEmpty &&
                allowRetry &&
                singleSource &&
                elapsedMs < 3500 &&
                !isClosed) {
              _log.i('[search] Primer resultado vacio rapido para '
                  '${event.source} (${elapsedMs}ms) — reintentando');
              await Future<void>.delayed(const Duration(milliseconds: 350));
              if (isClosed) return;
              await _attemptSearch(event, emit, allowRetry: false);
              return;
            }
            await _cacheAndFinalize(event.query, event.source, event.type, event.limit, poll.items, emit);
            return;
          }
        } catch (_) {
          break;
        }
      }

      if (!backendDone && lastItems.isEmpty && allowRetry && !isClosed) {
        // Window expired with NOTHING and the backend never answered done:
        // the first attempt raced congestion (or the backend just needed a
        // warm-up). Retry once from scratch — by now the bridge queue has
        // drained, so this attempt finishes at normal speed.
        _log.i('[search] Ventana expirada sin resultados para ${event.source} — reintentando');
        await _attemptSearch(event, emit, allowRetry: false);
        return;
      }

      // Poll window ended before the backend reported done (slow provider).
      // Show whatever arrived. A timeout is NOT a real "no results" answer:
      // don't cache the partial as final (which would make the next attempt
      // return instantly with nothing).
      emit(state.copyWith(
        results: lastItems,
        loading: false,
        hasSearched: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: e.toString(),
      ));
    }
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
