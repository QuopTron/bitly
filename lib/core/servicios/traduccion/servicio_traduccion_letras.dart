// ─────────────────────────────────────────────────────────────
// servicio_traduccion_letras.dart — Traduce la letra del karaoke
// al idioma que elija el usuario, detectando el idioma de origen.
//
// Cómo: una sola petición con TODAS las líneas separadas por \n (el
// traductor respeta los saltos, y pedir línea por línea disparaba una
// ráfaga de peticiones que el servicio gratuito bloquea). Si el
// resultado no devuelve la misma cantidad de líneas, se reintenta
// línea por línea, que es más lento pero nunca desalinea el karaoke.
//
// Antes de traducir se busca lo ya traducido: primero en la BASE
// (CacheTraducciones, así reabrir la canción —o abrir la app de nuevo—
// no vuelve a pedir nada) y después en memoria para el resto de la
// sesión. La clave incluye la huella de la letra original, así que una
// versión distinta de la letra no reusa una traducción vieja.
//
// Sobre la fuente: usa `translator` (scraping del traductor de Google,
// sin clave ni cuenta). Es un servicio gratuito y por eso puede fallar
// sin aviso; todas las fallas se devuelven como null para que la UI
// avise y el karaoke siga funcionando sin traducción.
//
// Se conecta con: features/reproductor/letras/hoja_letras_*.dart (lo
// consume) y se registra en app/inyeccion_estado.dart.
// Parte del flujo: reproductor → letras (traducción).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:translator/translator.dart';

import '../../cache/almacenes/cache_traducciones.dart';

/// Una línea ya traducida y el idioma del que se tradujo.
typedef ResultadoTraduccionLetras =
    ({
      /// Nombre del idioma de origen que detectó el traductor (\"English\", \"Spanish\").
      String idiomaOrigen,

      /// Texto traducido alineado con las líneas de entrada: null en las líneas
      /// vacías (los silencios del karaoke se quedan como están).
      List<String?> lineas,
    });

/// Función de traducción inyectable. Devuelve el texto traducido y el nombre
/// del idioma detectado. Existe como parámetro para poder testear el servicio
/// sin red.
typedef TraductorFn =
    Future<({String texto, String idiomaOrigen})> Function(
      String texto,
      String destino,
    );

/// Traduce la letra completa de una canción.
class ServicioTraduccionLetras {
  ServicioTraduccionLetras({TraductorFn? traductor, AlmacenTraducciones? cache})
    : _traducir = traductor ?? _traducirConGoogle,
      _cache = cache;

  final TraductorFn _traducir;

  /// Respaldo en la BASE (opcional): con él, reabrir la misma canción no vuelve
  /// a pedir la traducción ni aunque la app se haya cerrado.
  final AlmacenTraducciones? _cache;

  /// Caché en memoria por (huella de la letra, destino): volver al idioma
  /// anterior dentro de la misma sesión no toca ni la base ni la red.
  final Map<String, ResultadoTraduccionLetras> _memo = {};

  /// Traduce [lineas] a [destino]. Devuelve null si no se pudo (sin red, el
  /// servicio bloqueó la petición, o no hay letra que traducir).
  Future<ResultadoTraduccionLetras?> traducir({
    required List<String> lineas,
    required String destino,
    String? claveCancion,
  }) async {
    // Solo se traduce lo que tiene texto: las líneas vacías quedan vacías.
    final indices = <int>[];
    final textos = <String>[];
    for (var i = 0; i < lineas.length; i++) {
      if (lineas[i].trim().isNotEmpty) {
        indices.add(i);
        textos.add(lineas[i]);
      }
    }
    if (textos.isEmpty) return null;

    final unido = textos.join('\n');
    final huella = _huella(unido);

    // 1) Lo ya traducido para ESTA letra en la base (sobrevive al cierre de la
    //    app: es lo que evita volver a pedirla al reabrir la canción).
    if (_cache != null && claveCancion != null) {
      final guardada = await _cache.leer(
        cancion: claveCancion,
        destino: destino,
        huella: huella,
      );
      if (guardada != null) return guardada;
    }

    // 2) Memoria de esta sesión (misma letra e idioma, sin tocar la base).
    final claveMemoria = '$destino|$huella';
    final memo = _memo[claveMemoria];
    if (memo != null) return memo;

    final traducidas = await _traducirEnBloque(textos, unido, destino);
    if (traducidas == null) return null;

    final resultado = (
      idiomaOrigen: traducidas.idiomaOrigen,
      lineas: _alinear(lineas.length, indices, traducidas.partes),
    );
    _memo[claveMemoria] = resultado;
    if (_cache != null && claveCancion != null) {
      await _cache.guardar(
        cancion: claveCancion,
        destino: destino,
        huella: huella,
        idiomaOrigen: resultado.idiomaOrigen,
        lineas: resultado.lineas,
      );
    }
    return resultado;
  }

  /// Huella de la letra original: los primeros 16 caracteres del md5.
  ///
  /// Es md5 y no `hashCode` porque la clave se GUARDA en la base y tiene que
  /// valer igual en otra ejecución de la app (el `hashCode` de un String no
  /// tiene esa garantía). Y es recortado porque la clave solo necesita
  /// distinguir letras, no ser criptográfica.
  static String _huella(String texto) =>
      md5.convert(utf8.encode(texto)).toString().substring(0, 16);

  /// Traduce todo junto y, si el reparto de líneas no cuadra, una por una.
  Future<({List<String> partes, String idiomaOrigen})?> _traducirEnBloque(
    List<String> textos,
    String unido,
    String destino,
  ) async {
    try {
      final res = await _traducir(unido, destino);
      final partes = res.texto.split('\n');
      if (partes.length == textos.length) {
        return (partes: partes, idiomaOrigen: res.idiomaOrigen);
      }
      // El traductor puede colapsar o agregar saltos: si la cantidad de líneas
      // con texto coincide, se mapea así; si no, se cae al camino por línea.
      final conTexto = partes.where((p) => p.trim().isNotEmpty).toList();
      if (conTexto.length == textos.length) {
        return (partes: conTexto, idiomaOrigen: res.idiomaOrigen);
      }
    } catch (e) {
      debugPrintTraduccion(e);
    }
    return _traducirLineaPorLinea(textos, destino);
  }

  /// Camino lento (una petición por línea). Es el respaldo: mantiene la
  /// alineación aunque el traductor no respete los saltos de línea.
  Future<({List<String> partes, String idiomaOrigen})?> _traducirLineaPorLinea(
    List<String> textos,
    String destino,
  ) async {
    final partes = <String>[];
    var idioma = '';
    for (final texto in textos) {
      try {
        final res = await _traducir(texto, destino);
        if (idioma.isEmpty) idioma = res.idiomaOrigen;
        partes.add(res.texto);
      } catch (e) {
        debugPrintTraduccion(e);
        return null;
      }
    }
    if (partes.isEmpty) return null;
    return (partes: partes, idiomaOrigen: idioma);
  }

  /// Reparte [partes] (solo líneas con texto) en la lista completa, dejando
  /// null donde la letra original estaba vacía.
  List<String?> _alinear(int total, List<int> indices, List<String> partes) {
    final salida = List<String?>.filled(total, null);
    for (var i = 0; i < indices.length && i < partes.length; i++) {
      salida[indices[i]] = partes[i];
    }
    return salida;
  }

  /// Implementación real contra el traductor de Google (paquete `translator`).
  static Future<({String texto, String idiomaOrigen})> _traducirConGoogle(
    String texto,
    String destino,
  ) async {
    // Sin `from`: el traductor detecta el idioma de origen solo, que es lo que
    // se muestra en la cabecera del karaoke.
    final res = await GoogleTranslator().translate(texto, to: destino);
    return (texto: res.text, idiomaOrigen: res.sourceLanguage.name);
  }
}

/// Log de la traducción fallida (antes el catch quedaba mudo).
void debugPrintTraduccion(Object e) {
  // Se mantiene aislado para que el servicio no dependa de Flutter y pueda
  // testearse en un test de unidad puro.
  // ignore: avoid_print
  print('[traduccion] $e');
}
