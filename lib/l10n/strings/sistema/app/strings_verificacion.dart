// ─────────────────────────────────────────────────────────────
// strings_verificacion.dart — Textos del dialog de verificación
// (captcha Cloudflare): título, explicación, abrir en navegador y
// la vista de fallo con reintento. Español primario, inglés.
// Se conecta con: app_localizations.dart (lo expone como `verificacion`)
// y dialogo_verificacion_piezas / vista_fallo_verificacion.
// Parte del flujo: verificación de sesiones.
// ─────────────────────────────────────────────────────────────

class StringsVerificacion {
  final String avisoNavegador;
  final String abrirNavegador;
  final String falloTitulo;
  final String falloAyuda;
  final String reintentar;
  final String _titulo;
  final String _cuerpo;

  const StringsVerificacion({
    required this.avisoNavegador,
    required this.abrirNavegador,
    required this.falloTitulo,
    required this.falloAyuda,
    required this.reintentar,
    required String titulo,
    required String cuerpo,
  }) : _titulo = titulo,
       _cuerpo = cuerpo;

  /// Título del dialog con el nombre de la fuente.
  String titulo(String fuente) => _titulo.replaceFirst('{fuente}', fuente);

  /// Explicación larga con el nombre de la fuente.
  String cuerpo(String fuente) => _cuerpo.replaceFirst('{fuente}', fuente);

  static const es = StringsVerificacion(
    avisoNavegador: 'Si el captcha no carga aquí, ábrelo en el navegador:',
    abrirNavegador: 'Abrir en el navegador',
    falloTitulo: 'No se pudo cargar la verificación',
    falloAyuda: 'Toca "Abrir en el navegador" para completar el captcha.',
    reintentar: 'Reintentar',
    titulo: 'Verificar {fuente}',
    cuerpo:
        'Completa la verificación para poder reproducir y descargar '
        'música de {fuente}. Es un control del propio servicio de música '
        '(no nuestro): al resolverlo, la app continúa sola y no te lo '
        'volverá a pedir hasta que la sesión expire.',
  );

  static const en = StringsVerificacion(
    avisoNavegador: "If the captcha doesn't load here, open it in the browser:",
    abrirNavegador: 'Open in browser',
    falloTitulo: "Couldn't load the verification",
    falloAyuda: 'Tap "Open in browser" to complete the captcha.',
    reintentar: 'Retry',
    titulo: 'Verify {fuente}',
    cuerpo:
        'Complete the verification to play and download music from '
        '{fuente}. It is a check from the music service itself (not ours): '
        'once solved, the app continues on its own and will not ask again '
        'until the session expires.',
  );
}
