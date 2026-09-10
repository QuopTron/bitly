// ─────────────────────────────────────────────────────────────
// verificacion_mostrar.dart — PART de servicio_verificacion.dart:
// muestra el challenge de Cloudflare (WebView in-app en móvil,
// navegador del sistema + servidor loopback en desktop) y resuelve
// el grant. El dialog WebView vive en
// shared/widgets/dialogo_verificacion.dart.
// Se conecta con: servicio_verificacion.dart + dialogo_verificacion.
// Parte del flujo: verificación de sesiones (mostrar challenge).
// ─────────────────────────────────────────────────────────────

part of 'servicio_verificacion.dart';  /// Muestra el challenge de Cloudflare. Mixin aplicado en ServicioVerificacion.
  /// Depende de VerificacionKeepalive para que VerificacionLote/VerificacionUi
  /// (más abajo en la cadena) vean sus miembros (p.ej. _onLifecycle).
  mixin VerificacionMostrar on VerificacionKeepalive {
  /// Muestra el challenge en un dialog WebView in-app y devuelve el grant
  /// code, o null si se canceló/timeout.
  ///
  /// [intentarAuto] (default true): intenta primero el auto-pase de Turnstile
  /// en un WebView oculto (3×12s). El setup de bienvenida pasa false para
  /// abrir el WebView VISIBLE de inmediato — el usuario espera ver el sandbox
  /// al tocar Verificar, no 36s de "cargando" sin nada en pantalla.
  Future<String?> mostrarVerificacion({
    required String extId,
    required String nombreMostrado,
    required String urlAuth,
    Duration? timeout,
    bool intentarAuto = true,
  }) async {
    // Solo honrar un skip mientras un run de provisionSignedSessions está
    // activo; los llamadores directos (slide de setup) siempre tienen su modal.
    if (_deshabilitado && _runActivo) return null;
    _completarPendiente(''); // cancelar cualquier completer pendiente stale
    final completador = Completer<String?>();
    _pendiente = completador;
    NavigatorState? dialogNav;

    // Linux: webview_win_floating 2.x no soporta Linux (solo Windows), así abrir
    // el challenge en el navegador del sistema y recibir el grant en el servidor
    // loopback local (el backend apuntó el callback del challenge ahí). Si el
    // servidor callback no pudo bindear, skip de la fuente en vez de mostrar un
    // dialog WebView roto.
    final esLinux = Platform.isLinux;
    final callbackDesktop = ServidorCallbackEscritorio.instance;
    if (esLinux) {
      if (!callbackDesktop.estaListo) {
        _logVerificacion.w('[Verificacion] Servidor callback desktop no disponible, '
            'omitiendo verificación de $extId');
        _completarPendiente('');
        return null;
      }
      _flujoNavegador = true;
      try {
        unawaited(_lanzarNavegador(nombreMostrado, urlAuth));
        final grant = await callbackDesktop.esperarGrant(
            timeout ?? _timeoutGrant);
        _completarPendiente(grant);
        return grant;
      } finally {
        _flujoNavegador = false;
      }
    }

    // ── Intento silencioso ─────────────────────────────────────────────────
    // El challenge de Cloudflare suele ser un Turnstile en modo managed
    // (no-interactivo): dentro de un WebView real se auto-completa SOLO y el
    // grant llega sin que el usuario toque nada. Intentarlo primero en un
    // WebView oculto (1x1px, sin render visible) evita abrir el modal: la
    // sesión queda firmada en segundo plano y el usuario no ve NADA. Solo si
    // el challenge requiere interacción humana (o no auto-completa a tiempo)
    // se cae al dialog visible de abajo. El keepalive (cada 25s) ya refresca
    // las sesiones vivas; este intento cubre el caso de sesión vencida.
    // Saltado cuando [intentarAuto] es false (setup): ahí el usuario quiere
    // ver el sandbox de inmediato y no esperar la ventana silenciosa.
    if (intentarAuto) {
      final ctxSilencioso = _navigatorKey?.currentContext;
      if (ctxSilencioso != null) {
        final grantSilencioso =
            await _intentarSilencioso(urlAuth, ctxSilencioso);
        if (grantSilencioso != null && grantSilencioso.isNotEmpty) {
          _completarPendiente(grantSilencioso);
          debugPrint('[Verificacion] AUTO-firmado sin modal ✓ '
              '(${grantSilencioso.length} chars)');
          return grantSilencioso;
        }
      }
    }

    _timeout = Timer(timeout ?? _timeoutGrant, () {
      _logVerificacion.w('[Verificacion] Verificación agotó el tiempo tras '
          '${(timeout ?? _timeoutGrant).inMinutes} min');
      _completarPendiente('');
      // Pop solo de la ruta del dialog Y solo mientras el dialog esté abierto.
      // Un Navigator.pop() ciego al timeout puede popear la última página del
      // root de go_router y crashear con 'popped the last page off of the stack'.
      final nav = dialogNav;
      if (nav != null && nav.mounted && nav.canPop() && _dialogoAbierto) {
        nav.pop();
      }
    });

    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) {
      // Sin contexto de UI disponible — fallback al navegador del sistema.
      unawaited(_lanzarNavegador(nombreMostrado, urlAuth));
      return completador.future;
    }

    _dialogoAbierto = true;
    try {
      await showDialog<void>(
        context: ctx,
        barrierDismissible: false,
        builder: (dialogCtx) {
          dialogNav = Navigator.of(dialogCtx);

          void terminar(String? grant) {
            _completarPendiente(grant);
            debugPrint('[Verificacion] terminar($grant) mounted=${dialogCtx.mounted} '
                'canPop=${dialogCtx.mounted ? Navigator.of(dialogCtx).canPop() : false}');
            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
          }

          // Windows: el callback del challenge apunta al servidor loopback local
          // (http://127.0.0.1:<puerto>/session-grant). Si el WebView embebido no
          // captura el grant por URL/JS (p.ej. WebView2 no disponible), el
          // servidor loopback lo recibe igual — conectarlo para cerrar el dialog
          // y completar la verificación por ese camino.
          if (Platform.isWindows && callbackDesktop.estaListo) {
            unawaited(() async {
              final grant = await callbackDesktop.esperarGrant(
                  timeout ?? _timeoutGrant);
              debugPrint('[Verificacion] loopback esperó grant → '
                  '${grant == null ? 'null' : grant.isNotEmpty ? 'OK' : 'vacío'}');
              if (grant != null && grant.isNotEmpty) {
                _completarPendiente(grant);
                if (dialogCtx.mounted &&
                    Navigator.of(dialogCtx).canPop()) {
                  Navigator.of(dialogCtx).pop();
                }
              }
            }());
          }

          return DialogoVerificacion(
            nombreMostrado: nombreMostrado,
            urlAuth: urlAuth,
            alObtenerGrant: terminar,
            alCancelar: () => terminar(null),
            alUsarNavegador: () {
              // Mantener el completer pendiente; el grant llega por deep link
              // (móvil) o por el servidor loopback (Windows/Linux).
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              unawaited(_lanzarNavegador(nombreMostrado, urlAuth));
            },
          );
        },
      );
    } finally {
      _dialogoAbierto = false;
    }

    return completador.future;
  }

  /// Intenta auto-completar el challenge en un WebView FUERA de pantalla. Los
  /// Turnstile en modo managed/no-interactivo se auto-resuelven solos: el
  /// puente JS `SpotiflacGrant` entrega el grant sin interacción humana.
  /// Devuelve el grant, o null si el challenge pide interacción o no completa
  /// a tiempo (ahí el flujo sigue sin molestar al usuario).
  ///
  /// Se intenta 3 veces: el primer pase suele correr sin cookies de Turnstile
  /// (cf_clearance) y puede que no auto-pase; si el widget corrió, deja la
  /// cookie en el store compartido (Android/WebView2) y los pases siguientes
  /// con la MISMA URL suelen auto-pasar. Estos pases extra son los que
  /// convierten muchos "interactivos por defecto" en silenciosos.
  Future<String?> _intentarSilencioso(String urlAuth, BuildContext ctx) async {
    for (var intento = 0; intento < 3; intento++) {
      final grant = await _intentoSilenciosoUnico(
        urlAuth,
        ctx,
        const Duration(seconds: 12),
      );
      if (grant != null && grant.isNotEmpty) return grant;
    }
    return null;
  }

  /// Un pase único del intento silencioso: carga la URL del challenge en un
  /// WebView oculto y espera el grant por el puente JS (o timeout).
  Future<String?> _intentoSilenciosoUnico(
    String urlAuth,
    BuildContext ctx,
    Duration tiempo,
  ) async {
    final completador = Completer<String?>();
    late OverlayEntry entrada;
    var cerrado = false;
    void terminar(String? grant) {
      if (cerrado) return;
      cerrado = true;
      if (!completador.isCompleted) completador.complete(grant);
    }

    // El WebView silencioso debe estar FUERA de la pantalla, no "oculto" con
    // Opacity(0): en Android los platform views se dibujan en una capa aparte
    // e IGNORAN la opacidad de Flutter — un Opacity(0) con SizedBox 1x1 se
    // renderiza igualmente visible a su tamaño real (p.ej. 656x640) y el
    // usuario ve un "modal" fantasma. Posicionarlo con left/top muy negativos
    // lo saca del viewport visible (clipBehavior: none) manteniéndolo vivo
    // para que Turnstile managed se auto-resuelva sin mostrar nada.
    entrada = OverlayEntry(
      builder: (_) => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -10000,
            top: -10000,
            width: 656,
            height: 640,
            child: IgnorePointer(
              child: PanelVerificacionWeb(
                urlAuth: urlAuth,
                alObtenerGrant: terminar,
                colorCarga: Colors.transparent,
                esOscuro: true,
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(ctx, rootOverlay: true).insert(entrada);

    final timer = Timer(tiempo, () => terminar(null));
    final grant = await completador.future;
    timer.cancel();
    entrada.remove();
    if (grant == null || grant.isEmpty) return null;
    return grant;
  }

  /// Verifica una fuente abriendo el MODAL in-app (usado por reproducción,
  /// descarga y búsqueda). La verificación es la autorización que el servicio
  /// de música pide para permitir reproducir/descargar su contenido: cuando la
  /// extensión la necesita, el modal aparece DENTRO de la app (nunca se
  /// oculta), el usuario resuelve el captcha, la app rescata el token, cierra
  /// el modal y continúa exactamente donde estaba. El modal incluye un texto
  /// que explica al usuario por qué aparece.
  ///
  /// mostrarVerificacion intenta primero el auto-pase de Turnstile (modo
  /// managed, que Cloudflare resuelve solo sin interacción); si no auto-pasa,
  /// cae al dialog visible. Devuelve true solo si la sesión quedó firmada.
  ///
  /// [intentarAuto] false (setup) abre el WebView visible de inmediato.
  Future<bool> verificarFuenteNoIntrusiva(
    String extId,
    String nombreMostrado,
    String urlAuth, {
    bool intentarAuto = true,
  }) async {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted || _deshabilitado) return false;
    final grant = await mostrarVerificacion(
      extId: extId,
      nombreMostrado: nombreMostrado,
      urlAuth: urlAuth,
      intentarAuto: intentarAuto,
    );
    if (grant == null || grant.isEmpty) return false;
    try {
      final backend = di.sl<BackendService>();
      final ok = await backend.completeSignedSessionGrant(extId, grant);
      if (ok) _necesitaVerificacion.remove(extId);
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// Intenta firmar UNA fuente de forma SILENCIOSA (WebView oculto, sin
  /// modal). Devuelve true solo si el grant se obtuvo y la sesión quedó
  /// firmada contra Go. Usado por el setup para no abrir challenges en cadena.
  Future<bool> verificarFuenteSilenciosa(String extId, String urlAuth) async {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted || _deshabilitado) return false;
    final grant = await _intentarSilencioso(urlAuth, ctx);
    if (grant == null || grant.isEmpty) return false;
    try {
      final backend = di.sl<BackendService>();
      return await backend.completeSignedSessionGrant(extId, grant);
    } catch (e) {
      _logVerificacion.w(
          '[Verificacion] verificarFuenteSilenciosa $extId error: $e');
      return false;
    }
  }

  /// Reintenta SILENCIOSAMENTE las fuentes que quedaron pendientes de
  /// verificar. Ideal tras obtener un grant (el usuario resolvió un checkbox o
  /// una managed auto-pasó): el store de cookies ya tiene cf_clearance y las
  /// demás fuentes (mismo gateway zarz, mismo sitekey de Turnstile) pueden
  /// auto-pasar SIN modal. Nunca abre UI. Llamado tras cada éxito del lote y
  /// al volver la app al primer plano.
  Future<void> reintentarPendientesSilencioso() async {
    if (!estaListo || _necesitaVerificacion.isEmpty || _deshabilitado) return;
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final backend = di.sl<BackendService>();
    final fuentes = List<String>.from(_necesitaVerificacion);
    for (final extId in fuentes) {
      if (_deshabilitado || _dialogoAbierto || _pendiente != null) break;
      if (!ctx.mounted) return;
      try {
        var url = await backend.getPendingVerificationUrl(extId);
        if (url.isEmpty) {
          url = await backend.triggerExtensionVerification(extId);
        }
        if (url.isEmpty) continue;
        if (!ctx.mounted) return;
        final grant = await _intentarSilencioso(url, ctx);
        if (grant == null || grant.isEmpty) continue;
        final ok = await backend.completeSignedSessionGrant(extId, grant);
        _logVerificacion.i(
            '[Verificacion] re-intento silencioso $extId → $ok');
        if (ok) _necesitaVerificacion.remove(extId);
      } catch (e) {
        _logVerificacion.w(
            '[Verificacion] re-intento silencioso $extId error: $e');
      }
    }
  }

  /// Abre el challenge en el navegador del sistema. El grant vuelve por el deep
  /// link `spotiflac://session-grant` (canal nativo).
  Future<void> _lanzarNavegador(String nombreMostrado, String urlAuth) async {
    _mostrarHintEspera(nombreMostrado);
    try {
      final ok = await launchUrl(
        Uri.parse(urlAuth),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) _lanzamientoFallido();
    } catch (e) {
      _logVerificacion.e('[Verificacion] Error lanzando navegador: $e');
      _lanzamientoFallido();
    }
  }

  /// El navegador no se pudo abrir: terminar la verificación pendiente de
  /// inmediato y liberar el servidor callback desktop para que la espera no
  /// se arrastre hasta el timeout.
  void _lanzamientoFallido() {
    ServidorCallbackEscritorio.instance.cancelar();
    _completarPendiente('');
  }

  void _mostrarHintEspera(String nombreMostrado) {
    final ctx = _navigatorKey?.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(
            'Se abrió el navegador — completa el captcha para $nombreMostrado'),
        duration: const Duration(seconds: 5),
      ));
  }
}