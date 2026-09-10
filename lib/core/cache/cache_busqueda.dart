// ─────────────────────────────────────────────────────────────
// cache_busqueda.dart — Caché local de búsquedas recientes y
// accesos recientes (wrapper sobre RecentDao).
// Se conecta con: base_datos (RecentDao) + feature Búsqueda.
// Parte del flujo: historial de búsqueda y recientes.
// ─────────────────────────────────────────────────────────────

import '../base_datos/app_database.dart';
import '../base_datos/daos/recent_dao.dart';

/// Caché local de búsquedas recientes + accesos recientes.
class CacheBusqueda {
  final RecentDao _dao;
  CacheBusqueda(AppDatabase db) : _dao = RecentDao(db);

  // ── Búsquedas recientes ────────────────────────────────────

  Future<List<String>> getBusquedasRecientes({int limit = 10}) =>
      _dao.getRecentSearches(limit: limit);

  Future<void> guardarBusquedaReciente(String query) => _dao.saveSearch(query);
  Future<void> quitarBusquedaReciente(String query) => _dao.removeSearch(query);
  Future<void> limpiarBusquedasRecientes() => _dao.clearSearches();

  // ── Accesos recientes ──────────────────────────────────────

  Future<void> upsertAccesoReciente(String key, String json) =>
      _dao.upsertAccess(key, json);

  Future<void> quitarAccesoReciente(String key) => _dao.removeAccess(key);
  Future<void> limpiarAccesosRecientes() => _dao.clearAccess();
}