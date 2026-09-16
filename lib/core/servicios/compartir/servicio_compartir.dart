// ─────────────────────────────────────────────────────────────
// servicio_compartir.dart — Comparte una canción/álbum/playlist como
// un enlace de Bitly que lleva los datos cifrados dentro.
//
// Qué hace: cuando el usuario toca "Compartir", arma
// `https://<host>/open?s=<payload cifrado>` (el payload incluye el
// ISRC, el nombre, la carátula y SU nombre) y abre la hoja del
// sistema para mandarlo por WhatsApp, Telegram, etc.
//
// Sin servidor: el enlace no apunta a ninguna web nuestra; solo
// funciona para quien tenga Bitly instalado, que lo reconoce al abrir.
//
// Se conecta con: cifrado_compartir + datos_compartido + CacheAjustes
// (el nombre del usuario) + share_plus.
// Parte del flujo: compartir canción → enlace → abrir en el otro celu.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../../../app/inyeccion.dart' as di;
import '../../backend_go/nucleo/contrato_backend.dart';
import '../../cache/almacenes/cache_ajustes.dart';
import '../../modelos/feed/item_feed.dart';
import '../../modelos/resultado_enlace.dart';
import 'cifrado_compartir.dart';
import 'datos_compartido.dart';

part 'servicio_compartir_busqueda.dart';

/// Armado del enlace compartido y disparo de la hoja de compartir.
class ServicioCompartir {
  ServicioCompartir._();
  static final ServicioCompartir instance = ServicioCompartir._();

  /// Host y ruta del enlace compartido. Este host es el que tiene que estar
  /// declarado en el manifest de Android (App Link verificado con
  /// assetlinks.json) y en el entitlement de iOS (Universal Link con
  /// apple-app-site-association), así el enlace abre la app DIRECTO, sin
  /// selector ni navegador. Los dos archivos viven en la carpeta `public/`
  /// del sitio (repo bitly-site) y se publican en
  /// `https://<host>/.well-known/`. Si cambia el dominio, se cambia acá y en
  /// esos dos archivos; también se puede fijar sin tocar código:
  /// --dart-define=BITLY_LINK_HOST=mi-dominio
  static const host = String.fromEnvironment(
    'BITLY_LINK_HOST',
    defaultValue: 'bitly-site.pages.dev',
  );
  static const ruta = '/open';

  /// Hosts que el lector acepta: el configurado, los históricos (enlaces ya
  /// mandados por WhatsApp) y `open` del esquema propio `bitly://open`.
  static const _hostsValidos = ['bitly-site.pages.dev', 'bitly.app', 'open'];

  /// Convierte un compartido (descifrado) en una canción reproducible.
  /// Lo usan el botón de la carta y la lista de Ajustes → Compartidos.
  Future<ResultadoEnlace?> resolver(DatosCompartido datos) =>
      _resolverCompartido(datos);

  /// Comparte [item] con el enlace cifrado.
  Future<void> compartir(ItemFeed item, {String? texto}) async {
    final datos = DatosCompartido.desdeItem(item, emisor: await _emisor());
    final enlace = construirEnlace(datos);
    final titulo = texto ?? _tituloLegible(item);
    await SharePlus.instance.share(
      ShareParams(text: '$titulo\n$enlace'),
    );
  }

  /// Enlace listo para pegar: host + payload cifrado.
  String construirEnlace(DatosCompartido datos) {
    final payload =
        CifradoCompartir.cifrar(jsonEncode(datos.aJson()));
    return 'https://$host$ruta?s=$payload';
  }

  /// Lee un enlace de Bitly y devuelve los datos descifrados.
  /// null si el enlace no es nuestro o no se puede autenticar.
  DatosCompartido? leerEnlace(String url) {
    try {
      final uri = Uri.parse(url.trim());
      // Acepta las formas declaradas en Android/iOS: el host configurado
      // (https://<host>/open?s=...) y el esquema propio (bitly://open?s=...).
      final hostValido =
          uri.host == host || _hostsValidos.contains(uri.host);
      if (!hostValido) return null;
      final payload = uri.queryParameters['s'];
      if (payload == null || payload.isEmpty) return null;
      final claro = CifradoCompartir.descifrar(payload);
      if (claro == null) return null;
      final json = jsonDecode(claro);
      if (json is! Map) return null;
      final datos = DatosCompartido.desdeJson(Map<String, dynamic>.from(json));
      return datos.valido ? datos : null;
    } catch (_) {
      return null;
    }
  }

  /// ¿Este texto trae un enlace de Bitly? (para no tratarlo como URL de otra
  /// fuente y mandarlo al backend sin necesidad)
  bool esEnlaceBitly(String texto) => leerEnlace(texto) != null;

  /// Texto visible: la canción y el artista; el enlace lo agrega [compartir].
  String _tituloLegible(ItemFeed item) {
    final artista = item.artists?.trim() ?? '';
    final emoji = switch (item.type) {
      'album' => '💿',
      'playlist' => '📃',
      'artist' => '🎤',
      _ => '🎵',
    };
    if (item.type == 'track' && artista.isNotEmpty) {
      return '$emoji ${item.name} — $artista';
    }
    return '$emoji ${item.name}';
  }

  /// Nombre con el que firma el enlace: el del setup y, si no hay, el de
  /// Soulseek. Ambos ya existen; no se le pide nada nuevo al usuario.
  Future<String> _emisor() async {
    try {
      final cache = di.sl<CacheAjustes>();
      final setup = await cache.cargarDatosSetup();
      final nombre = (setup?.username ?? '').trim();
      if (nombre.isNotEmpty) return nombre;
      final soulseek = (await cache.getAjuste('soulseek_usuario') ?? '').trim();
      return soulseek;
    } catch (_) {
      return '';
    }
  }
}
