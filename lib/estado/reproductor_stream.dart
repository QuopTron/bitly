// ─────────────────────────────────────────────────────────────
// reproductor_stream.dart — PART de cubit_reproductor.dart: helpers
// de resolución de stream: decode de resultados RPC, detección de
// red wifi (calidad acotada en datos móviles), reuso de preloads de
// fuentes de stream completo, clave de caché con calidad y
// expiración de URLs cacheadas. Los abstractos _getStreamCacheDir y
// _guardarCachePersistente los implementan partes superiores
// (archivos_temp y init).
// Se conecta con: reproductor_estado_cache.dart (misma library).
// Parte del flujo: reproducción (resolver URL de streaming).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Helpers de stream. Mixin aplicado en CubitReproductor.
mixin ReproductorStream on ReproductorEstadoCache {
  /// Directorio del caché de stream — implementación concreta en
  /// ReproductorArchivosTemp (arriba en la cadena); declaración para el
  /// decrypt.
  Future<Directory> _getStreamCacheDir();

  /// Decodifica un resultado RPC del backend a un Map cuando es posible.
  /// Ambos backends devuelven la respuesta Go como JSON *string* (Android la
  /// devuelve cruda del MethodChannel, desktop devuelve `result` que es a su
  /// vez un string JSON-encoded). Sin decodificar, `result['audioUrl']`
  /// falla silenciosamente y el playback reporta "Could not resolve URI".
  Map<String, dynamic>? _decodeRpcResult(dynamic resultado) {
    if (resultado == null) return null;
    if (resultado is Map) {
      return Map<String, dynamic>.from(resultado);
    }
    if (resultado is String && resultado.isNotEmpty) {
      try {
        final decodificado = jsonDecode(resultado);
        return decodificado is Map ? Map<String, dynamic>.from(decodificado) : null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// True en wifi/ethernet; false en datos móviles. En móvil la calidad de
  /// stream se acota para ahorrar MB; wifi mantiene la elección completa.
  static int _cacheDesde = 0;
  static bool _ultimoEsWifi = true;
  Future<bool> _esRedWifi() async {
    try {
      if (DateTime.now().millisecondsSinceEpoch - _cacheDesde > 30000) {
        final conexiones = await Connectivity().checkConnectivity();
        _ultimoEsWifi = conexiones.any(
          (c) =>
              c == ConnectivityResult.wifi || c == ConnectivityResult.ethernet,
        );
        _cacheDesde = DateTime.now().millisecondsSinceEpoch;
      }
      return _ultimoEsWifi;
    } catch (_) {
      return true;
    }
  }

  /// Elige la calidad enviada al backend para streaming. En datos móviles,
  /// lossless → 320kbps para mantener el stream liviano; wifi mantiene la
  /// calidad elegida.
  Future<String> _calidadStreamEfectiva(String solicitada) async {
    final esWifi = await _esRedWifi();
    if (esWifi) return solicitada;
    final q = solicitada.toLowerCase();
    if (q == 'flac' || q == 'hi_res' || q == 'lossless' || q == 'flac_high') {
      return 'high';
    }
    return solicitada;
  }

  /// Si una URL resuelta por preload puede reusarse por un tap real: debe ser
  /// un stream http(s) directo de una fuente de stream completo.
  bool _puedeReusarPreloadDirecto(ItemFeed track, String url) {
    final src = (track.source ?? '').toLowerCase();
    if (!_fuentesStreamCompleto.contains(src)) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Clave de caché de stream: incluye la calidad actual para que un cambio
  /// de calidad nunca sirva una URL resuelta en otro tier.
  String _claveCacheStream(String idNorm) => '$idNorm|$_calidadAudio';

  /// Computa la expiración de una URL de stream: archivos locales nunca
  /// expiran; URLs googlevideo de YouTube llevan un `expire` exacto en
  /// unix-seconds; todo lo demás recibe un TTL conservador por defecto.
  DateTime? _expiryParaUrl(String url) {
    if (url.startsWith('file://')) return null;
    final m = RegExp(r'[?&]expire=(\d{10})').firstMatch(url);
    if (m != null) {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(m.group(1)!) * 1000);
    }
    return DateTime.now().add(_ttlStreamDefault);
  }

  /// Una URL cacheada dentro de [_margenSeguridadUrl] de su expiración es
  /// vieja — re-resolver.
  bool _urlStreamVieja(_StreamCacheado? cacheado) {
    final exp = cacheado?.expiraEn;
    if (exp == null) return false;
    return DateTime.now().add(_margenSeguridadUrl).isAfter(exp);
  }
}