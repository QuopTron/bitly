// servicio_oauth_youtube.dart — OAuth de YouTube: Google Sign-In nativo
// (Credential Manager en Android, picker en iOS/macOS) con caída a WebView
// in-app (oauth_youtube_app.dart). Verifica/refresca el token
// (refreshYoutubeOauth de Go) y guarda credenciales en la extensión
// ytmusic-spotiflac. El flujo nativo vive en oauth_youtube_nativo.dart.

import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../app/inyeccion.dart' as di;
import '../../../config/secretos.dart';
import '../../backend_go/nucleo/contrato_backend.dart';
import '../../cache/almacenes/cache_ajustes.dart';
import 'oauth_youtube_app.dart';
import '../proveedores/servicio_credenciales_proveedor.dart';

part 'oauth_youtube_nativo.dart';
part 'servicio_oauth_youtube_helpers.dart';

/// OAuth de YouTube: nativo (bonito, sin Chrome) → WebView in-app → error.
class ServicioOAuthYouTube {
  static const idExt = 'ytmusic-spotiflac';

  CacheAjustes get _cache => di.sl<CacheAjustes>();
  BackendService get _backend => di.sl<BackendService>();

  Future<bool> get estaConectado async {
    final token = await _cache.getAjuste('${idExt}_oauthAccessToken');
    return token != null && token.trim().isNotEmpty;
  }

  // ─── Conectar ──

  /// Conecta YouTube. Orden: WebView in-app (Android/Windows, consentimiento
  /// embebido sin Chrome) → picker nativo (iOS/macOS) → error. Devuelve un
  /// mensaje legible (éxito, cancelado o error).
  Future<String> conectar([BuildContext? context]) async {
    if (_webviewPrimero()) {
      if (context != null && context.mounted) {
        return _conectarInAppConReintento(this, context);
      }
      return 'No se pudo conectar YouTube en este dispositivo.';
    }

    if (_soportaNativo()) {
      try {
        return await _conectarNativo(this);
      } on _ExcepcionCanceladoUsuario {
        return 'Inicio de sesión cancelado.';
      } catch (e) {
        debugPrint('YouTube OAuth: flujo nativo falló ($e)');
      }
    } else {
      debugPrint('YouTube OAuth: sin flujo nativo en esta plataforma');
    }

    if (context != null && context.mounted) {
      return _conectarInAppConReintento(this, context);
    }

    return 'No se pudo conectar YouTube en este dispositivo.';
  }

  // ─── Token ──

  /// Verifica que haya token usable; si solo hay refresh, lo refresca vía
  /// Go y persiste el nuevo. Devuelve true cuando hay token válido.
  Future<bool> asegurarTokenValido() async {
    final token = await _cache.getAjuste('${idExt}_oauthAccessToken');
    if (token != null && token.trim().isNotEmpty) return true;

    final refreshToken = await _cache.getAjuste('${idExt}_oauthRefreshToken');
    if (refreshToken == null || refreshToken.trim().isEmpty) return false;

    final clientId = await _cache.getAjuste('${idExt}_oauthClientId');
    final clientSecret = await _cache.getAjuste('${idExt}_oauthClientSecret');
    if (clientId == null || clientId.isEmpty) return false;

    try {
      final raw = await _backend.rpcCall('refreshYoutubeOauth', {
        'client_id': clientId,
        'client_secret': clientSecret ?? '',
        'refresh_token': refreshToken,
      });

      final res = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);

      if (res['ok'] == true && res['access_token'] != null) {
        final nuevo = res['access_token'] as String;
        final guardados = await _ajustesGuardados(this);
        guardados['oauthAccessToken'] = nuevo;
        await ServicioCredencialesProveedor(_backend, _cache)
            .guardarYReinicializar(idExt, guardados);
        debugPrint('YouTube OAuth: token refrescado correctamente');
        return true;
      }
    } catch (e) {
      debugPrint('YouTube OAuth: refresh falló: $e');
    }

    return false;
  }

  // ─── Helpers ──

  /// Cierra la sesión de YouTube y limpia los tokens.
  Future<String> cerrarSesion() async {
    try {
      await _inicializar();
      await _signOutNativo();
    } catch (e) { debugPrint("[OAuth] error: $e"); }

    final guardados = await _ajustesGuardados(this);
    guardados.remove('oauthAccessToken');
    guardados.remove('oauthRefreshToken');
    await _cache.guardarAjuste('${idExt}_oauthAccessToken', '');
    await _cache.guardarAjuste('${idExt}_oauthRefreshToken', '');
    await ServicioCredencialesProveedor(_backend, _cache)
        .guardarYReinicializar(idExt, guardados);
    return 'Sesión de YouTube cerrada.';
  }
}