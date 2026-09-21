// ─────────────────────────────────────────────────────────────
// strings_servicio.dart — Mensajes que nacen en la capa de servicio/
// bloc (sin BuildContext): errores de premium, nombre de Soulseek,
// avisos de verificación/búsqueda y errores del audio web. Se usan
// vía L10n. Español primario, inglés secundario.
// Se conecta con: app_localizations.dart (lo expone como `servicio`) +
// premium_mixin, ayudantes_backend, servicio_soulseek,
// verificacion_navegador, busqueda_verificacion, setup y audio web.
// Parte del flujo: mensajes de servicios y blocs.
// ─────────────────────────────────────────────────────────────

class StringsServicio {
  final String soulseekNombreRequerido;
  final String soulseekRespuestaInesperada;
  final String soulseekConectada;
  final String soulseekCuentaCreada;
  final String soulseekNoConectar;
  final String soulseekNombreTomado;
  final String soulseekNombreInvalido;
  final String _errorGenerico;
  final String audioWebCabeceras;
  final String audioWebAutoplay;
  final String audioWebCancelada;
  final String audioWebRed;
  final String audioWebDecodificar;
  final String audioWebNoDisponible;
  final String audioWebGenerico;
  final String _navegadorAbierto;
  final String _busquedaVerificacion;
  final String busquedaFallo;

  const StringsServicio({
    required this.soulseekNombreRequerido,
    required this.soulseekRespuestaInesperada,
    required this.soulseekConectada,
    required this.soulseekCuentaCreada,
    required this.soulseekNoConectar,
    required this.soulseekNombreTomado,
    required this.soulseekNombreInvalido,
    required String errorGenerico,
    required this.audioWebCabeceras,
    required this.audioWebAutoplay,
    required this.audioWebCancelada,
    required this.audioWebRed,
    required this.audioWebDecodificar,
    required this.audioWebNoDisponible,
    required this.audioWebGenerico,
    required String navegadorAbierto,
    required String busquedaVerificacion,
    required this.busquedaFallo,
  }) : _errorGenerico = errorGenerico,
       _navegadorAbierto = navegadorAbierto,
       _busquedaVerificacion = busquedaVerificacion;

  /// Error genérico con el detalle ya interpolado.
  String errorGenerico(Object e) => _errorGenerico.replaceFirst('{e}', '$e');

  /// Aviso de que el captcha se abrió en el navegador.
  String navegadorAbierto(String nombre) =>
      _navegadorAbierto.replaceFirst('{n}', nombre);

  /// Error de búsqueda cuando la fuente exige verificación.
  String busquedaVerificacion(String nombre) =>
      _busquedaVerificacion.replaceFirst('{n}', nombre);

  static const es = StringsServicio(
    soulseekNombreRequerido: 'Escribí el nombre que querés usar en Soulseek.',
    soulseekRespuestaInesperada: 'Respuesta inesperada del backend.',
    soulseekConectada: 'Cuenta conectada y lista para buscar.',
    soulseekCuentaCreada:
        'Cuenta creada y conectada. La contraseña quedó guardada: Soulseek no '
        'tiene recuperación, así que exportala si querés usar esta cuenta en '
        'otro cliente.',
    soulseekNoConectar: 'No se pudo conectar con Soulseek.',
    soulseekNombreTomado:
        'Ese nombre ya está tomado en Soulseek. Elegí otro para continuar.',
    soulseekNombreInvalido:
        'Ese nombre no es válido en Soulseek. Probá con otro.',
    errorGenerico: 'Error: {e}',
    audioWebCabeceras:
        'Este stream necesita cabeceras que el navegador no puede enviar; '
        'si no suena, probá con otra fuente.',
    audioWebAutoplay: 'Tocá play otra vez para permitir la reproducción',
    audioWebCancelada: 'Reproducción cancelada',
    audioWebRed: 'Error de red al traer el audio (¿sin conexión?)',
    audioWebDecodificar: 'El audio no se pudo decodificar',
    audioWebNoDisponible:
        'El audio no está disponible o el enlace no es reproducible '
        '(algunos streams exigen cabeceras que el navegador no puede mandar)',
    audioWebGenerico: 'El navegador no pudo reproducir el audio',
    navegadorAbierto: 'Se abrió el navegador — completa el captcha para {n}',
    busquedaVerificacion:
        'Verificación requerida para {n}. Ábrela desde Configuración y reintenta.',
    busquedaFallo: 'No se pudo completar la búsqueda. Reintenta en un momento.',
  );

  static const en = StringsServicio(
    soulseekNombreRequerido: 'Type the name you want to use on Soulseek.',
    soulseekRespuestaInesperada: 'Unexpected backend response.',
    soulseekConectada: 'Account connected and ready to search.',
    soulseekCuentaCreada:
        'Account created and connected. The password was saved: Soulseek has '
        'no recovery, so export it if you want to use this account in another '
        'client.',
    soulseekNoConectar: "Couldn't connect to Soulseek.",
    soulseekNombreTomado:
        'That name is already taken on Soulseek. Choose another to continue.',
    soulseekNombreInvalido: "That name isn't valid on Soulseek. Try another.",
    errorGenerico: 'Error: {e}',
    audioWebCabeceras:
        "This stream needs headers the browser can't send; if it doesn't "
        'play, try another source.',
    audioWebAutoplay: 'Tap play again to allow playback',
    audioWebCancelada: 'Playback cancelled',
    audioWebRed: 'Network error fetching the audio (offline?)',
    audioWebDecodificar: "The audio couldn't be decoded",
    audioWebNoDisponible:
        "The audio isn't available or the link can't be played (some streams "
        "require headers the browser can't send)",
    audioWebGenerico: "The browser couldn't play the audio",
    navegadorAbierto: 'Browser opened — complete the captcha for {n}',
    busquedaVerificacion:
        'Verification required for {n}. Open it from Settings and retry.',
    busquedaFallo: "Couldn't complete the search. Try again in a moment.",
  );
}
