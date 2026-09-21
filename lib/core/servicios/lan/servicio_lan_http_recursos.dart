// ─────────────────────────────────────────────────────────────
// servicio_lan_http_recursos.dart — PART de servicio_lan.dart: lo que este
// aparato ENTREGA a un aparato ya vinculado.
//
//   GET /lan/index        → el catálogo de lo descargado
//   GET /lan/file/<id>    → los bytes del audio
//   GET /lan/cover/<id>   → la carátula (si la tiene)
//   GET /lan/lyrics/<id>  → la letra, con el nombre que espera la app
//
// El id se valida como NOMBRE de archivo: un `../` o una barra no puede leer
// nada de afuera. Se separa del router para que cada archivo quede chico y
// para que la entrega (que toca el disco) viva en un solo lugar.
//
// Se conecta con: servicio_lan_http.dart (el router) + download_dao.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

part of 'servicio_lan.dart';

/// Entrega de catálogo y archivos.
extension RecursosLan on ServicioLan {
  /// Atiende un GET a /lan/... (ya autorizado por el router).
  Future<void> _servirRecurso(io.HttpRequest pedido, String ruta) async {
    if (ruta == '/lan/index') {
      final indice = await indicePropio();
      await _responderJson(pedido, io.HttpStatus.ok, 'canciones', {
        'canciones': [for (final c in indice) c.aJson()],
      });
      return;
    }
    if (ruta.startsWith('/lan/file/')) {
      await _servirAudio(pedido, _idDeRuta(ruta, '/lan/file/'));
      return;
    }
    if (ruta.startsWith('/lan/cover/')) {
      await _servirCover(pedido, _idDeRuta(ruta, '/lan/cover/'));
      return;
    }
    if (ruta.startsWith('/lan/lyrics/')) {
      await _servirLetra(pedido, _idDeRuta(ruta, '/lan/lyrics/'));
      return;
    }
    await _responderJson(pedido, io.HttpStatus.notFound, 'ruta');
  }

  /// El id pedido, ya validado (null si no es un nombre de archivo sano).
  String? _idDeRuta(String ruta, String prefijo) {
    final crudo = Uri.decodeComponent(ruta.substring(prefijo.length));
    return crudo.isEmpty ? null : nombreArchivoSeguro(crudo);
  }

  /// El audio de una descarga.
  Future<void> _servirAudio(io.HttpRequest pedido, String? id) async {
    final ruta = id == null ? null : await _db.downloadDao.getFilePathById(id);
    await _servirArchivo(pedido, ruta);
  }

  /// La carátula local de una descarga.
  Future<void> _servirCover(io.HttpRequest pedido, String? id) async {
    final ruta = id == null ? null : await _db.downloadDao.getCoverPathById(id);
    final ext = ruta == null ? '' : extImagenDe(ruta);
    if (ext.isEmpty) {
      await _responderJson(pedido, io.HttpStatus.notFound, 'cover');
      return;
    }
    await _servirArchivo(pedido, ruta, tipo: _tipoImagen(ext));
  }

  /// La letra que está al lado del audio de esa descarga.
  Future<void> _servirLetra(io.HttpRequest pedido, String? id) async {
    final ruta = id == null ? null : await _db.downloadDao.getFilePathById(id);
    final punto = ruta == null ? -1 : ruta.lastIndexOf(RegExp(r'[/\\]'));
    if (punto <= 0) {
      await _responderJson(pedido, io.HttpStatus.notFound, 'lyrics');
      return;
    }
    final letra =
        '${ruta!.substring(0, punto)}${io.Platform.pathSeparator}'
        '${nombreLetra(id!)}';
    await _servirArchivo(pedido, letra, tipo: io.ContentType.text, ext: 'lrc');
  }

  /// Manda un archivo del disco (404 si no está). El tipo se fija para que el
  /// otro lado sepa qué le llegó.
  Future<void> _servirArchivo(
    io.HttpRequest pedido,
    String? ruta, {
    io.ContentType? tipo,
    String? ext,
  }) async {
    final archivo = ruta == null ? null : io.File(ruta);
    if (archivo == null || !await archivo.exists()) {
      await _responderJson(pedido, io.HttpStatus.notFound, 'archivo');
      return;
    }
    pedido.response.headers.contentType = tipo ?? io.ContentType.binary;
    if (ext != null) {
      pedido.response.headers.set('x-bitly-ext', ext);
    }
    pedido.response.contentLength = await archivo.length();
    await archivo.openRead().pipe(pedido.response);
  }

  /// El tipo del contenido de una carátula por su extensión.
  io.ContentType _tipoImagen(String ext) =>
      io.ContentType('image', ext == 'jpg' ? 'jpeg' : ext);
}
