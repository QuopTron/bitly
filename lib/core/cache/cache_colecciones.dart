// ─────────────────────────────────────────────────────────────
// cache_colecciones.dart — Caché local de colecciones del usuario
// (playlists) — wrapper sobre CollectionsDao.
// Se conecta con: base_datos (CollectionsDao) + PlaylistCubit.
// Parte del flujo: Mi Espacio → Playlists (crear/editar/borrar).
// ─────────────────────────────────────────────────────────────

import '../base_datos/app_database.dart';
import '../base_datos/daos/collections_dao.dart';

/// Caché local de colecciones (playlists del usuario).
class CacheColecciones {
  final CollectionsDao _dao;
  CacheColecciones(AppDatabase db) : _dao = CollectionsDao(db);

  Future<String?> crearColeccion(String name, String coverPath) =>
      _dao.create(name, coverPath: coverPath);

  Future<void> agregarTrackColeccion(String collectionId, String trackId) =>
      _dao.addTrack(collectionId, trackId);

  Future<void> quitarTrackColeccion(String collectionId, String trackId) =>
      _dao.removeTrack(collectionId, trackId);

  Future<void> actualizarCaratulaColeccion(String collectionId, String coverPath) =>
      _dao.updateCover(collectionId, coverPath);

  Future<String?> getCaratulaPlaylist(String collectionId) =>
      _dao.getCover(collectionId);

  Future<void> borrarColeccion(String collectionId) =>
      _dao.removeCollection(collectionId);

  Future<List<Collection>> getTodasLasPlaylists() => _dao.getAllPlaylists();
}