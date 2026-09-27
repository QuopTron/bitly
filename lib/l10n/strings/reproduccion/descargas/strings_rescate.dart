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
  final String relayLabel;
  final String relayAyuda;
  final String avanzadoTitulo;
  final String avanzadoAyuda;
  final String instanciaLabel;
  final String instanciaHint;
  final String tokenLabel;
  final String tokenHint;
  final String cobaltAyuda;
  final String proxyLabel;
  final String proxyHint;
  final String proxyAyuda;
  final String proxyInvalido;
  final String urlInvalida;
  final String guardar;
  final String guardado;

  const StringsRescate({
    required this.titulo,
    required this.ayuda,
    required this.sitiosLabel,
    required this.sitiosAyuda,
    required this.relayLabel,
    required this.relayAyuda,
    required this.avanzadoTitulo,
    required this.avanzadoAyuda,
    required this.instanciaLabel,
    required this.instanciaHint,
    required this.tokenLabel,
    required this.tokenHint,
    required this.cobaltAyuda,
    required this.proxyLabel,
    required this.proxyHint,
    required this.proxyAyuda,
    required this.proxyInvalido,
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
    relayLabel: 'Relay sin pérdida (Stash)',
    relayAyuda:
        'Un relay público de otro proyecto firma contra sus cuentas de Qobuz '
        'y entrega el FLAC directo del CDN, sin cuenta tuya. Es infraestructura '
        'ajena y tiene cupos: si falla, el rescate sigue por los demás caminos. '
        'Apagado, no se le hace ni una petición.',
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
    proxyLabel: 'Proxy del rescate (opcional)',
    proxyHint: 'socks5://127.0.0.1:1080',
    proxyAyuda:
        'Sale por acá TODO el rescate: espejos, sitios, canal sin pérdida y '
        'claves firmadas. Sirve cuando un sitio te bloquea por región. Sin '
        'dirección, todo sale directo como hasta ahora.',
    proxyInvalido:
        'Usa http://, https://, socks5:// o socks5h:// con host y puerto',
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
    relayLabel: 'Lossless relay (Stash)',
    relayAyuda:
        'A public relay from another project signs against its own Qobuz '
        'accounts and hands over the FLAC straight from the CDN, with no '
        'account of yours. It is third-party infrastructure with quotas: if it '
        'fails, the rescue carries on through the other paths. Turned off, not '
        'a single request goes to it.',
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
    proxyLabel: 'Rescue proxy (optional)',
    proxyHint: 'socks5://127.0.0.1:1080',
    proxyAyuda:
        'ALL of the rescue goes through it: mirrors, sites, the lossless '
        'channel and signed keys. Useful when a site blocks you by region. '
        'Without an address everything goes direct, as before.',
    proxyInvalido:
        'Use http://, https://, socks5:// or socks5h:// with host and port',
    urlInvalida: 'Paste the full address, starting with https://',
    guardar: 'Save',
    guardado: 'Saved',
  );
}
