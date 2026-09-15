// ─────────────────────────────────────────────────────────────
// strings_splash.dart — Strings de la pantalla de splash y de los paneles de error
// (backend caído, sin conexión, versión web).
// Se conecta con: app_localizations.dart (los consume).
// Parte del flujo: splash / arranque.
// ─────────────────────────────────────────────────────────────

class StringsSplash {
  final String retry;
  final String backendNotResponding;
  final String connectionError;

  /// Título del panel de error propio de la versión WEB.
  final String webNeedsServerTitle;

  /// Explicación en lenguaje llano de por qué la web necesita el servidor
  /// (sin tecnicismos: habla de "los servicios de música bloquean…").
  final String webNeedsServerBody;

  /// Aviso para quien NO instaló el servidor: esta web no es para él y
  /// conviene que use la app nativa.
  final String webUseAppHint;

  /// Etiqueta del botón que lleva a la página de descargas de la app nativa.
  final String webDownloadApp;

  const StringsSplash({
    required this.retry,
    required this.backendNotResponding,
    required this.connectionError,
    required this.webNeedsServerTitle,
    required this.webNeedsServerBody,
    required this.webUseAppHint,
    required this.webDownloadApp,
  });

  static const es = StringsSplash(
    retry: 'Reintentar',
    backendNotResponding: 'Backend no responde',
    connectionError: 'Error de conexión',
    webNeedsServerTitle: 'Esta versión web necesita el servidor de Bitly',
    webNeedsServerBody:
        'El navegador no puede buscar la música por sí solo: los servicios de '
        'música bloquean ese tipo de pedido desde una página web. Por eso la '
        'web funciona con el servidor de Bitly encendido en tu computadora.',
    webUseAppHint:
        'Si no instalaste el servidor, esta web todavía no es para vos. Usá la '
        'app:',
    webDownloadApp: 'Descargar la app',
  );

  static const en = StringsSplash(
    retry: 'Retry',
    backendNotResponding: 'Backend not responding',
    connectionError: 'Connection error',
    webNeedsServerTitle: 'This web version needs the Bitly server',
    webNeedsServerBody:
        "The browser can't fetch music on its own: music services block that "
        'kind of request from a web page. That is why the web version runs '
        'with the Bitly server turned on, on your computer.',
    webUseAppHint:
        "Haven't installed the server? Then this web version is not for you "
        'yet. Use the app:',
    webDownloadApp: 'Download the app',
  );
}
