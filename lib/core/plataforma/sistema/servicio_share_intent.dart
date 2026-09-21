// ─────────────────────────────────────────────────────────────
// servicio_share_intent.dart — Maneja share intents entrantes
// (Android/iOS): captura texto/URLs compartidas a la app y extrae
// las URLs de música (Spotify, Deezer, Apple, Tidal, etc.).
// Se conecta con: MethodChannel nativo + stream de URLs compartidas.
// Parte del flujo: arranque y compartición hacia la app.
// ─────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Maneja share intents entrantes (Android/iOS).
class ServicioShareIntent {
  static const _canal = MethodChannel('com.bitly/share_intent');
  static final ServicioShareIntent _instancia = ServicioShareIntent._();
  static ServicioShareIntent get instance => _instancia;

  final StreamController<String> _urlController =
      StreamController<String>.broadcast();
  Stream<String> get urlsCompartidas => _urlController.stream;

  ServicioShareIntent._();

  /// Inicializa el listener de share intents.
  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    _canal.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSharedText':
          final texto = call.arguments as String?;
          if (texto != null && texto.isNotEmpty) {
            _urlController.add(texto);
          }
          break;
        case 'onSharedUrl':
          final url = call.arguments as String?;
          if (url != null && url.isNotEmpty) {
            _urlController.add(url);
          }
          break;
      }
    });

    // Verifica el share intent inicial (app abierta vía compartir).
    try {
      final textoInicial = await _canal.invokeMethod<String>(
        'getInitialSharedText',
      );
      if (textoInicial != null && textoInicial.isNotEmpty) {
        _urlController.add(textoInicial);
      }
    } catch (_) {
      // Método no disponible en esta plataforma.
    }
  }

  void dispose() {
    _urlController.close();
  }
}
