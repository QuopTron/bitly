import 'dart:io' as io;
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/settings_table.dart';
import 'tables/content_tables.dart';
import 'tables/sources_table.dart';
import 'tables/favorites_tables.dart';
import 'tables/collections_table.dart';
import 'tables/play_history_table.dart';
import 'tables/download_tables.dart';
import 'tables/recent_table.dart';
import 'tables/secrets_table.dart';
import 'tables/premium_table.dart';
import 'tables/artists_tables.dart';
import 'tables/cache_tables.dart';

import 'daos/settings_dao.dart';
import 'daos/content_dao.dart';
import 'daos/favorites_dao.dart';
import 'daos/collections_dao.dart';
import 'daos/play_history_dao.dart';
import 'daos/download_dao.dart';
import 'daos/recent_dao.dart';
import 'daos/premium_dao.dart';
import 'daos/cache_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    AppSettings,
    Artists,
    Albums,
    Tracks,
    Sources,
    Files,
    LovedTracks,
    FavoriteAlbums,
    FavoriteArtists,
    FavoritePlaylists,
    Collections,
    CollectionItems,
    PlayHistory,
    PlayAggregates,
    DownloadQueue,
    DownloadHistory,
    DownloadBatches,
    HiddenDownloadIds,
    RecentSearches,
    RecentAccess,
    SecretCounters,
    SecretUnlocks,
    UserPremium,
    QuotaUsage,
    UserDailyPlays,
    IsrcCache,
    VideoUrlCache,
    JsonCache,
    SimilarArtists,
  ],
  daos: [
    SettingsDao,
    ContentDao,
    FavoritesDao,
    CollectionsDao,
    PlayHistoryDao,
    DownloadDao,
    RecentDao,
    PremiumDao,
    CacheDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

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
    },
  );

  /// Migrates legacy cover rows written by older builds. Covers used to be
  /// stored as desktop-only loopback HTTP URLs under /cover/ which break cover
  /// rendering on other platforms and after server changes, leaving cards
  /// gray. Clearing them makes the UI fall back to the remote coverUrl; new
  /// covers are saved with real absolute local paths. Runs once at startup —
  /// the UPDATEs only touch legacy rows, so it's cheap and idempotent.
  Future<void> migrateLegacyCoverPaths() async {
    const legacyWhere = "LIKE 'http://127.0.0.1%' OR cover_path LIKE 'http://localhost%'";
    try {
      await customStatement("UPDATE loved_tracks SET cover_path = '' WHERE cover_path $legacyWhere");
      await customStatement("UPDATE favorite_albums SET cover_path = '' WHERE cover_path $legacyWhere");
      await customStatement("UPDATE favorite_artists SET image_path = '' WHERE image_path LIKE 'http://127.0.0.1%' OR image_path LIKE 'http://localhost%'");
      await customStatement("UPDATE favorite_playlists SET cover_path = '' WHERE cover_path $legacyWhere");
      await customStatement("UPDATE download_history SET cover_path = '' WHERE cover_path $legacyWhere");
    } catch (_) {
      // Best-effort: a failed migration must never block app startup.
    }
  }

  static Future<AppDatabase> create() async {
    final dir = await getApplicationDocumentsDirectory();
    await dir.create(recursive: true);
    final dbFile = io.File(p.join(dir.path, 'bitly_cache.db'));
    return AppDatabase(NativeDatabase.createInBackground(dbFile));
  }
}

