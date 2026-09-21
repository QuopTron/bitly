// ─────────────────────────────────────────────────────────────
// strings_reproductor.dart — Textos del reproductor: estado de la
// cola, letras karaoke y video visualizador. Español primario,
// inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `reproductor`)
// y modal_cola_* / reproductor_pagina_*.
// Parte del flujo: reproductor (cola, letras, video).
// ─────────────────────────────────────────────────────────────

class StringsReproductor {
  final String colaVacia;
  final String colaEmpieza;
  final String sinTrack;
  final String sinLetras;
  final String videoSinConexion;
  final String videoNoObtenido;
  final String videoNoReproducido;
  final String sesionNoVerificada;
  final String proveedorSaturado;
  final String sinConexion;
  final String sinStream;

  /// Etiqueta del control de volumen. Solo se usa en PC y TV: en el celular
  /// el volumen lo manejan las teclas del aparato.
  final String volumen;
  final String _colaTitulo;
  final String _colaProximos;
  final String _sesionDe;

  const StringsReproductor({
    required this.colaVacia,
    required this.colaEmpieza,
    required this.sinTrack,
    required this.sinLetras,
    required this.videoSinConexion,
    required this.videoNoObtenido,
    required this.videoNoReproducido,
    required this.sesionNoVerificada,
    required this.proveedorSaturado,
    required this.sinConexion,
    required this.sinStream,
    required this.volumen,
    required String colaTitulo,
    required String colaProximos,
    required String sesionDe,
  }) : _colaTitulo = colaTitulo,
       _colaProximos = colaProximos,
       _sesionDe = sesionDe;

  /// Aviso con el nombre de la fuente que exige verificación.
  String sesionDe(String nombre) => _sesionDe.replaceFirst('{n}', nombre);

  /// Título de la cola con la cantidad total.
  String colaTitulo(int total) => _colaTitulo.replaceFirst('{n}', '$total');

  /// Cuántas canciones quedan por delante.
  String colaProximos(int n) => _colaProximos.replaceFirst('{n}', '$n');

  static const es = StringsReproductor(
    colaVacia: 'Cola vacía',
    colaEmpieza: 'Reproduce una canción para empezar',
    sinTrack: 'No hay ninguna canción seleccionada',
    sinLetras: 'Sin letras para esta canción',
    videoSinConexion: 'Sin conexión y sin video descargado',
    videoNoObtenido: 'No se pudo obtener el video visualizador',
    videoNoReproducido: 'No se pudo reproducir el video visualizador',
    sesionNoVerificada:
        'Sesión no verificada — completa la verificación para reproducir '
        'esta canción.',
    proveedorSaturado:
        'Proveedor temporalmente saturado (429) — inténtalo de nuevo en unos '
        'segundos.',
    sinConexion:
        'Sin conexión a internet — descarga esta canción para reproducirla '
        'sin red.',
    sinStream: 'No se pudo obtener un stream original para esta canción.',
    volumen: 'Volumen',
    colaTitulo: 'Cola ({n})',
    colaProximos: '{n} próximos',
    sesionDe:
        'Sesión de {n} no verificada — completa la verificación para '
        'reproducir esta canción.',
  );

  static const en = StringsReproductor(
    colaVacia: 'Empty queue',
    colaEmpieza: 'Play a song to start',
    sinTrack: 'No track selected',
    sinLetras: 'No lyrics for this song',
    videoSinConexion: 'No connection and no downloaded video',
    videoNoObtenido: "Couldn't get the visualizer video",
    videoNoReproducido: "Couldn't play the visualizer video",
    sesionNoVerificada:
        'Session not verified — complete the verification to play this song.',
    proveedorSaturado:
        'Provider temporarily overloaded (429) — try again in a few seconds.',
    sinConexion:
        "No internet connection — download this song to play it offline.",
    sinStream: "Couldn't get an original stream for this song.",
    volumen: 'Volume',
    colaTitulo: 'Queue ({n})',
    colaProximos: '{n} upcoming',
    sesionDe:
        'Session for {n} not verified — complete the verification to play '
        'this song.',
  );
}
