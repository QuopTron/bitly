// ─────────────────────────────────────────────────────────────
// ajustes_pool_qobuz.dart — Ajustes y ESTADO del POOL de sesiones de Qobuz.
//
// Qué resuelve: el pool de Qobuz (una URL propia o el /pool del Worker de
// fábrica) puede quedar vacío, y hasta ahora eso apagaba la descarga directa
// en silencio. El backend sabe POR QUÉ quedó vacío (endpoint caído vs. sin
// tokens vivos) y lo publica en la acción `estadoPool` de qobuz-web; acá vive
// la traducción de esa respuesta a un estado que la UI pueda pintar, y la
// validación de la URL que el usuario pega.
//
// Los estados son los mismos que define Go (ver
// sessionpool/qobuz_diagnostico.go): si se agrega uno allá, se agrega acá.
//
// Se conecta con: settings_sheet_download_pool_qobuz (la tarjeta de Ajustes) +
// servicio_credenciales_proveedor (el push) + el backend (estadoPool).
// Parte del flujo: Ajustes → Descargas → sesiones de Qobuz.
// ─────────────────────────────────────────────────────────────

/// Ajustes y estado del pool de sesiones de Qobuz.
class AjustesPoolQobuz {
  /// El id de la extensión cuyo pool se informa.
  static const String id = 'qobuz-web';

  /// La clave del ajuste con la URL (o URLs) del pool.
  static const String claveUrls = 'qobuzPoolUrls';

  /// La acción del backend que devuelve el informe del pool.
  static const String accionEstado = 'estadoPool';

  // Estados posibles (espejo de sessionpool/qobuz_diagnostico.go).
  /// El pool tiene credenciales vivas.
  static const String estadoOk = 'ok';
  /// Hay fuentes, pero ninguna respondió (endpoint caído).
  static const String estadoFuenteCaida = 'fuente_caida';
  /// Las fuentes respondieron, pero sin tokens usables.
  static const String estadoSinTokens = 'sin_tokens';
  /// No hay ninguna URL configurada (ni propia ni de fábrica).
  static const String estadoSinFuentes = 'sin_fuentes';

  /// Estados LOCALES de la UI (no vienen del backend).
  /// Todavía no se consultó.
  static const String estadoConsultando = 'consultando';
  /// La consulta al backend falló.
  static const String estadoError = 'error';

  /// La URL del pool sin espacios.
  static String normalizarUrl(String url) => url.trim();

  /// ¿Es una URL http(s) con host? Una URL a medio pegar no se guarda: el
  /// backend la bajaría y fallaría en cada arranque.
  static bool urlValida(String url) {
    final limpia = normalizarUrl(url);
    if (limpia.isEmpty) return false;
    final uri = Uri.tryParse(limpia);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  /// El `result` del informe dentro de la respuesta de la acción, o null si la
  /// respuesta no trae uno válido.
  static Map<String, dynamic>? resultadoDeRespuesta(
    Map<String, dynamic>? respuesta,
  ) {
    if (respuesta == null || respuesta['ok'] != true) return null;
    final result = respuesta['result'];
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  /// El estado a pintar a partir de la respuesta de la acción `estadoPool`.
  /// Cualquier respuesta inválida cae en [estadoError] (nunca miente con un
  /// "ok" cuando no se pudo confirmar).
  static String estadoDeRespuesta(Map<String, dynamic>? respuesta) {
    final result = resultadoDeRespuesta(respuesta);
    if (result == null) return estadoError;
    final estado = result['estado'];
    if (estado is String && estadosValidos.contains(estado)) return estado;
    return estadoError;
  }

  /// Los estados que el backend puede devolver.
  static const Set<String> estadosValidos = {
    estadoOk,
    estadoFuenteCaida,
    estadoSinTokens,
    estadoSinFuentes,
  };

  /// El detalle que mandó el backend (texto ya en castellano), si vino.
  static String detalleDeRespuesta(Map<String, dynamic>? respuesta) {
    final result = resultadoDeRespuesta(respuesta);
    final detalle = result?['detalle'];
    return detalle is String ? detalle : '';
  }
}
