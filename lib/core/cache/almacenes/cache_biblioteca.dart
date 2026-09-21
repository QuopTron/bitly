// ─────────────────────────────────────────────────────────────
// cache_biblioteca.dart — Invalidación de la caché de la
// biblioteca local. Las consultas se cachean bajo el prefijo
// `library:` (página, conteo, grupos de álbumes...); acá solo
// vive el borrado masivo que se dispara tras un escaneo, una
// descarga completada o el borrado de un lote.
// Se conecta con: base_datos (CacheDao) y los flujos de descargas.
// Parte del flujo: biblioteca local del usuario.
// ─────────────────────────────────────────────────────────────

import '../../base_datos/app_database.dart';
import '../../base_datos/daos/cache_dao.dart';

class CacheBiblioteca {
  final CacheDao _dao;
  CacheBiblioteca(AppDatabase db) : _dao = CacheDao(db);

  /// Invalida toda la caché de biblioteca. Llamar tras un escaneo o una
  /// descarga completada para asegurar datos frescos en la próxima consulta.
  Future<void> invalidarTodo() => _dao.removeByPrefix('library:');
}
