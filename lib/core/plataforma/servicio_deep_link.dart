// ─────────────────────────────────────────────────────────────
// servicio_deep_link.dart — Captura deep links
// (bitly://open?... o https://bitly.app/open?...) y los expone como
// stream para que la UI muestre el overlay "compartido contigo".
// Se conecta con: MethodChannel nativo + overlay compartido.
// Parte del flujo: arranque y llegada de links (WhatsApp, etc).
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

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
    } catch (_) {}
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
      final type = uri.queryParameters['type'] ?? 'track';
      final id = uri.queryParameters['id'] ?? '';
      final query = uri.queryParameters['q'] ?? '';
      if (id.isEmpty && query.isEmpty) return null;
      return DatosDeepLink(type: type, id: id, query: query);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _controller.close();
  }
}

class DatosDeepLink {
  final String type;
  final String id;
  final String query;

  const DatosDeepLink({
    required this.type,
    required this.id,
    required this.query,
  });
}