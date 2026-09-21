// ─────────────────────────────────────────────────────────────
// cache_traducciones.dart — Guarda en la BASE las traducciones de
// la letra ya pedidas, para no volver a traducir la misma canción
// cada vez que se abre el karaoke.
//
// Por qué en el JsonCache genérico: ya es una tabla de la base (clave
// → JSON) con su DAO, así que guardar acá no necesita migración de
// esquema ni tocar la tabla de nadie. El prefijo propio
// (`letra:traduccion:`) lo mantiene aislado: la invalidación de otras
// cachés va por prefijo ('detail:', 'library:') y no lo toca.
//
// La CLAVE lleva la huella de la letra original: si la fuente devuelve
// otra versión de la letra, la traducción vieja no se reusa (mostraría
// la traducción de otro texto, desalineada del karaoke).
//
// Se conecta con: base_datos (CacheDao) + servicio_traduccion_letras.
// Parte del flujo: reproductor → letras (traducción).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../../../../base_datos/app_database.dart';
import '../../../../base_datos/daos/sistema/cache/cache_dao.dart';

import 'package:flutter/foundation.dart';
/// Traducción ya guardada: el idioma detectado y las líneas traducidas
/// (null donde la línea original estaba vacía).
typedef TraduccionGuardada = ({String idiomaOrigen, List<String?> lineas});

/// Contrato del almacén de traducciones. Existe como interfaz para que el
/// servicio se pueda testear sin base de datos.
abstract class AlmacenTraducciones {
  Future<TraduccionGuardada?> leer({
    required String cancion,
    required String destino,
    required String huella,
  });

  Future<void> guardar({
    required String cancion,
    required String destino,
    required String huella,
    required String idiomaOrigen,
    required List<String?> lineas,
  });
}

/// Traducciones de letras persistidas en el JsonCache.
class CacheTraducciones implements AlmacenTraducciones {
  CacheTraducciones(AppDatabase db) : _dao = CacheDao(db);

  final CacheDao _dao;

  /// Prefijo de TODAS las claves de este almacén (ver `borrarDeCancion`).
  static const prefijo = 'letra:traduccion';

  /// Clave de una traducción: [cancion] es la identidad del track (ISRC cuando
  /// lo hay, si no su id) y [huella] la de la letra traducida.
  static String clave({
    required String cancion,
    required String destino,
    required String huella,
  }) => '$prefijo:$cancion:$destino:$huella';

  @override
  Future<TraduccionGuardada?> leer({
    required String cancion,
    required String destino,
    required String huella,
  }) async {
    try {
      final crudo = await _dao.get(
        clave(cancion: cancion, destino: destino, huella: huella),
      );
      if (crudo == null || crudo.isEmpty) return null;
      final data = jsonDecode(crudo);
      if (data is! Map) return null;
      final lineas = data['lineas'];
      if (lineas is! List) return null;
      return (
        idiomaOrigen: (data['idioma'] ?? '') as String,
        lineas: [for (final l in lineas) l as String?],
      );
    } catch (e) {
      debugPrint('[CacheTraducciones] $e');
      // Una fila vieja o corrupta no puede romper la traducción: se ignora y
      // se vuelve a pedir al traductor.
      return null;
    }
  }

  @override
  Future<void> guardar({
    required String cancion,
    required String destino,
    required String huella,
    required String idiomaOrigen,
    required List<String?> lineas,
  }) async {
    try {
      await _dao.set(
        clave(cancion: cancion, destino: destino, huella: huella),
        jsonEncode({'idioma': idiomaOrigen, 'lineas': lineas}),
      );
    } catch (e) {
      debugPrint('[CacheTraducciones] $e');
      // Best-effort: si no se pudo guardar, la traducción igual se muestra.
    }
  }
}
