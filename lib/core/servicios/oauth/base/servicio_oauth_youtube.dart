// servicio_oauth_youtube.dart — OAuth de YouTube: Google Sign-In nativo
// (Credential Manager en Android, picker en iOS/macOS) con caída a WebView
// in-app (oauth_youtube_app.dart). Verifica/refresca el token
// (refreshYoutubeOauth de Go) y guarda credenciales en la extensión
// ytmusic-spotiflac. El flujo nativo vive en oauth_youtube_nativo.dart.

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../app/inyeccion/inyeccion.dart' as di;
import '../../../../config/secretos.dart';
import '../../../../shared/utilidades/formato/comun/textos/l10n_servicio.dart';
import '../../../backend_go/nucleo/base/contrato_backend.dart';
import '../../../cache/almacenes/sistema/cache_ajustes.dart';
import '../youtube/oauth_youtube_app.dart';
import '../../proveedores/base/servicio_credenciales_proveedor.dart';

part '../youtube/oauth_youtube_nativo.dart';
part 'servicio_oauth_youtube_helpers.dart';

/// Resultado de conectar YouTube. El éxito se lee por [ok], nunca comparando
/// el [mensaje]: ese texto se traduce y cambia, así que compararlo por
/// `startsWith`/`contains` se rompe al cambiar de idioma o al retocar el copy.
class ResultadoConexionYouTube {
  final bool ok;
  final String mensaje;

  const ResultadoConexionYouTube({required this.ok, required this.mensaje});

  const ResultadoConexionYouTube.fallo(this.mensaje) : ok = false;
}

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
  /// [ResultadoConexionYouTube] con el éxito y el mensaje legible.
  Future<ResultadoConexionYouTube> conectar([BuildContext? context]) async {
    if (_webviewPrimero()) {
      if (context != null && context.mounted) {
        return _conectarInAppConReintento(this, context);
      }
      return ResultadoConexionYouTube.fallo(L10n.actual.oauth.sinDispositivo);
    }

    if (_soportaNativo()) {
      try {
        return await _conectarNativo(this);
      } on _ExcepcionCanceladoUsuario {
        return ResultadoConexionYouTube.fallo(L10n.actual.oauth.cancelada);
      } catch (e) {
        debugPrint('YouTube OAuth: flujo nativo falló ($e)');
      }
    } else {
      debugPrint('YouTube OAuth: sin flujo nativo en esta plataforma');
    }

    if (context != null && context.mounted) {
      return _conectarInAppConReintento(this, context);
    }

    return ResultadoConexionYouTube.fallo(L10n.actual.oauth.sinDispositivo);
  }
}
