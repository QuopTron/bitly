// ─────────────────────────────────────────────────────────────
// collections_dao_items.dart — PART de collections_dao.dart: orden,
// ids y conteo de los items de una colección (playlist).
//
// Por qué existe: `addTrack` no escribe `position`, así que una
// playlist armada a mano quedaba ordenada por lo que devolviera
// SQLite. Acá se graba la posición de cada canción.
// Se conecta con: collections_dao.dart (misma library).
// Parte del flujo: Mi Espacio → playlists (crear/editar).
// ─────────────────────────────────────────────────────────────

part of 'collections_dao.dart';

/// Orden y conteo de los items de una colección. Extensión sobre
/// [CollectionsDao] para mantener cada archivo dentro del límite.
extension CollectionsDaoItems on CollectionsDao {
  /// Deja los items de la colección EXACTAMENTE en [itemIds] (en ese orden).
  ///
  /// Se conserva el `addedAt` de los que ya estaban: solo cambia el orden.
  Future<void> reordenarItems(String collectionId, List<String> itemIds) async {
    final previos = await getTracks(collectionId);
    final porId = {for (final p in previos) p.itemId: p};
    await (delete(collectionItems)
      ..where((t) => t.collectionId.equals(collectionId))).go();
    for (var i = 0; i < itemIds.length; i++) {
      final id = itemIds[i];
      await into(collectionItems).insert(
        CollectionItemsCompanion(
          collectionId: Value(collectionId),
          itemId: Value(id),
          trackId: Value(id),
          addedAt: Value(porId[id]?.addedAt ?? DateTime.now()),
          position: Value(i),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  }

  /// Ids de los tracks de una colección (en el orden guardado).
  Future<List<String>> getTrackIds(String collectionId) async {
    final filas = await getTracks(collectionId);
    return filas.map((f) => f.trackId ?? f.itemId).toList();
  }

  /// Cantidad de canciones por colección, en UNA sola consulta (evita hacer
  /// una por playlist al listar las creadas).
  Future<Map<String, int>> getConteosPorColeccion() async {
    final cuenta = collectionItems.itemId.count();
    final consulta =
        selectOnly(collectionItems)
          ..addColumns([collectionItems.collectionId, cuenta])
          ..groupBy([collectionItems.collectionId]);
    final filas = await consulta.get();
    final mapa = <String, int>{};
    for (final fila in filas) {
      final id = fila.read(collectionItems.collectionId);
      if (id == null) continue;
      mapa[id] = fila.read(cuenta) ?? 0;
    }
    return mapa;
  }
}
