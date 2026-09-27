// ─────────────────────────────────────────────────────────────
// strings_pool_qobuz.dart — Textos de la tarjeta "Sesiones de Qobuz" de
// Ajustes → Descargas: el estado del pool (vivo / caído / sin tokens) y la URL
// de la fuente que lo sirve.
//
// Español primario, inglés secundario (se elige por el locale).
// Se conecta con: app_localizations.dart (lo expone como `poolQobuz`) y
// features/ajustes/sheet/descargas/qobuz/settings_sheet_download_pool_qobuz.dart.
// Parte del flujo: Ajustes → Descargas → sesiones de Qobuz.
// ─────────────────────────────────────────────────────────────

class StringsPoolQobuz {
  final String titulo;
  final String ayuda;
  final String estadoTitulo;
  final String estadoOk;
  final String estadoFuenteCaida;
  final String estadoSinTokens;
  final String estadoSinFuentes;
  final String estadoConsultando;
  final String estadoError;
  final String detalleOk;
  final String detalleFuenteCaida;
  final String detalleSinTokens;
  final String detalleSinFuentes;
  final String detalleError;
  final String urlLabel;
  final String urlHint;
  final String urlAyuda;
  final String urlInvalida;
  final String guardar;
  final String guardado;
  final String revisar;
  final String revisando;

  const StringsPoolQobuz({
    required this.titulo,
    required this.ayuda,
    required this.estadoTitulo,
    required this.estadoOk,
    required this.estadoFuenteCaida,
    required this.estadoSinTokens,
    required this.estadoSinFuentes,
    required this.estadoConsultando,
    required this.estadoError,
    required this.detalleOk,
    required this.detalleFuenteCaida,
    required this.detalleSinTokens,
    required this.detalleSinFuentes,
    required this.detalleError,
    required this.urlLabel,
    required this.urlHint,
    required this.urlAyuda,
    required this.urlInvalida,
    required this.guardar,
    required this.guardado,
    required this.revisar,
    required this.revisando,
  });

  /// El título del estado, en corto (para el chip de color).
  String etiquetaEstado(String estado) {
    switch (estado) {
      case 'ok':
        return estadoOk;
      case 'fuente_caida':
        return estadoFuenteCaida;
      case 'sin_tokens':
        return estadoSinTokens;
      case 'sin_fuentes':
        return estadoSinFuentes;
      case 'consultando':
        return estadoConsultando;
      default:
        return estadoError;
    }
  }

  /// La explicación del estado. Es un RESPALDO: si el backend mandó su propio
  /// `detalle`, se usa ese (ya viene en castellano y con el matiz real).
  String detalleEstado(String estado) {
    switch (estado) {
      case 'ok':
        return detalleOk;
      case 'fuente_caida':
        return detalleFuenteCaida;
      case 'sin_tokens':
        return detalleSinTokens;
      case 'sin_fuentes':
        return detalleSinFuentes;
      case 'consultando':
        return estadoConsultando;
      default:
        return detalleError;
    }
  }

  static const es = StringsPoolQobuz(
    titulo: 'Sesiones de Qobuz',
    ayuda:
        'Qobuz entrega FLAC solo con una cuenta con suscripción. La app baja '
        'esas sesiones de una fuente tuya (el /pool de tu Worker) y las rota '
        'sola; acá ves si la fuente está viva.',
    estadoTitulo: 'Estado del pool',
    estadoOk: 'Con sesiones',
    estadoFuenteCaida: 'Fuente caída',
    estadoSinTokens: 'Sin sesiones',
    estadoSinFuentes: 'Sin configurar',
    estadoConsultando: 'Consultando…',
    estadoError: 'No se pudo consultar',
    detalleOk: 'El pool tiene credenciales vivas: la descarga directa de Qobuz funciona.',
    detalleFuenteCaida:
        'Ninguna fuente respondió: revisá la URL y que el endpoint esté publicado.',
    detalleSinTokens:
        'La fuente respondió pero no publicó sesiones vivas: revisá que tenga tokens de una cuenta con suscripción.',
    detalleSinFuentes: 'No hay ninguna URL de pool configurada.',
    detalleError: 'No se pudo consultar el estado del pool. Probá de nuevo.',
    urlLabel: 'URL del pool (opcional)',
    urlHint: 'https://tu-worker.workers.dev/pool/<secreto>',
    urlAyuda:
        'Una sola URL. Si la dejás vacía se usa el origen de fábrica. Poné el '
        'secreto en la ruta si tu Worker lo pide.',
    urlInvalida: 'Pega la dirección completa, empezando con https://',
    guardar: 'Guardar',
    guardado: 'Guardado',
    revisar: 'Revisar estado',
    revisando: 'Revisando…',
  );

  static const en = StringsPoolQobuz(
    titulo: 'Qobuz sessions',
    ayuda:
        'Qobuz only hands over FLAC with a subscription account. The app '
        'downloads those sessions from a source of yours (your Worker /pool) '
        'and rotates them by itself; here you see whether the source is alive.',
    estadoTitulo: 'Pool status',
    estadoOk: 'Has sessions',
    estadoFuenteCaida: 'Source down',
    estadoSinTokens: 'No sessions',
    estadoSinFuentes: 'Not set up',
    estadoConsultando: 'Checking…',
    estadoError: 'Could not check',
    detalleOk: 'The pool has live credentials: Qobuz direct download works.',
    detalleFuenteCaida:
        'No source answered: check the URL and that the endpoint is deployed.',
    detalleSinTokens:
        'The source answered but published no live sessions: check that it has tokens from a subscription account.',
    detalleSinFuentes: 'No pool URL is configured.',
    detalleError: 'Could not check the pool status. Try again.',
    urlLabel: 'Pool URL (optional)',
    urlHint: 'https://your-worker.workers.dev/pool/<secret>',
    urlAyuda:
        'A single URL. Leave it empty to use the factory origin. Put the '
        'secret in the path if your Worker asks for one.',
    urlInvalida: 'Paste the full address, starting with https://',
    guardar: 'Save',
    guardado: 'Saved',
    revisar: 'Check status',
    revisando: 'Checking…',
  );
}
