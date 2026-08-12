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

/// Fuentes cuyas BÚSQUEDAS requieren la sesión firmada para devolver
/// resultados: qobuz-web da 403 y amazon devuelve 0 sin verificar. Deezer y
/// pandora buscan de forma anónima — un resultado vacío ahí casi siempre es
/// rate-limit (429) o "sin resultados", NUNCA un problema de sesión, así que
/// abrir el modal de Cloudflare desde la búsqueda es inútil y molesto.
final _verifyOnEmptySources = <String>{'qobuz-web', 'amazon'};

/// Resultado de intentar verificar una fuente con sesión firmada.
enum _VerifyOutcome { verified, notNeeded, failed }

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final BackendService _backend;
  final SearchCache _searchCache;

  /// Cooldown per source so a signed-session search source (qobuz-web,
  /// amazon) that returns empty — e.g. a temporary provider 429, not a missing
  /// session — doesn't re-open the Cloudflare verification modal on every
  /// keystroke. After a verification attempt, further empty searches just show
  /// "no results" for a while.
  final Map<String, DateTime> _lastVerifyAttempt = {};
  static const _verifyCooldown = Duration(minutes: 5);

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

        // A search-enabled signed-session source (qobuz-web, amazon) that
        // returns empty. Only open the Cloudflare modal when the session is
        // actually missing/expired — an empty result for an already-verified
        // source usually means "no results" or a temporary provider 429, and
        // popping the modal on every keystroke was spamming the user. Deezer
        // and pandora search anonymously, so their empty results never open it.
        if (results.isEmpty && _verifyOnEmptySources.contains(event.source)) {
          final last = _lastVerifyAttempt[event.source];
          final inCooldown = last != null &&
              DateTime.now().difference(last) < _verifyCooldown;
          final sessionUsable = await _sourceSessionUsable(event.source);
          if (!inCooldown && !sessionUsable) {
            // Session is genuinely missing/expired: open the modal once.
            _lastVerifyAttempt[event.source] = DateTime.now();
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
          // Session already usable (or we just tried): empty search is a real
          // empty result, not a verification problem — show it normally.
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

  /// Reports whether a signed-session source already has a usable session, so
  /// empty search results aren't mistaken for a missing verification (which
  /// would open the Cloudflare modal repeatedly). Mirrors PlayerCubit's
  /// pre-play gate.
  Future<bool> _sourceSessionUsable(String source) async {
    try {
      final status = await _backend.getSignedSessionStatus(source);
      return status.authenticated;
    } catch (_) {
      // Can't ask — don't block on verification.
      return true;
    }
  }

  /// Ejecuta el flujo completo de verificación (WebView → grant → complete)
  /// para una fuente con sesión firmada.
  Future<_VerifyOutcome> _verifySource(String source) async {
    try {
      // Solo reportamos lo que el backend ya tiene pendiente. Nunca forzamos
      // triggerExtensionVerification desde la búsqueda: en Go es idéntico a
      // getPendingVerificationUrl (ambos bootstrapean y devuelven un challenge
      // URL cuando la sesión no está verificada), así que forzarlo re-abría el
      // modal para fuentes rate-limitadas en cada resultado vacío.
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


