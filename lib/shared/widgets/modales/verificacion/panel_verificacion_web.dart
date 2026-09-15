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

import '../../../../core/servicios/verificacion/servicio_verificacion.dart';
import 'vista_fallo_verificacion.dart';

part 'panel_verificacion_branding.dart';
part 'panel_verificacion_controlador.dart';
part 'panel_verificacion_navegacion.dart';
part 'panel_verificacion_callbacks.dart';
part 'panel_verificacion_branding_js.dart';

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
    if (widget.urlAuth.contains('zarz.moe')) {
      debugPrint('[Verificacion] PanelVerificacionWeb: refusing zarz URL → empty');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.alObtenerGrant('');
      });
      return;
    }
    _controlador.loadRequest(Uri.parse(widget.urlAuth));
  }

  /// Marca la vista de fallo (invocado desde los callbacks del WebView).
  void _marcarFallo() {
    if (mounted) setState(() => _fallo = true);
  }

  /// Marca la página como cargada y descarta un fallo previo.
  void _marcarCargada() {
    if (mounted) {
      setState(() {
        _fallo = false;
        _paginaCargada = true;
      });
    }
  }

  @override
  void dispose() {
    _timerCarga?.cancel();
    super.dispose();
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