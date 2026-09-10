// ─────────────────────────────────────────────────────────────
// contrato_backend.dart — Interfaz BackendService: TODOS los RPCs
// contra el backend Go. Las implementaciones concretas
// (Android/iOS/Desktop) la cumplen vía mixins por dominio.
// Se conecta con: backend_go/mixins (implementaciones por dominio).
// Parte del flujo: TODO — es la única puerta de Flutter hacia Go.
// ─────────────────────────────────────────────────────────────

import '../modelos/config_busqueda_fuente.dart';
import '../modelos/item_feed.dart';
import '../modelos/seccion_feed.dart';
import 'estado_sesion_firmada.dart';
import 'resultados_busqueda_stream.dart';

/// Contrato de comunicación con el backend Go.
abstract class BackendService {
  // ── Core ──────────────────────────────────────────────
  Future<bool> healthCheck();
  Future<List<SeccionFeed>> getHomeFeed({String locale = 'en'});

  /// Lista todas las fuentes/proveedores disponibles.
  Future<List<String>> getSources();

  // ── Búsqueda ──────────────────────────────────────────
  Future<List<ItemFeed>> search({required String query, String source = '', String type = '', int limit = 20});

  /// Inicia búsqueda en streaming (proveedores en paralelo, resultados
  /// acumulados). Devuelve el ID de generación de la sesión.
  Future<int> searchStreaming({required String query, String source = '', String type = '', int limit = 20});

  /// Resultados acumulados de la sesión de búsqueda actual.
  Future<ResultadosBusquedaStream> getSearchStreamResults();

  /// Burbujas de categoría del manifest de cada fuente (searchBehavior).
  Future<List<ConfigBusquedaFuente>> getSearchConfig();

  // ── Acciones (likes, descargas) ───────────────────────
  Future<void> likeItem(String itemId, bool liked);
  Future<void> downloadItem(String itemId);
  Future<String> getAllDownloadProgress();

  /// Elimina una entrada de progreso del tracker de Go para que deje de
  /// reportarse (tras borrar una descarga del cliente).
  Future<void> cancelDownload(String itemId);

  /// Despacha una descarga (audio/video/letras) a Go. JSON resultante o null.
  Future<dynamic> downloadByStrategy(String json);
  Future<void> initItemProgress(String itemId, {String trackName = '', String artistName = ''});
  Future<String> estimateTrackFileSize(int durationMs, String quality);

  // ── Detalles (extensiones) ────────────────────────────
  /// Detalle desde API de extensión (no DB local). '{}' si no existe.
  Future<String> fetchAlbumDetail(String albumId, String source);
  Future<String> fetchPlaylistDetail(String collectionId, String source);
  Future<String> fetchArtistDetail(String artistId, String source);

  // ── Caché de carátulas ────────────────────────────────
  Future<String?> saveCover(String coverUrl);
  Future<void> deleteCover(String coverUrl);

  /// Ruta local de una carátula por ISRC o track+artista.
  Future<String?> getCoverPathForTrack({required String trackId, String? isrc, String? trackName, String? artistName, String? coverUrl});

  // ── Caché de streaming ────────────────────────────────
  Future<Map<String, dynamic>> getStreamCacheStats();
  Future<Map<String, dynamic>> clearStreamCache();
  Future<Map<String, dynamic>> setStreamCacheMaxMb(int mb);

  // ── Sincronización de config (Flutter → Go) ───────────
  Future<void> syncDownloadDir(String path);
  Future<void> syncBackendConfig({String? mode, int? streamCacheMaxMb, int? downloadConcurrency, int? streamChunkSize});
  Future<void> syncDownloadProviderPriority(List<String> providers);

  // ── Premium ───────────────────────────────────────────
  /// null = válido, String = mensaje de error.
  Future<String?> validatePremiumCode(String code);
  Future<void> setPremiumGithubToken(String token);

  /// Sincroniza el estado premium (drift) hacia Go para que el gate de
  /// descargas respete códigos ya activados tras un reinicio.
  Future<void> syncPremiumStatus({required bool isPremium, required String tier, int? expiresAt});

  // ── Sesiones firmadas ─────────────────────────────────
  Future<String> getPendingVerificationUrl(String extensionId);
  Future<bool> completeSignedSessionGrant(String extensionId, String grantCode);
  Future<EstadoSesionFirmada> getSignedSessionStatus(String extensionId);
  Future<String> triggerExtensionVerification(String extensionId);

  /// Pasada de provisionamiento al arrancar: reporta estado por fuente,
  /// refresca en silencio las que expiran, bootstrapa las que faltan.
  Future<Map<String, dynamic>> provisionSignedSessions();

  /// Keepalive en segundo plano: refresca en silencio sesiones por expirar.
  Future<Map<String, dynamic>> keepAliveSignedSessions();

  // ── Acciones de extensión (botones de Ajustes) ────────
  Future<Map<String, dynamic>> invokeExtensionAction(String provider, String action, {List<dynamic> args = const []});

  // ── RPC genérico ──────────────────────────────────────
  /// Ejecuta un método RPC arbitrario. [timeout] sobreescribe el timeout
  /// defensivo por llamada (las descargas de track pasan uno más largo).
  Future<dynamic> rpcCall(String method, [Map<String, dynamic>? params, Duration? timeout]);

  // ── Reset / Editor tags / Salud ───────────────────────
  /// Borra TODOS los datos (DB, ajustes, favoritos, descargas, librería).
  Future<bool> resetAllData();
  Future<String> readFileMetadata(String filePath);
  Future<bool> writeFileMetadata(String filePath, Map<String, String> meta);

  /// Estado de cooldown de todos los proveedores como JSON string.
  Future<String> getProviderHealthStatus();
}