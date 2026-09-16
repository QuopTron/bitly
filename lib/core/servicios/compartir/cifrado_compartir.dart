// ─────────────────────────────────────────────────────────────
// cifrado_compartir.dart — Cifra y autentica el contenido del enlace
// que se comparte por WhatsApp/Telegram, SIN servidor.
//
// Qué hace: el enlace lleva los datos del ítem (ISRC, nombre, artista,
// álbum, carátula y quién lo manda) cifrados y firmados dentro del
// propio texto. Bitly los descifra al abrirlo, así que se reconoce la
// canción sin pasar por ninguna API ni backend.
//
// Cómo: cifrado de flujo con HMAC-SHA256 como generador de keystream
// (nonce aleatorio por enlace + contador por bloque) y un MAC de 8
// bytes para que un enlace manipulado se descarte en vez de mostrar
// basura. Solo usa `crypto`, que ya es dependencia de la app.
//
// Envelope (bytes): [versión 1B][nonce 8B][mac 8B][cifrado ...B]
//
// Se conecta con: servicio_compartir (al crear) y servicio_deep_link
// (al leer).
// Parte del flujo: compartir canción → enlace → abrir en el otro celu.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Cifrado simétrico compacto para los enlaces compartidos.
class CifradoCompartir {
  CifradoCompartir._();

  /// Versión del formato; viaja en el primer byte para poder cambiarlo
  /// sin romper los enlaces viejos.
  static const version = 1;

  /// Semilla de la app. No es un secreto distribuido (no hay servidor que lo
  /// reparta): su objetivo es que el enlace no sea legible ni reescribible a
  /// mano, que es lo que aporta el "cifrado" pedido.
  static const _semilla = 'bitly-compartir-v1';

  static final List<int> _claveFlujo =
      sha256.convert(utf8.encode('$_semilla|flujo')).bytes;
  static final List<int> _claveMac =
      sha256.convert(utf8.encode('$_semilla|autenticidad')).bytes;

  /// Cifra [texto] y lo devuelve como base64url sin relleno.
  static String cifrar(String texto) {
    final datos = utf8.encode(texto);
    final nonce = _nonce(8);
    final flujo = _flujo(nonce, datos.length);
    final cifrado = Uint8List(datos.length);
    for (var i = 0; i < datos.length; i++) {
      cifrado[i] = datos[i] ^ flujo[i];
    }
    final mac = _mac(nonce, cifrado).sublist(0, 8);
    final salida = BytesBuilder(copy: false)
      ..addByte(version)
      ..add(nonce)
      ..add(mac)
      ..add(cifrado);
    return base64Url.encode(salida.toBytes()).replaceAll('=', '');
  }

  /// Descifra un enlace creado por [cifrar]. null si está corrupto,
  /// manipulado o no es de este formato.
  static String? descifrar(String texto) {
    try {
      final bytes = _desdeBase64(texto);
      if (bytes.length < 1 + 8 + 8 + 1) return null;
      if (bytes[0] != version) return null;
      final nonce = bytes.sublist(1, 9);
      final mac = bytes.sublist(9, 17);
      final cifrado = bytes.sublist(17);
      if (!_iguales(mac, _mac(nonce, cifrado).sublist(0, 8))) return null;
      final flujo = _flujo(nonce, cifrado.length);
      final claro = Uint8List(cifrado.length);
      for (var i = 0; i < cifrado.length; i++) {
        claro[i] = cifrado[i] ^ flujo[i];
      }
      return utf8.decode(claro);
    } catch (_) {
      return null;
    }
  }

  /// Keystream: HMAC(clave, nonce || contador) por cada bloque de 32 bytes.
  static List<int> _flujo(List<int> nonce, int largo) {
    final salida = Uint8List(largo);
    var escritos = 0;
    var contador = 0;
    while (escritos < largo) {
      final bloque = Hmac(sha256, _claveFlujo).convert([
        ...nonce,
        (contador >> 24) & 0xff,
        (contador >> 16) & 0xff,
        (contador >> 8) & 0xff,
        contador & 0xff,
      ]).bytes;
      final copiar = min(bloque.length, largo - escritos);
      salida.setRange(escritos, escritos + copiar, bloque);
      escritos += copiar;
      contador++;
    }
    return salida;
  }

  /// MAC del contenido: garantiza que nadie edite el payload a mano.
  static List<int> _mac(List<int> nonce, List<int> cifrado) =>
      Hmac(sha256, _claveMac).convert([...nonce, ...cifrado]).bytes;

  /// Bytes aleatorios criptográficamente seguros.
  static List<int> _nonce(int largo) {
    final rnd = Random.secure();
    return List<int>.generate(largo, (_) => rnd.nextInt(256));
  }

  /// Decodifica base64url aunque venga sin relleno o con el alfabeto normal.
  static Uint8List _desdeBase64(String texto) {
    final limpio = texto.trim().replaceAll('-', '+').replaceAll('_', '/');
    final pad = (4 - limpio.length % 4) % 4;
    return base64.decode(limpio + '=' * pad);
  }

  /// Comparación en tiempo constante (evita filtrar el MAC byte a byte).
  static bool _iguales(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var dif = 0;
    for (var i = 0; i < a.length; i++) {
      dif |= a[i] ^ b[i];
    }
    return dif == 0;
  }
}
