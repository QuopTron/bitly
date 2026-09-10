// ─────────────────────────────────────────────────────────────
// panel_verificacion_web.dart — Panel WebView del challenge
// Cloudflare (Turnstile): carga la URL, captura el grant por el
// puente JS `SpotiflacGrant` o deep link, re-marca a Bitly y
// muestra vista de fallo si no carga.
// Se conecta con: dialogo_verificacion + servicio_verificacion.
// Parte del flujo: verificación (WebView del captcha).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_win_floating/webview_win_floating.dart'
    show WindowsPlatformWebViewControllerCreationParams;

import '../../core/servicios/servicio_verificacion.dart';
import 'vista_fallo_verificacion.dart';

part 'panel_verificacion_branding.dart';
part 'panel_verificacion_controlador.dart';
part 'panel_verificacion_navegacion.dart';

final _logPanel = Logger();

/// Área WebView del challenge Cloudflare, con captura del grant.
class PanelVerificacionWeb extends StatefulWidget {
  final String urlAuth;
  final void Function(String grant) alObtenerGrant;
  final Color colorCarga;
  final bool esOscuro;

  const PanelVerificacionWeb({
    super.key,
    required this.urlAuth,
    required this.alObtenerGrant,
    required this.colorCarga,
    required this.esOscuro,
  });

  @override
  State<PanelVerificacionWeb> createState() => _PanelVerificacionWebState();
}

class _PanelVerificacionWebState extends State<PanelVerificacionWeb> {
  late final WebViewController _controlador;
  bool _fallo = false;
  bool _paginaCargada = false;
  Timer? _timerCarga;
  // El grant puede dispararse desde varios delegados para la misma URL —
  // dispararlo una sola vez para popear el dialog una sola vez.
  bool _grantDisparado = false;

  @override
  void initState() {
    super.initState();

    // Timeout de carga: sin él el dialog cuelga donde Turnstile no renderiza.
    // En Windows el primer arranque de WebView2 tarda más (inicialización del
    // runtime), así usar un timeout más generoso en escritorio para no mostrar
    // la vista de fallo mientras la página todavía está cargando.
    final escritorio = (Platform.isWindows ||
        Platform.isLinux ||
        Platform.isMacOS);
    _timerCarga = Timer(
      escritorio ? const Duration(seconds: 20) : const Duration(seconds: 10),
      () {
        if (mounted && !_paginaCargada && !_fallo && !_grantDisparado) {
          _logPanel.w('[Verificacion] Timeout de carga — mostrando fallo');
          setState(() => _fallo = true);
        }
      },
    );

    // El controlador incluye el puente JS `SpotiflacGrant` + delegate (parts).
    _controlador = _crearControlador(this);

    // UA Chrome para que Turnstile renderice en el WebView embebido.
    final plataforma = _controlador.platform;
    if (plataforma is AndroidWebViewController) {
      unawaited(plataforma.setUserAgent(ServicioVerificacion.chromeUA));
    }
    _controlador.loadRequest(Uri.parse(widget.urlAuth));
  }

  @override
  void dispose() {
    _timerCarga?.cancel();
    super.dispose();
  }

  void _chequear(String? url) {
    if (url == null) return;
    // Parser TOLERANTE (mismo que el loopback y el puente JS): la URL de
    // callback de zarz suele llegar con la query malformada
    // (`?cb_version=v2grant?grant=gr_...`) y el parseo estricto la descartaba
    // en silencio → el modal quedaba abierto aunque la verificación hubiera
    // terminado bien. En Windows es la ruta principal (la página navega al
    // callback loopback), por eso ahí no cerraba y en Android sí.
    final grant = grantDeCadena(url);
    if (grant != null) _dispararGrant(grant);
  }

  void _dispararGrant(String grant) {
    if (_grantDisparado) return;
    _grantDisparado = true;
    _timerCarga?.cancel();
    debugPrint('[Verificacion] GRANT capturado en WebView ($grant) → alObtenerGrant');
    widget.alObtenerGrant(grant);
  }

  /// Re-marca el captcha a Bitly (JS en panel_verificacion_branding.dart) e
  /// inyecta el interceptor de red que rescata el grant de la respuesta del
  /// challenge. El interceptor corre ANTES de que la página haga su fetch de
  /// verificación (que ocurre recién cuando el usuario resuelve el captcha),
  /// así el hook queda puesto a tiempo.
  void _aplicarBranding(String url) {
    if (url.isEmpty || !url.contains('zarz.moe')) return;
    unawaited(_controlador.runJavaScript(_jsInterceptorGrant));
    unawaited(_controlador.runJavaScript(_jsBrandingBitly));
  }

  /// onPageStarted: intenta inyectar el interceptor lo antes posible (por si
  /// el documento nuevo ya está activo). Es idempotente.
  void _alIniciarPagina(String url) {
    if (url.contains('zarz.moe')) {
      unawaited(_controlador.runJavaScript(_jsInterceptorGrant));
    }
  }

  /// onPageFinished: marca la página cargada + branding.
  void _paginaTerminoDeCargar(String url) {
    _chequear(url);
    if (mounted) {
      setState(() {
        _fallo = false;
        _paginaCargada = true;
      });
    }
    _aplicarBranding(url);
  }

  /// onWebResourceError: solo fallo para errores del frame principal.
  void _errorRecursoWeb(WebResourceError error) {
    if (error.isForMainFrame != false) {
      _logPanel.e('[Verificacion] Error WebView: '
          '${error.description} code=${error.errorCode} url=${error.url}');

      // El redirect spotiflac:// reporta ERR_UNKNOWN_URL_SCHEME (varía por
      // dispositivo); el delegado de navegación ya capturó el grant.
      final esErrorScheme = error.errorCode == -10 ||
          error.description.toUpperCase().contains('UNKNOWN_URL_SCHEME') ||
          (error.url ?? '').startsWith('spotiflac://');
      if (!esErrorScheme && mounted) {
        setState(() => _fallo = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fallo) {
      return VistaFalloVerificacion(
        esOscuro: widget.esOscuro,
        alReintentar: () {
          setState(() => _fallo = false);
          _controlador.reload();
        },
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        WebViewWidget(controller: _controlador),
        if (!_paginaCargada)
          CircularProgressIndicator(strokeWidth: 2, color: widget.colorCarga),
      ],
    );
  }
}