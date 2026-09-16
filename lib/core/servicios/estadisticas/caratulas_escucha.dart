// ─────────────────────────────────────────────────────────────
// caratulas_escucha.dart — Resuelve la carátula LOCAL de las filas del
// detalle de estadísticas. El backend busca la portada ya descargada
// (por id, ISRC o nombre+artista); acá se pide de a poco, en paralelo
// acotado, se cachea en memoria y se devuelve un mapa id → ruta.
//
// Por qué acotado: son cientos de filas posibles y cada consulta cruza
// el puente a Go. Se resuelven solo las VISIBLES (las que el usuario
// mira) y se recuerda el resultado para que reabrir el modal no vuelva
// a pedirlas.
// Se conecta con: settings_estadisticas_detalle.dart (lo usa) +
// BackendService (getCoverPathForTrack).
// Parte del flujo: Ajustes → Estadísticas → detalle.
// ─────────────────────────────────────────────────────────────

import '../../backend_go/nucleo/contrato_backend.dart';
import '../../../app/inyeccion.dart' as di;
import 'filtro_escucha.dart';

/// Caché en memoria de carátulas por id de ítem del historial.
class CaratulasEscucha {
  final Map<String, String> _cache = {};

  /// Cuántas filas se resuelven como máximo por llamada: el detalle muestra
  /// el top, no miles de ítems.
  static const int _maximoPorLlamada = 40;

  /// Consultas simultáneas al puente: de a 8 para no saturar el canal.
  static const int _concurrencia = 8;

  /// Devuelve id → ruta local de carátula para [filas]. Las que no tienen
  /// portada simplemente no aparecen en el mapa.
  Future<Map<String, String>> resolver(List<FilaEscucha> filas) async {
    final pendientes = <FilaEscucha>[];
    final resueltas = <String, String>{};
    for (final fila in filas) {
      if (fila.id.isEmpty) continue;
      final cacheada = _cache[fila.id];
      if (cacheada != null) {
        if (cacheada.isNotEmpty) resueltas[fila.id] = cacheada;
        continue;
      }
      pendientes.add(fila);
      if (pendientes.length >= _maximoPorLlamada) break;
    }
    if (pendientes.isEmpty) return resueltas;

    final backend = di.sl<BackendService>();
    for (var i = 0; i < pendientes.length; i += _concurrencia) {
      final tanda = pendientes.skip(i).take(_concurrencia);
      final rutas = await Future.wait(tanda.map((f) => _una(backend, f)));
      for (var j = 0; j < rutas.length; j++) {
        final fila = pendientes[i + j];
        final ruta = rutas[j];
        _cache[fila.id] = ruta ?? ''; // '' = ya se buscó y no hay
        if (ruta != null && ruta.isNotEmpty) resueltas[fila.id] = ruta;
      }
    }
    return resueltas;
  }

  /// Consulta UNA carátula. Nunca lanza: sin portada devuelve null.
  Future<String?> _una(BackendService backend, FilaEscucha fila) async {
    try {
      return await backend.getCoverPathForTrack(
        trackId: fila.id,
        trackName: fila.nombre,
        artistName: fila.artista,
      );
    } catch (_) {
      return null;
    }
  }
}
