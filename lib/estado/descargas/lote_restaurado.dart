// ─────────────────────────────────────────────────────────────
// lote_restaurado.dart — Decisión PURA de cómo se restaura un lote
// (álbum/playlist) leído de la base: "completado" SOLO si TODOS sus
// tracks están de verdad descargados; si falta cualquiera queda
// parcial con su progreso.
//
// Por qué existe: la fila del lote se escribe al EMPEZAR la descarga
// (para que sobreviva un reinicio) y el cargador la levantaba como
// completada sin mirar nada más, así que un álbum con 2 de 17
// canciones bajadas aparecía con el tilde verde de "descargado", el
// botón de descarga apagado y el álbum listado en Mi Espacio como
// si estuviera entero.
//
// Se conecta con: descargas_carga_lotes.dart (lo usa) y su test.
// Parte del flujo: descargas (restauración del historial de lotes).
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import '../../core/cache/estado/estado_descarga.dart';
import '../../core/servicios/utilidades/utilidades_id.dart';

/// Resultado de verificar un lote guardado: cuántos tracks están de
/// verdad en disco y si con eso el lote queda completo.
typedef LoteRestaurado = ({
  bool completo,
  double progreso,
  int listos,
  int total,
});

/// ¿Es una clave que puede ser un lote de colección (álbum o playlist)?
/// La cola de singles persiste su key interna ('_singles'), que no es
/// ninguna colección y no debe restaurarse ni listarse.
bool esClaveDeColeccion(String batchKey) =>
    batchKey.startsWith('album_') || batchKey.startsWith('playlist_');

/// State keys (`track_<id>_<fuente>`) guardadas en el `track_ids` de un
/// lote. Acepta el formato viejo (array de strings) y el enriquecido
/// (array de `{id, name, artist, cover}`). Un JSON ilegible da lista vacía.
List<String> idsStateKeysDeLote(String trackIdsJson) {
  if (trackIdsJson.isEmpty || trackIdsJson == '[]') return const [];
  try {
    final lista = jsonDecode(trackIdsJson) as List;
    final ids = <String>[];
    for (final e in lista) {
      if (e is String) {
        if (e.isNotEmpty) ids.add(e);
      } else if (e is Map) {
        final id = (e['id'] ?? '').toString();
        if (id.isNotEmpty) ids.add(id);
      }
    }
    return ids;
  } catch (_) {
    return const [];
  }
}

/// Id normalizado de una state key `track_<id>_<fuente>`.
///
/// Corta con la fuente CONOCIDA del lote en vez de buscar el último '_':
/// hay ids que lo traen (p.ej. los de Internet Archive), y cortar por el
/// último '_' devolvería un id truncado que nunca coincide con el
/// historial → el lote quedaría "parcial" para siempre.
String idDeStateKey(String stateKey, String source) {
  const prefijo = 'track_';
  if (!stateKey.startsWith(prefijo)) return normalizarId(stateKey);
  var resto = stateKey.substring(prefijo.length);
  final sufijo = '_$source';
  if (source.isNotEmpty && resto.endsWith(sufijo)) {
    resto = resto.substring(0, resto.length - sufijo.length);
  } else {
    final corte = resto.lastIndexOf('_');
    if (corte > 0) resto = resto.substring(0, corte);
  }
  return normalizarId(resto);
}

/// Verifica [stateKeys] con [estaDescargado] y dice si el lote está
/// completo. Un lote sin tracks registrados NUNCA se da por completo:
/// sin ids no hay nada que verificar y un verde falso es peor que un
/// lote sin estado.
LoteRestaurado evaluarLoteRestaurado(
  List<String> stateKeys,
  bool Function(String stateKey) estaDescargado,
) {
  final total = stateKeys.length;
  if (total == 0) {
    return (completo: false, progreso: 0.0, listos: 0, total: 0);
  }
  var listos = 0;
  for (final key in stateKeys) {
    if (estaDescargado(key)) listos++;
  }
  final completo = listos >= total;
  return (
    completo: completo,
    progreso: completo ? 1.0 : listos / total,
    listos: listos,
    total: total,
  );
}

/// Estado que corresponde a un lote restaurado: verde solo si está
/// completo; parcial queda en [EstadoDescarga.ninguno] con su progreso
/// (la UI muestra "2 / 17 descargado" y deja descargar el resto).
DatosEstadoDescarga estadoDeLoteRestaurado(LoteRestaurado r) => r.completo
    ? const DatosEstadoDescarga(
        estado: EstadoDescarga.completado,
        progreso: 1.0,
      )
    : DatosEstadoDescarga(estado: EstadoDescarga.ninguno, progreso: r.progreso);
