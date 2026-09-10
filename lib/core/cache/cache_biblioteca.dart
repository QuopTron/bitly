// ─────────────────────────────────────────────────────────────
// cache_biblioteca.dart — Caché JSON read-through para consultas
// de la biblioteca local (página, conteo, grupos de álbumes).
// Claves: library:page/count/albumGroups/... TTL: 30 min.
// Se conecta con: base_datos (CacheDao) + Mi Espacio → Biblioteca.
// Parte del flujo: biblioteca local del usuario.
// ─────────────────────────────────────────────────────────────

import '../base_datos/app_database.dart';
import '../base_datos/daos/cache_dao.dart';

/// Caché JSON read-through para consultas de la biblioteca local.
class CacheBiblioteca {
  final CacheDao _dao;
  CacheBiblioteca(AppDatabase db) : _dao = CacheDao(db);

  /// TTL por defecto en milisegundos (30 minutos).
  static const int ttlMs = 30 * 60 * 1000;

  // ── Página de biblioteca ────────────────────────────────────

  String _clavePagina(int limit, int offset, String busqueda, String orden) =>
      'library:page:$limit:$offset:${busqueda.hashCode}:${orden.hashCode}';

  Future<String?> getPaginaBiblioteca({
    required int limit,
    required int offset,
    String busqueda = '',
    String orden = '',
  }) =>
      _obtenerSiFresco(_clavePagina(limit, offset, busqueda, orden));

  Future<void> setPaginaBiblioteca({
    required int limit,
    required int offset,
    String busqueda = '',
    String orden = '',
    required String json,
  }) =>
      _dao.set(_clavePagina(limit, offset, busqueda, orden), json);

  // ── Conteo de biblioteca ────────────────────────────────────

  String _claveConteo(String busqueda) => 'library:count:${busqueda.hashCode}';

  Future<String?> getConteoBiblioteca({String busqueda = ''}) =>
      _obtenerSiFresco(_claveConteo(busqueda));

  Future<void> setConteoBiblioteca({String busqueda = '', required String json}) =>
      _dao.set(_claveConteo(busqueda), json);

  // ── Grupos de álbumes ───────────────────────────────────────

  String _claveGruposAlbumes(int limit, int offset, String busqueda) =>
      'library:albumGroups:$limit:$offset:${busqueda.hashCode}';

  Future<String?> getGruposAlbumes({
    required int limit,
    required int offset,
    String busqueda = '',
  }) =>
      _obtenerSiFresco(_claveGruposAlbumes(limit, offset, busqueda));

  Future<void> setGruposAlbumes({
    required int limit,
    required int offset,
    String busqueda = '',
    required String json,
  }) =>
      _dao.set(_claveGruposAlbumes(limit, offset, busqueda), json);

  // ── Conteo de grupos de álbumes ─────────────────────────────

  String _claveConteoGrupos(String busqueda) =>
      'library:albumGroupCount:${busqueda.hashCode}';

  Future<String?> getConteoGruposAlbumes({String busqueda = ''}) =>
      _obtenerSiFresco(_claveConteoGrupos(busqueda));

  Future<void> setConteoGruposAlbumes({String busqueda = '', required String json}) =>
      _dao.set(_claveConteoGrupos(busqueda), json);

  // ── Conteo de tracks sueltos ────────────────────────────────

  String _claveConteoTracksSueltos(String busqueda) =>
      'library:singleTrackCount:${busqueda.hashCode}';

  Future<String?> getConteoTracksSueltos({String busqueda = ''}) =>
      _obtenerSiFresco(_claveConteoTracksSueltos(busqueda));

  Future<void> setConteoTracksSueltos({String busqueda = '', required String json}) =>
      _dao.set(_claveConteoTracksSueltos(busqueda), json);

  // ── Operaciones en lote ─────────────────────────────────────

  /// Invalida toda la caché de biblioteca. Llamar tras un escaneo o una
  /// descarga completada para asegurar datos frescos en la próxima consulta.
  Future<void> invalidarTodo() => _dao.removeByPrefix('library:');

  // ── Helpers internos ────────────────────────────────────────

  Future<String?> _obtenerSiFresco(String key) async {
    final ts = await _dao.getTimestamp(key);
    if (ts == null) return null;
    final edad = DateTime.now().millisecondsSinceEpoch - ts;
    if (edad > ttlMs) {
      await _dao.remove(key);
      return null;
    }
    return _dao.get(key);
  }
}