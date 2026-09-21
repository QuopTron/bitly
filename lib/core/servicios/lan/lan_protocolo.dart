// ─────────────────────────────────────────────────────────────
// lan_protocolo.dart — Lo que se dicen dos aparatos por la red local, sin
// tocar sockets: el anuncio de descubrimiento, el permiso por token y las
// rutas de archivo.
//
// Todo es PURO (texto y listas entran, texto y listas salen): así la parte
// delicada del vínculo —comparar tokens y no dejar que un pedido se escape
// del directorio de descargas— se puede probar sin levantar una red.
//
// El vínculo no tiene servidor: cada app anuncia por difusión y levanta su
// propio mini-servidor en la red local. El token es lo único que autoriza a
// pedir el catálogo y los archivos, y se guarda recién cuando los dos
// aparatos se aceptan.
//
// Se conecta con: lan_modelos (los datos) + servicio_lan (los sockets).
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'lan_modelos.dart';

/// Puerto fijo de la difusión: todos los aparatos escuchan acá para
/// encontrarse, sin saber la IP de antemano.
const int puertoDescubrimiento = 45777;

/// Versión del protocolo: si cambia, un aparato viejo no se mezcla con uno
/// nuevo en vez de hablar idiomas distintos a medias.
const int versionLan = 1;

/// Nombre del archivo del anuncio por difusión.
const String nombreAnuncio = 'bitly';

/// El anuncio que sale por difusión cada pocos segundos.
String armarAnuncio({
  required String id,
  required String nombre,
  required int puerto,
}) => jsonEncode({
  'v': versionLan,
  'app': nombreAnuncio,
  'id': id,
  'nombre': nombre,
  'puerto': puerto,
});

/// Lee un anuncio. Devuelve null si el texto no es nuestro (otro programa en
/// el mismo puerto, versión distinta, o JSON roto) o si viene del propio
/// aparato ([idPropio]), que también se escucha a sí mismo.
ParLan? leerAnuncio(String crudo, {required String idPropio}) {
  try {
    final parsed = jsonDecode(crudo);
    if (parsed is! Map<String, dynamic>) return null;
    if (parsed['app'] != nombreAnuncio) return null;
    if ((parsed['v'] as num?)?.toInt() != versionLan) return null;
    final id = parsed['id'] as String? ?? '';
    final puerto = (parsed['puerto'] as num?)?.toInt() ?? 0;
    if (id.isEmpty || id == idPropio || puerto <= 0 || puerto > 65535) {
      return null;
    }
    return ParLan(
      id: id,
      nombre: parsed['nombre'] as String? ?? '',
      host: '',
      puerto: puerto,
    );
  } catch (_) {
    // Un anuncio ilegible es normal en una red con más gente: se ignora.
    return null;
  }
}

/// ¿El token que mandó el otro aparato es el que corresponde?
///
/// Se compara sin cortar en la primera diferencia: si el tiempo de respuesta
/// dependiera de cuántos caracteres acertó, un aparato ajeno podría adivinar
/// el token letra por letra.
bool tokenValido(String? recibido, String esperado) {
  if (esperado.isEmpty) return false;
  final otro = recibido ?? '';
  if (otro.length != esperado.length) return false;
  var diferencia = 0;
  for (var i = 0; i < esperado.length; i++) {
    diferencia |= otro.codeUnitAt(i) ^ esperado.codeUnitAt(i);
  }
  return diferencia == 0;
}

/// El nombre de archivo a usar para un ítem, ya sin ninguna ruta adentro.
///
/// El servidor entrega SOLO el nombre del archivo, nunca una ruta: así un
/// pedido con `../` o con barras no puede escribir afuera de la carpeta de
/// descargas del que recibe.
String? nombreArchivoSeguro(String? id) {
  if (id == null) return null;
  final limpio = id.trim();
  if (limpio.isEmpty || limpio.length > 120) return null;
  if (limpio.contains('..') || limpio.contains('/') || limpio.contains(r'\')) {
    return null;
  }
  // Solo letras, números, guiones y puntos: nada de espacios raros ni
  // caracteres de control.
  if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(limpio)) return null;
  return limpio;
}

/// De una lista de canciones del otro aparato, las que a este le faltan.
///
/// La identidad se decide por [CancionLan.clave] (ISRC, o nombre+artista):
/// comparar por id de descarga no sirve porque cada aparato guarda los suyos.
List<CancionLan> faltantesPara(
  List<CancionLan> remotas,
  Set<String> clavesLocales,
) => remotas
    .where((c) => c.id.isNotEmpty && !clavesLocales.contains(c.clave))
    .toList(growable: false);
