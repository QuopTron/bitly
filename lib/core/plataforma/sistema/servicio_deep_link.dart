// ─────────────────────────────────────────────────────────────
// servicio_deep_link.dart — Captura deep links
// (bitly://open?... o https://<host>/open?...) y los expone como
// stream para que la UI muestre el overlay "compartido contigo".
// El host del enlace https es el dominio verificado de la app (App Link en
// Android, Universal Link en iOS): ver servicio_compartir.dart.
// Se conecta con: MethodChannel nativo + overlay compartido.
// Parte del flujo: arranque y llegada de links (WhatsApp, etc).
// ─────────────────────────────────────────────────────────────

import "package:flutter/foundation.dart";
import 'dart:async';
import 'dart:io';


import 'package:flutter/services.dart';

import '../../servicios/compartir/datos_compartido.dart';
import '../../servicios/compartir/servicio_compartir.dart';
import '../../servicios/compartir/servicio_historial_compartidos.dart';

/// Captura deep links y los expone como stream.
class ServicioDeepLink {
  static const _canal = MethodChannel('com.bitly/deep_link');
  static final ServicioDeepLink _instancia = ServicioDeepLink._();
  static ServicioDeepLink get instance => _instancia;

  final _controller = StreamController<DatosDeepLink>.broadcast();
  Stream<DatosDeepLink> get onDeepLink => _controller.stream;

  DatosDeepLink? _linkPendiente;
  DatosDeepLink? get linkPendiente => _linkPendiente;

  ServicioDeepLink._();

  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _canal.setMethodCallHandler((call) async {
      if (call.method == 'onDeepLink') {
        final url = call.arguments as String?;
        if (url != null && url.isNotEmpty) {
          final datos = _parsear(url);
          if (datos != null) {
            _linkPendiente = datos;
            _controller.add(datos);
          }
        }
      }
    });

    // Verifica el deep link inicial (app abierta vía link).
    try {
      final inicial = await _canal.invokeMethod<String>('getInitialDeepLink');
      if (inicial != null && inicial.isNotEmpty) {
        final datos = _parsear(inicial);
        if (datos != null) {
          _linkPendiente = datos;
        }
      }
    } catch (e) { debugPrint("[App] $e"); }
  }

  /// Emite un link armado dentro de la app (p. ej. un enlace de Bitly que
  /// llegó por el share sheet de Android y se tradujo a DatosDeepLink).
  void emitir(DatosDeepLink datos) {
    final compartido = datos.compartido;
    if (compartido != null) _registrarCompartido(compartido);
    _linkPendiente = datos;
    _controller.add(datos);
  }

  /// Consume el deep link pendiente para que el overlay no se vuelva a mostrar.
  DatosDeepLink? consumirPendiente() {
    final link = _linkPendiente;
    _linkPendiente = null;
    return link;
  }

  DatosDeepLink? _parsear(String url) {
    try {
      final uri = Uri.parse(url);
      // Enlace de Bitly: los datos vienen cifrados dentro (?s=...). Se
      // descifran acá y alimentan el overlay "te compartieron".
      final compartido = ServicioCompartir.instance.leerEnlace(url);
      if (compartido != null) {
        _registrarCompartido(compartido);
        return DatosDeepLink(
          type: compartido.tipo,
          id: compartido.isrc,
          query: compartido.nombre,
          compartido: compartido,
        );
      }
      final type = uri.queryParameters['type'] ?? 'track';
      final id = uri.queryParameters['id'] ?? '';
      final query = uri.queryParameters['q'] ?? '';
      // Enlace completo de una fuente (Spotify/YouTube/...). Cuando viene, la
      // app lo resuelve contra Go en vez de buscar por nombre.
      final enlace = uri.queryParameters['url'] ?? '';
      if (id.isEmpty && query.isEmpty && enlace.isEmpty) return null;
      return DatosDeepLink(
        type: type,
        id: id,
        query: query,
        url: enlace,
      );
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _controller.close();
  }
}

/// Anota el enlace compartido recibido: queda en el historial ("quién te
/// compartió qué", visible en Ajustes) y deja una traza para diagnosticar en
/// el dispositivo por qué no apareció la carta (enlace manipulado, vacío...).
void _registrarCompartido(DatosCompartido datos) {
  final quien = datos.emisor.isEmpty ? 'alguien' : datos.emisor;
  final isrc = datos.isrc.isEmpty ? '' : ' (${datos.isrc})';
  debugPrint('[Compartido] enlace de $quien: ${datos.nombre}$isrc');
  // Sin await: la carta se muestra ya, el historial se escribe detrás.
  unawaited(ServicioHistorialCompartidos.instance.registrar(datos));
}

class DatosDeepLink {
  final String type;
  final String id;
  final String query;

  /// Enlace completo de la fuente (p. ej. https://open.spotify.com/track/x).
  /// Vacío cuando el deep link solo trae tipo/id/consulta.
  final String url;

  /// Datos del enlace de Bitly (compartido desde otra app con la versión
  /// nueva): ISRC, nombre, carátula y quién lo manda. null en los enlaces
  /// viejos o de otras fuentes.
  final DatosCompartido? compartido;

  const DatosDeepLink({
    required this.type,
    required this.id,
    required this.query,
    this.url = '',
    this.compartido,
  });
}