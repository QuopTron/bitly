// ─────────────────────────────────────────────────────────────
// servicio_fiesta_audio.dart — PART de servicio_fiesta.dart: el audio que el
// host le pasa a los invitados.
//
// GET /fiesta/audio entrega EXACTAMENTE lo que este aparato está sonando:
//   · si suena un archivo descargado, se manda ese archivo;
//   · si suena un stream (o el proxy local del backend), se reenvía tal cual.
//
// Se respeta el `Range` en los dos casos: sin eso el invitado no puede
// arrancar por el minuto que va la canción (y sonaría desde el principio).
// Con un archivo se contesta 206 y solo el tramo pedido; con un stream se
// copian las cabeceras del origen, que ya sabe hacerlo.
//
// Se conecta con: servicio_fiesta.dart (misma library) + el reproductor (la
// URL que está abierta).
// Parte del flujo: reproductor → modo fiesta → audio del host.
// ─────────────────────────────────────────────────────────────

part of 'servicio_fiesta.dart';

/// Cabeceras del origen que hay que copiar para que el invitado pueda buscar.
const List<String> _cabecerasDeAudio = [
  'content-type',
  'content-length',
  'content-range',
  'accept-ranges',
  'cache-control',
];

/// Entrega el audio que está sonando en este aparato (si hay alguno).
Future<void> servirAudioFiesta(
  io.HttpRequest pedido,
  InstantaneaFiesta Function() instantanea,
) async {
  final url = instantanea().url ?? '';
  if (url.isEmpty) {
    await _sinAudio(pedido);
    return;
  }
  final rango = pedido.headers.value('range');
  if (url.startsWith('file://')) {
    try {
      await _servirArchivoRango(pedido, Uri.parse(url).toFilePath(), rango);
    } catch (e) {
      debugPrint('[Fiesta] archivo ilegible ($url): $e');
      await _sinAudio(pedido);
    }
    return;
  }
  await _proxiarAudio(pedido, url, rango);
}

/// Reenvía el stream del origen, copiando el tramo pedido y sus cabeceras.
Future<void> _proxiarAudio(
  io.HttpRequest pedido,
  String url,
  String? rango,
) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    await _sinAudio(pedido);
    return;
  }
  final cliente = io.HttpClient();
  try {
    final arriba = await cliente.getUrl(uri);
    // El origen (mpv) ya mandó su propio pedido; acá solo se copia lo que
    // pide el invitado. Sin esto, buscar hacia atrás no anda.
    if (rango != null) arriba.headers.set('range', rango);
    final respuesta = await arriba.close();
    pedido.response.statusCode = respuesta.statusCode;
    for (final nombre in _cabecerasDeAudio) {
      final valor = respuesta.headers.value(nombre);
      if (valor != null) pedido.response.headers.set(nombre, valor);
    }
    await respuesta.pipe(pedido.response);
  } catch (e) {
    debugPrint('[Fiesta] no se pudo reenviar el audio: $e');
    // Si ya se había empezado a contestar no se puede corregir el código:
    // se cierra y el motor del invitado reintenta.
    try {
      await _sinAudio(pedido);
    } catch (e) {
      debugPrint('[Fiesta] respuesta ya empezada: $e');
    }
  } finally {
    cliente.close(force: true);
  }
}

/// Manda un archivo del disco, respetando el `Range` (así el invitado puede
/// arrancar en el minuto que va la canción).
Future<void> _servirArchivoRango(
  io.HttpRequest pedido,
  String ruta,
  String? rango,
) async {
  final archivo = io.File(ruta);
  if (!await archivo.exists()) {
    await _sinAudio(pedido);
    return;
  }
  final total = await archivo.length();
  final tramo = _leerRango(rango, total);
  if (tramo == null) {
    // Rango imposible de cumplir: se avisa en vez de mandar cualquier cosa.
    pedido.response.statusCode = io.HttpStatus.requestedRangeNotSatisfiable;
    pedido.response.headers.set('content-range', 'bytes */$total');
    await pedido.response.close();
    return;
  }
  final (desde, hasta) = tramo;
  final parcial = rango != null;
  pedido.response.statusCode =
      parcial ? io.HttpStatus.partialContent : io.HttpStatus.ok;
  pedido.response.headers
    ..contentType = io.ContentType('audio', 'mpeg')
    ..set('accept-ranges', 'bytes')
    ..contentLength = hasta - desde + 1;
  if (parcial) {
    pedido.response.headers.set('content-range', 'bytes $desde-$hasta/$total');
  }
  await archivo.openRead(desde, hasta + 1).pipe(pedido.response);
}

/// Interpreta `bytes=desde-hasta`. Devuelve null si el rango no tiene sentido
/// para un archivo de [total] bytes.
(int, int)? _leerRango(String? rango, int total) {
  if (rango == null || total <= 0) {
    return total <= 0 ? null : (0, total - 1);
  }
  if (!rango.startsWith('bytes=')) return (0, total - 1);
  final partes = rango.substring(6).split('-');
  final desde = int.tryParse(partes.first.trim()) ?? 0;
  final hastaTexto = partes.length > 1 ? partes[1].trim() : '';
  final hasta = hastaTexto.isEmpty ? total - 1 : int.tryParse(hastaTexto) ?? -1;
  if (desde < 0 || desde > hasta || desde >= total) return null;
  return (desde, hasta < total ? hasta : total - 1);
}

/// No hay nada que prestar (o el archivo ya no está).
Future<void> _sinAudio(io.HttpRequest pedido) async {
  pedido.response.statusCode = io.HttpStatus.notFound;
  pedido.response.headers.contentType = io.ContentType.json;
  pedido.response.write('{"estado":"sinAudio"}');
  await pedido.response.close();
}
