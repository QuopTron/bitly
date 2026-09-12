// ─────────────────────────────────────────────────────────────
// importacion_biblioteca.dart — Importa la música PROPIA del
// usuario (compras de Amazon, archivos de iTunes Match, FLAC
// sueltos): escanea la carpeta en Go y guarda cada canción en el
// historial de descargas para que aparezca en Mi Espacio.
// Se conecta con: backend_go (importarBibliotecaLocal) +
// CacheDescargas (guardarTrackDescargado) + CubitDescargas.
// Parte del flujo: Ajustes → Más → Importar carpeta.
// ─────────────────────────────────────────────────────────────

import '../../app/inyeccion.dart';
import '../../estado/cubit_descargas.dart';
import '../backend_go/contrato_backend.dart';
import '../cache/cache_descargas.dart';

/// Resumen de una importación, listo para mostrar en la UI.
class ResultadoImportacion {
  /// Cuántos archivos de audio se encontraron en la carpeta.
  final int archivos;

  /// Cuántos traían ISRC (los que entran al dedupe).
  final int conIsrc;

  /// Cuántos quedaron guardados en Mi Espacio.
  final int guardados;

  const ResultadoImportacion({
    required this.archivos,
    required this.conIsrc,
    required this.guardados,
  });
}

/// Importa música local y la deja visible en Mi Espacio.
class ImportacionBiblioteca {
  final BackendService _backend;
  final CacheDescargas _descargas;

  ImportacionBiblioteca({BackendService? backend, CacheDescargas? descargas})
      : _backend = backend ?? sl<BackendService>(),
        _descargas = descargas ?? sl<CacheDescargas>();

  /// Escanea [directorio] en Go y guarda cada canción en la biblioteca.
  /// Al terminar refresca el cubit de descargas para que Mi Espacio la liste.
  Future<ResultadoImportacion> importar(String directorio) async {
    final respuesta = await _backend.importarBibliotecaLocal(
      directorio: directorio,
    );
    final entradas = respuesta['entradas'];
    var guardados = 0;

    if (entradas is List) {
      for (final entrada in entradas) {
        if (entrada is Map && await _guardarEntrada(entrada)) guardados++;
      }
    }

    // Refresca Mi Espacio con lo recién importado.
    try {
      await sl<CubitDescargas>().initialize();
    } catch (_) {}

    return ResultadoImportacion(
      archivos: _entero(respuesta['archivos']),
      conIsrc: _entero(respuesta['conIsrc']),
      guardados: guardados,
    );
  }

  /// Guarda una entrada escaneada como una "descarga local".
  /// El id se deriva del ISRC (o de la ruta) para que reimportar la misma
  /// carpeta sea idempotente y no duplique filas.
  Future<bool> _guardarEntrada(Map<dynamic, dynamic> entrada) async {
    final ruta = entrada['filePath']?.toString() ?? '';
    final meta = entrada['metadata'];
    if (ruta.isEmpty || meta is! Map) return false;

    final titulo = meta['title']?.toString() ?? '';
    if (titulo.isEmpty) return false;

    final artista = meta['artist']?.toString() ?? '';
    final isrc = meta['isrc']?.toString() ?? '';
    await _descargas.guardarTrackDescargado(
      id: isrc.isNotEmpty ? 'local:$isrc' : 'local:$ruta',
      trackName: titulo,
      artistName: artista.isEmpty ? 'Desconocido' : artista,
      albumName: meta['album']?.toString() ?? '',
      isrc: isrc,
      filePath: ruta,
      service: 'local',
      duration: _entero(meta['durationMs']),
      providerSource: 'local',
    );
    return true;
  }

  int _entero(dynamic valor) {
    if (valor is num) return valor.toInt();
    return int.tryParse(valor?.toString() ?? '') ?? 0;
  }
}
