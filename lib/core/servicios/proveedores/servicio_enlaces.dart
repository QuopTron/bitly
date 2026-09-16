// ─────────────────────────────────────────────────────────────
// servicio_enlaces.dart — Resolución de enlaces de música.
//
// Qué hace: toma los enlaces que llegan por share intent (compartir desde
// Spotify/YouTube y elegir Bitly) o que el usuario pega, los manda a resolver
// a Go y emite el ítem listo para reproducir. Antes esos enlaces se capturaban
// y se descartaban: compartir una canción no hacía nada.
//
// Se conecta con: servicio_share_intent (URLs entrantes) +
// backend_go.resolveUrl (quién elige la extensión y resuelve) + la UI, que
// escucha [resultados].
//
// Parte del flujo: enlace entrante/pegado → item reproducible → cola.
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import '../../backend_go/nucleo/contrato_backend.dart';
import '../../../app/inyeccion.dart' as di;
import '../../modelos/resultado_enlace.dart';
import '../../plataforma/sistema/servicio_deep_link.dart';
import '../../plataforma/sistema/servicio_share_intent.dart';
import '../compartir/servicio_compartir.dart';

/// Resuelve enlaces de Spotify/YouTube/Deezer... a un ítem reproducible.
class ServicioEnlaces {
  static final ServicioEnlaces _instancia = ServicioEnlaces._();
  static ServicioEnlaces get instance => _instancia;

  ServicioEnlaces._();

  final _controller = StreamController<ResultadoEnlace>.broadcast();

  /// Enlaces ya resueltos y listos para reproducir.
  Stream<ResultadoEnlace> get resultados => _controller.stream;

  BackendService get _backend => di.sl<BackendService>();

  /// Escucha los enlaces que llegan compartidos a la app.
  void initialize() {
    ServicioShareIntent.instance.urlsCompartidas.listen(_procesarCompartido);
  }

  /// Texto compartido → enlace de Bitly (se muestra la carta "te
  /// compartieron") o primer enlace de otra fuente → resolver → emitir.
  Future<void> _procesarCompartido(String texto) async {
    final datos = ServicioCompartir.instance.leerEnlace(texto.trim());
    if (datos != null) {
      ServicioDeepLink.instance.emitir(DatosDeepLink(
        type: datos.tipo,
        id: datos.isrc,
        query: datos.nombre,
        compartido: datos,
      ));
      return;
    }
    final enlace = enlaceEnTexto(texto);
    if (enlace == null) return;
    final resuelto = await resolver(enlace);
    if (resuelto != null) _controller.add(resuelto);
  }

  /// Resuelve un enlace y devuelve el ítem (null si ninguna fuente pudo).
  Future<ResultadoEnlace?> resolver(String url) => _backend.resolveUrl(url);

  /// Detecta un enlace de música dentro de un texto (compartido o pegado).
  /// Acepta URLs http(s) y esquemas tipo "spotify:track:...".
  static String? enlaceEnTexto(String texto) {
    final t = texto.trim();
    if (t.isEmpty) return null;

    // Enlace suelto sin espacios: se resuelve tal cual.
    if (!t.contains(' ') && _pareceEnlaceMusical(t)) return t;

    // Esquema con dos puntos ("spotify:track:x", "tidal:track:y").
    final esquema = RegExp(
      r'(spotify|tidal|deezer|applemusic):[^\s]+',
      caseSensitive: false,
    ).firstMatch(t);
    if (esquema != null) return esquema.group(0);

    // URL de música dentro del texto.
    final url = RegExp(
      r'https?://[^\s<>"{}|\\^`\[\]]+',
      caseSensitive: false,
    ).firstMatch(t);
    if (url != null && _pareceEnlaceMusical(url.group(0)!)) {
      return url.group(0);
    }
    return null;
  }

  /// Reconoce los hosts que alguna extensión declara en su urlHandler.
  static bool _pareceEnlaceMusical(String valor) {
    final v = valor.toLowerCase();
    const hosts = [
      'spotify.com',
      'spotify:',
      'youtube.com',
      'youtu.be',
      'deezer.com',
      'deezer.page.link',
      'music.apple.com',
      'tidal.com',
      'tidal:',
      'soundcloud.com',
      'qobuz.com',
      'music.amazon',
      'pandora.com',
    ];
    return hosts.any(v.contains);
  }

  void dispose() {
    _controller.close();
  }
}
