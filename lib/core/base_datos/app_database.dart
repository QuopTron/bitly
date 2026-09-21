// ---------------------------------------------------------------------------
// app_database.dart — Base de datos local (drift/SQLite). Define todas las tablas y DAOs, la migracion de esquema (v4) y la creacion de bitly_cache.db. Se conecta con: tablas/ y daos/. Parte del flujo: arranque (AppDatabase.create).
// ---------------------------------------------------------------------------

import 'package:drift/drift.dart';

// La CONEXIÓN se elige según la plataforma porque el navegador no tiene
// dart:ffi (y drift/native.dart lo usa): en web se abre con drift sobre
// wasm y en el resto como archivo SQLite nativo. Ver conexion_nativa.dart
// y conexion_web.dart.
import 'conexion_nativa.dart'
    if (dart.library.js_interop) 'conexion_web.dart'
    as conexion;

import 'tables/sistema/settings_table.dart';
import 'tables/musica/base/content_tables.dart';
import 'tables/usuario/favorites_tables.dart';
import 'tables/usuario/collections_table.dart';
import 'tables/musica/historial/play_history_table.dart';
import 'tables/sistema/download_tables.dart';
import 'tables/musica/historial/recent_table.dart';
import 'tables/usuario/premium_table.dart';
import 'tables/musica/artistas/artists_tables.dart';
import 'tables/sistema/cache_tables.dart';

import 'daos/descargas/download_dao.dart';

import 'package:flutter/foundation.dart';
part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AppSettings,
    Artists,
    Albums,
    Tracks,
    LovedTracks,
    FavoriteAlbums,
    FavoriteArtists,
    FavoritePlaylists,
    Collections,
    CollectionItems,
    PlayHistory,
    PlayAggregates,
    DownloadHistory,
    DownloadBatches,
    RecentSearches,
    UserPremium,
    QuotaUsage,
    UserDailyPlays,
    IsrcCache,
    VideoUrlCache,
    JsonCache,
    SimilarArtists,
  ],
  // Solo DownloadDao se usa como getter (`db.downloadDao`); los demás DAOs se
  // construyen donde hacen falta (`ContentDao(db)`), así que no se declaran
  // acá: drift generaba para ellos un getter que nadie llamaba.
  daos: [DownloadDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        m.create(jsonCache);
      }
      if (from < 3) {
        m.addColumn(downloadBatches, downloadBatches.trackIds);
      }
      if (from < 4) {
        m.addColumn(downloadBatches, downloadBatches.coverUrl);
        m.addColumn(downloadBatches, downloadBatches.coverPath);
      }
      if (from < 5) {
        // Las tablas de "secretos" (contadores y desbloqueos ocultos) nunca
        // guardaron una sola fila y sus DAOs se eliminaron. DROP IF EXISTS
        // para que la migración sea idempotente y no pueda bloquear el
        // arranque si la tabla ya no estaba (p. ej. base recién creada).
        await customStatement('DROP TABLE IF EXISTS secret_counters');
        await customStatement('DROP TABLE IF EXISTS secret_unlocks');
      }
      if (from < 6) {
        // Tres tablas que quedaron sin un solo lector ni escritor:
        //   recent_access  → el historial de reproducción y el de búsquedas
        //                    ya cubren esos dos usos.
        //   files          → la biblioteca local se lee por descargas, no
        //                    por esta tabla, que nunca se llenó.
        //   download_queue → la cola de descargas vive en memoria (el cubit);
        //                    solo se persiste el historial y los lotes.
        //   hidden_download_ids → la app no tiene "ocultar descarga": la
        //                    feature nunca existió del lado del código.
        //   sources        → la tabla de "proveedor + id externo" por track
        //                    nunca tuvo quien la llenara: la fuente de cada
        //                    resultado viaja con el propio resultado.
        // Con sus métodos de DAO eliminados, DROP IF EXISTS deja la migración
        // idempotente y no puede bloquear el arranque.
        for (final tabla in [
          'recent_access',
          'files',
          'download_queue',
          'hidden_download_ids',
          'sources',
        ]) {
          await customStatement('DROP TABLE IF EXISTS $tabla');
        }
      }
    },
  );

  /// Migrates legacy cover rows written by older builds. Covers used to be
  /// stored as desktop-only loopback HTTP URLs under /cover/ which break cover
  /// rendering on other platforms and after server changes, leaving cards
  /// gray. Clearing them makes the UI fall back to the remote coverUrl; new
  /// covers are saved with real absolute local paths. Runs once at startup —
  /// the UPDATEs only touch legacy rows, so it's cheap and idempotent.
  Future<void> migrateLegacyCoverPaths() async {
    const legacyWhere =
        "LIKE 'http://127.0.0.1%' OR cover_path LIKE 'http://localhost%'";
    try {
      await customStatement(
        "UPDATE loved_tracks SET cover_path = '' WHERE cover_path $legacyWhere",
      );
      await customStatement(
        "UPDATE favorite_albums SET cover_path = '' WHERE cover_path $legacyWhere",
      );
      await customStatement(
        "UPDATE favorite_artists SET image_path = '' WHERE image_path LIKE 'http://127.0.0.1%' OR image_path LIKE 'http://localhost%'",
      );
      await customStatement(
        "UPDATE favorite_playlists SET cover_path = '' WHERE cover_path $legacyWhere",
      );
      await customStatement(
        "UPDATE download_history SET cover_path = '' WHERE cover_path $legacyWhere",
      );
    } catch (e) {
      debugPrint('[AppDatabase] $e');
      // Best-effort: a failed migration must never block app startup.
    }
  }

  static Future<AppDatabase> create() async =>
      AppDatabase(await conexion.abrirConexion());
}
