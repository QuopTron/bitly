// ─────────────────────────────────────────────────────────────
// datos_mi_espacio_acciones.dart — PART de datos_mi_espacio.dart:
// quitar el like de un ítem de la pestaña activa, el tipo de ítem
// según la pestaña y el contador de canciones (amadas +
// descargadas) que usa la insignia del perfil.
// Se conecta con: datos_mi_espacio.dart (misma library) + cubit de
// likes + cubit de descargas.
// Parte del flujo: Home → Mi Espacio (acciones y contadores).
// ─────────────────────────────────────────────────────────────

part of 'datos_mi_espacio.dart';

/// Quita el like de un ítem de la pestaña [pestana].
void quitarLikeItem(Item item, BuildContext context, int pestana) {
  if (item.idReal.isEmpty) return;
  final tipo = tipoParaPestana(pestana);
  context.read<CubitLikes>().quitarLikePorId(
    item.idReal,
    tipo,
    item.titulo,
    item.subtitulo,
    item.coverUrl,
  );
}

/// Tipo de ítem (string) según la pestaña activa.
String tipoParaPestana(int pestana) {
  switch (pestana) {
    case 0:
      return 'track';
    case 1:
      return 'playlist';
    case 2:
      return 'album';
    case 3:
      return 'artist';
    default:
      return '';
  }
}

/// Contador de canciones amadas + descargadas con la misma dedup
/// que itemsParaPestana (para la insignia del perfil).
int contarTracks(EstadoLikes estado, {CubitDescargas? cubitDescargas}) {
  final vistosId = <String>{};
  final vistosClave = <String>{};
  for (final i in estado.todosAmados.values.where((i) => i.type == 'track')) {
    vistosId.add(normalizarIdTrack(i.id));
    vistosClave.add(
      '${_normalizarNombre(i.name)}|${_normalizarNombre(i.artists ?? '')}',
    );
  }
  var count = vistosId.length;
  if (cubitDescargas != null) {
    for (final t in cubitDescargas.tracksCompletados) {
      final normId = normalizarIdTrack(t.id);
      final clave =
          '${_normalizarNombre(t.name)}|${_normalizarNombre(t.artists ?? '')}';
      if (!vistosId.contains(normId) && !vistosClave.contains(clave)) {
        vistosId.add(normId);
        vistosClave.add(clave);
        count++;
      }
    }
  }
  return count;
}
