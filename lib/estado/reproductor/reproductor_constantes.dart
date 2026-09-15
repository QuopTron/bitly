// ─────────────────────────────────────────────────────────────
// reproductor_constantes.dart — PART de cubit_reproductor.dart:
// clases y constantes compartidas del player — la entrada de caché de
// stream resuelto, los márgenes de seguridad del caché, la
// configuración del crossfade y el set de fuentes que sirven audio
// COMPLETO (un preload de una de ellas es un track entero).
// Se conecta con: cubit_reproductor.dart (misma library).
// Parte del flujo: reproducción (estado compartido del player).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Stream URL resuelta, guardada en el caché en memoria/persistente.
class _StreamCacheado {
  final String url;
  final bool conRespaldo;

  /// Expiración propia de la URL (las URLs de YouTube llevan `expire`), o
  /// null para archivos locales / desconocidos — ver [_expiryForUrl].
  final DateTime? expiraEn;

  const _StreamCacheado(this.url, this.conRespaldo, this.expiraEn);
}

/// URLs de stream cuya vida restante está dentro de esta ventana se tratan
/// como viejas y se re-resuelven (mismo margen de 60s de ArchiveTune).
const _margenSeguridadUrl = Duration(seconds: 60);

/// Vida útil conservadora para streams http(s) directos sin expiración
/// explícita (CDN de soundcloud/deezer...). Las de YouTube llevan su propio
/// `expire` que [_expiryForUrl] parsea en su lugar.
const _ttlStreamDefault = Duration(hours: 6);

/// Crossfade: cuando es true, el listener de posición hace fade-out cerca del
/// final del track y el handler de completado hace fade-in del siguiente.
const _crossfadeHabilitado = true;

/// Ventana corta a propósito: el fade-out empieza 1.5s antes del final y dura
/// 0.8s, así el silencio entre canciones queda en ~0.7s máximo. Antes era
/// 5s/3s → el volumen llegaba a 0 con 2s de canción restante y el usuario
/// percibía un "muteo" de 2 segundos entre canciones.
const _duracionCrossfade = Duration(milliseconds: 800);
const _crossfadeInicioAntesDelFinal = Duration(milliseconds: 1500);

/// Fuentes de stream completo (el backend sirve audio COMPLETO): un preload
/// de una de estas es un track entero, un tap puede reusarlo sin re-resolver.
const _fuentesStreamCompleto = {
  'ytmusic-spotiflac',
  'youtube',
  'soundcloud',
  'deezer',
  'qobuz-web',
  'tidal-web',
  'ytmusic',
};
