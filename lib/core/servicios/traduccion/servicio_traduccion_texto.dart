// ─────────────────────────────────────────────────────────────
// servicio_traduccion_texto.dart — Traduce textos CORTOS y sueltos
// (título, artista, álbum) al idioma que pida el usuario.
//
// Por qué existe aparte de servicio_traduccion_letras: ese está hecho
// para la letra del karaoke —mide líneas, guarda en la base por canción
// y alinea para que el barrido no se desfase—. Acá no hay alineación ni
// guardado: son pocos textos, se piden UNA vez y se cachean en memoria
// para el resto de la sesión.
//
// Cómo se pide: los textos van juntos, separados por \n, en UNA sola
// petición (el mismo motivo que en las letras: pedir de a uno dispara
// una ráfaga que el traductor gratuito bloquea). Si la respuesta no
// devuelve la misma cantidad de textos, se descarta la traducción
// entera: mostrar el título de una canción y el álbum de otra mezclados
// sería peor que no traducir.
//
// Se conecta con: shared/widgets/modales/info_cancion/ (lo consume) y
// se registra en app/inyeccion_estado.dart.
// Parte del flujo: info de canción → traducir datos.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:translator/translator.dart';

/// Función de traducción inyectable (permite testear sin red).
typedef TraductorTextoFn =
    Future<({String texto, String idiomaOrigen})> Function(
      String texto,
      String destino,
    );

/// Traduce textos cortos, en bloque y con caché de sesión.
class ServicioTraduccionTexto {
  ServicioTraduccionTexto({TraductorTextoFn? traductor})
    : _traducir = traductor ?? _traducirConGoogle;

  final TraductorTextoFn _traducir;

  /// Memoria por (destino, huella del conjunto de textos): volver a abrir la
  /// misma canción no vuelve a pedir nada, y cambiar de idioma y volver
  /// tampoco.
  final Map<String, ({List<String> textos, String idiomaOrigen})> _memo = {};

  /// Traduce [textos] a [destino], devolviendo la MISMA cantidad (las
  /// entradas vacías quedan vacías). null si no se pudo traducir.
  Future<({List<String> textos, String idiomaOrigen})?> traducir({
    required List<String> textos,
    required String destino,
  }) async {
    final indices = <int>[];
    final utiles = <String>[];
    for (var i = 0; i < textos.length; i++) {
      if (textos[i].trim().isNotEmpty) {
        indices.add(i);
        utiles.add(textos[i]);
      }
    }
    if (utiles.isEmpty) return null;

    final unido = utiles.join('\n');
    final clave =
        '$destino|${md5.convert(utf8.encode(unido)).toString().substring(0, 16)}';
    final memo = _memo[clave];
    if (memo != null) return memo;

    try {
      final res = await _traducir(unido, destino);
      var partes = res.texto.split('\n');
      if (partes.length != utiles.length) {
        // El traductor a veces colapsa las líneas vacías: si la cuenta aún
        // cuadra, se usa igual; si no, se descarta (ver cabecera).
        partes = partes.where((p) => p.trim().isNotEmpty).toList();
        if (partes.length != utiles.length) return null;
      }
      final salida = List<String>.filled(textos.length, '');
      for (var i = 0; i < indices.length; i++) {
        salida[indices[i]] = partes[i];
      }
      final resultado = (textos: salida, idiomaOrigen: res.idiomaOrigen);
      _memo[clave] = resultado;
      return resultado;
    } catch (e) {
      _log(e);
      return null;
    }
  }

  /// Implementación real contra el traductor de Google (paquete `translator`).
  /// Sin `from`: el idioma de origen lo detecta el servicio.
  static Future<({String texto, String idiomaOrigen})> _traducirConGoogle(
    String texto,
    String destino,
  ) async {
    final res = await GoogleTranslator().translate(texto, to: destino);
    return (texto: res.text, idiomaOrigen: res.sourceLanguage.name);
  }

  /// Log aislado para no depender de Flutter (el servicio se testea sin red).
  static void _log(Object e) {
    // ignore: avoid_print
    print('[traduccion-info] $e');
  }
}
