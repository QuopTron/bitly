// ─────────────────────────────────────────────────────────────
// servicio_verificacion.dart — Orquesta la verificación de sesiones
// firmadas (Cloudflare Turnstile) de las extensiones: provisiona al
// arranque, mantiene vivas las sesiones en segundo plano (keepalive),
// y muestra el challenge en un WebView in-app (o navegador en
// desktop). El dialog WebView vive en
// shared/widgets/dialogo_verificacion.dart. El estado compartido,
// el keepalive y el mostrar viven en los parts del mismo library.
// Se conecta con: backend_go (sesiones firmadas) + deep links.
// Parte del flujo: verificación de sesiones (Cloudflare).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/inyeccion.dart' as di;
import '../../shared/widgets/dialogo_verificacion.dart';
import '../../shared/widgets/panel_verificacion_web.dart';
import '../backend_go/contrato_backend.dart';
import 'servidor_callback_escritorio.dart';

// Re-exportado para que los llamadores (y los tests) sigan importando
// grantVerificacionDeUrl / grantDeCadena desde este library.
export 'grant_verificacion.dart';

part 'verificacion_estado.dart';
part 'verificacion_keepalive.dart';
part 'verificacion_lote.dart';
part 'verificacion_mostrar.dart';
part 'verificacion_ui.dart';

final _logVerificacion = Logger();

/// Canal nativo por el que llega el grant del deep link.
const _canalGrant = MethodChannel('com.bitly/session_grant');

/// Timeout por defecto para esperar un grant de verificación.
const _timeoutGrant = Duration(seconds: 90);

/// Gracia tras volver de background antes de cancelar la verificación.
const _graciaResume = Duration(seconds: 2);

/// Servicio singleton de verificación de sesiones firmadas.
class ServicioVerificacion
    with
        WidgetsBindingObserver,
        VerificacionEstado,
        VerificacionKeepalive,
        VerificacionMostrar,
        VerificacionLote,
        VerificacionUi {
  static final ServicioVerificacion _instancia = ServicioVerificacion._();
  factory ServicioVerificacion() => _instancia;
  ServicioVerificacion._();

  /// UA Chrome móvil real para que Turnstile no marque el WebView embebido.
  static const chromeUA =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Mobile Safari/537.36';

  /// Proveedores con sesión firmada que pueden tener challenge (Cloudflare o
  /// auth). Provisionarlos al arranque evita fallos VERIFY_REQUIRED durante
  /// streaming/búsqueda/descargas.
  static const fuentesSesionFirmada = <String>[
    'qobuz-web', 'amazon', 'deezer', 'pandora', 'tidal-web',
  ];

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    _canalGrant.setMethodCallHandler((call) async {
      if (call.method == 'onSessionGrant') {
        _logVerificacion.i('[Verificacion] Grant de sesión recibido por deep link');
        _completarPendiente((call.arguments as String? ?? '').trim());
      }
      return null;
    });
    WidgetsBinding.instance.addObserver(this);
    // La app puede ya estar resumed cuando init() corre (antes del primer
    // evento de lifecycle al observer), así sincronizar el keepalive ahora.
    final estado = WidgetsBinding.instance.lifecycleState;
    _appEnUso = estado == null || estado == AppLifecycleState.resumed;
    if (_appEnUso) _iniciarTimerKeepalive();
  }

  // ── UI/lifecycle (verificacion_ui.dart) ──

  /// Provisiona sesiones firmadas de TODAS las fuentes Cloudflare al arrancar
  /// (un RPC en paralelo dentro del backend, sin trabar el arranque). Registra
  /// en [_necesitaVerificacion] las que requieren challenge humano, pero NO
  /// abre modal: los flujos de acción explícita preguntan bajo demanda.
  Future<void> provisionarSesionesFirmadas() async {
    if (!estaListo) return;
    final backend = di.sl<BackendService>();
    _runActivo = true;
    _deshabilitado = false;
    _necesitaVerificacion.clear();
    try {
      final resultados = await backend
          .provisionSignedSessions()
          .timeout(const Duration(seconds: 15));
      _keepaliveAlgunaVezExitoso = true;
      for (final fuente in fuentesSesionFirmada) {
        final estado = resultados[fuente];
        if (estado is Map && estado['needs_verification'] == true) {
          _necesitaVerificacion.add(fuente);
        }
        _logVerificacion.i('[Verificacion] $fuente provision: $estado');
      }
    } catch (e) {
      _logVerificacion.w('[Verificacion] provisionSignedSessions falló: $e');
    } finally {
      _runActivo = false;
    }
    // Arrancar la cadencia de refresh silencioso ahora que el backend está tibio.
    if (_appEnUso) _iniciarTimerKeepalive();
  }

  // ── Lote + nombres (verificacion_lote.dart) / UI (verificacion_ui.dart) ──
}