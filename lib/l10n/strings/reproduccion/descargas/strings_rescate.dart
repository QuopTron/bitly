// ─────────────────────────────────────────────────────────────
// strings_rescate.dart — Textos de la tarjeta "Rescate sin pérdida" de
// Ajustes → Descargas: el switch de sitios raspables y la instancia propia de
// cobalt (respaldo de descarga cuando yt-dlp falla).
// Español primario, inglés secundario (se elige por el locale).
// Se conecta con: app_localizations.dart (lo expone como `rescate`) y
// features/ajustes/sheet/settings_sheet_download_rescate.dart.
// Parte del flujo: Ajustes → Descargas → rescate.
// ─────────────────────────────────────────────────────────────

class StringsRescate {
  final String titulo;
  final String ayuda;
  final String sitiosLabel;
  final String sitiosAyuda;
  final String avanzadoTitulo;
  final String avanzadoAyuda;
  final String instanciaLabel;
  final String instanciaHint;
  final String tokenLabel;
  final String tokenHint;
  final String cobaltAyuda;
  final String urlInvalida;
  final String guardar;
  final String guardado;

  const StringsRescate({
    required this.titulo,
    required this.ayuda,
    required this.sitiosLabel,
    required this.sitiosAyuda,
    required this.avanzadoTitulo,
    required this.avanzadoAyuda,
    required this.instanciaLabel,
    required this.instanciaHint,
    required this.tokenLabel,
    required this.tokenHint,
    required this.cobaltAyuda,
    required this.urlInvalida,
    required this.guardar,
    required this.guardado,
  });

  static const es = StringsRescate(
    titulo: 'Rescate sin pérdida',
    ayuda:
        'Cuando una canción no baja del catálogo, la app la busca en sitios '
        'públicos que entregan el FLAC real. Se usan solo para descargar: el '
        'resultado se verifica contra el título, el artista y la duración.',
    sitiosLabel: 'Sitios de respaldo (FLAC)',
    sitiosAyuda:
        'Apagados, el rescate queda solo con los espejos y las claves '
        'firmadas. No afecta a las canciones que ya suenan.',
    avanzadoTitulo: 'Avanzado',
    avanzadoAyuda:
        'Instancia propia de cobalt: una segunda vía de descarga por si '
        'YouTube bloquea la normal.',
    instanciaLabel: 'Instancia de cobalt',
    instanciaHint: 'https://mi-instancia.ejemplo',
    tokenLabel: 'Clave de la instancia',
    tokenHint: 'Solo si tu instancia la pide',
    cobaltAyuda:
        'Cobalt no entrega FLAC: es audio de YouTube como el que ya se baja, '
        'así que se usa solo como respaldo. Sin URL, no se usa ni abre red.',
    urlInvalida: 'Pega la dirección completa, empezando con https://',
    guardar: 'Guardar',
    guardado: 'Guardado',
  );

  static const en = StringsRescate(
    titulo: 'Lossless rescue',
    ayuda:
        'When a song cannot be downloaded from the catalog, the app looks for '
        'it on public sites that hand over the real FLAC. They are used for '
        'downloads only: the result is checked against title, artist and '
        'duration.',
    sitiosLabel: 'Backup sites (FLAC)',
    sitiosAyuda:
        'Turned off, the rescue falls back to mirrors and signed keys only. '
        'It does not affect songs that already play.',
    avanzadoTitulo: 'Advanced',
    avanzadoAyuda:
        'Your own cobalt instance: a second download path in case YouTube '
        'blocks the normal one.',
    instanciaLabel: 'Cobalt instance',
    instanciaHint: 'https://my-instance.example',
    tokenLabel: 'Instance key',
    tokenHint: 'Only if your instance asks for one',
    cobaltAyuda:
        'Cobalt does not deliver FLAC: it is YouTube audio like the usual '
        'download, so it is only a backup. Without a URL it is unused and '
        'opens no network.',
    urlInvalida: 'Paste the full address, starting with https://',
    guardar: 'Save',
    guardado: 'Saved',
  );
}
