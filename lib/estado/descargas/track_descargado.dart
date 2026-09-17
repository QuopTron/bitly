// ─────────────────────────────────────────────────────────────
// track_descargado.dart — Decisión PURA de si una canción ya está
// descargada: por su clave exacta (`track_<id>_<fuente>`) o por ISRC,
// que es la misma grabación bajada desde OTRA extensión.
//
// Por qué existe: los detalles de álbum/playlist contaban solo la
// clave exacta, así que una canción bajada con otra fuente no se
// contaba y el álbum mostraba "0 de 17" aunque el archivo estuviera
// en disco. El ISRC es identidad exacta (no como el nombre, que puede
// coincidir entre dos versiones distintas), así que no da falsos
// positivos.
//
// Se conecta con: descargas_acceso.dart (lo expone al cubit) y su test.
// Parte del flujo: descargas (detalles de álbum/playlist).
// ─────────────────────────────────────────────────────────────

import '../../core/cache/estado/estado_descarga.dart';
import '../../core/servicios/utilidades/huella_item.dart';
import '../../core/servicios/utilidades/utilidades_id.dart';

/// ¿La canción [trackId] ya está descargada con la fuente [source], o con
/// otra fuente que llevaba el mismo [isrc]?
bool trackDescargadoEnEstado({
  required Map<String, DatosEstadoDescarga> descargas,
  required Set<String> huellasDescargadas,
  required String trackId,
  String source = '',
  String? isrc,
}) {
  if (trackId.isEmpty) return false;
  final normId = normalizarId(trackId);
  if (descargas['track_${normId}_$source']?.estado ==
      EstadoDescarga.completado) {
    return true;
  }
  final code = (isrc ?? '').trim();
  if (code.isEmpty) return false;
  return huellasDescargadas.contains(huellaIsrc(code));
}
