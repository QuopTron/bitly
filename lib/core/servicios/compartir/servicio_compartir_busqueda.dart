// ─────────────────────────────────────────────────────────────
// servicio_compartir_busqueda.dart — PART de servicio_compartir.dart:
// convierte los datos de un enlace compartido en una canción real.
//
// orden: primero por ISRC (identidad exacta, sin adivinar) y solo si
// eso falla por nombre + artista, eligiendo el candidato que más se
// parece para no traer un remix o una versión en vivo.
//
// Se conecta con: servicio_compartir.dart (misma library).
// Parte del flujo: enlace compartido → canción reproducible.
// ─────────────────────────────────────────────────────────────

part of 'servicio_compartir.dart';

/// Canción de un compartido: ISRC primero, nombre+artista después.
Future<ResultadoEnlace?> _resolverCompartido(DatosCompartido datos) async {
  final backend = di.sl<BackendService>();
  ItemFeed? item;
  if (datos.isrc.isNotEmpty) {
    item = await backend.resolverIsrc(datos.isrc);
  }
  if (item == null) {
    final consulta = [datos.nombre, datos.artista]
        .where((e) => e.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (consulta.isEmpty) return null;
    final resultados = await backend.search(
      query: consulta,
      type: datos.tipo == 'track' ? 'track' : '',
      limit: 10,
    );
    if (resultados.isEmpty) return null;
    item = datos.tipo == 'track'
        ? _mejorCandidato(resultados, datos)
        : resultados.first;
  }
  return ResultadoEnlace(item: item);
}

/// Elige el resultado que más se parece a lo compartido: mismo ISRC
/// primero, después mismo nombre y artista.
ItemFeed _mejorCandidato(List<ItemFeed> resultados, DatosCompartido datos) {
  final nombre = normalizarTexto(datos.nombre);
  final artista = normalizarTexto(datos.artista);
  for (final r in resultados) {
    if (datos.isrc.isNotEmpty && r.isrc == datos.isrc) return r;
  }
  for (final r in resultados) {
    final coincideNombre = normalizarTexto(r.name) == nombre;
    final coincideArtista = artista.isEmpty ||
        normalizarTexto(r.artists ?? '').contains(artista);
    if (coincideNombre && coincideArtista) return r;
  }
  return resultados.first;
}

/// Texto comparable: sin acentos, sin mayúsculas y sin puntuación.
String normalizarTexto(String texto) {
  const acentos = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const planos = 'aaaaaeeeeiiiiooooouuuunc';
  final buffer = StringBuffer();
  for (final runa in texto.toLowerCase().runes) {
    final c = String.fromCharCode(runa);
    final i = acentos.indexOf(c);
    buffer.write(i >= 0 ? planos[i] : c);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), '').trim();
}
