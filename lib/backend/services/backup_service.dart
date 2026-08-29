import 'dart:convert' as convert;
import 'dart:io' as io;
import 'package:drift/drift.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';

final _log = Logger();

/// Backup/Restore service — exports and imports app data (settings, download
/// history, favorites, collections, recent searches) as a single JSON file.
class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  /// Export all backupable data to a JSON file in the app's documents directory.
  /// Returns the path to the created backup file.
  Future<String> exportBackup() async {
    final data = await _collectBackupData();
    final jsonStr = const convert.JsonEncoder.withIndent('  ').convert(data);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final file = io.File(p.join(dir.path, 'bitly_backup_$timestamp.json'));
    await file.writeAsString(jsonStr);

    _log.i('[backup] exported to ${file.path} (${jsonStr.length} bytes)');
    return file.path;
  }

  /// Import backup data from a JSON file. Returns the number of records restored.
  Future<int> importBackup(String filePath) async {
    final file = io.File(filePath);
    if (!await file.exists()) {
      throw Exception('Backup file not found: $filePath');
    }

    final jsonStr = await file.readAsString();
    final data = convert.jsonDecode(jsonStr) as Map<String, dynamic>;
    int restored = 0;
    final now = DateTime.now();

    // Restore settings
    if (data['settings'] is Map) {
      final settings = Map<String, String>.from(data['settings']);
      for (final entry in settings.entries) {
        await _db.into(_db.appSettings).insert(
          AppSettingsCompanion.insert(
            key: entry.key,
            value: entry.value,
            updatedAt: now,
          ),
          mode: InsertMode.replace,
        );
        restored++;
      }
      _log.i('[backup] restored ${settings.length} settings');
    }

    // Restore download history
    if (data['download_history'] is List) {
      for (final item in data['download_history'] as List) {
        final m = Map<String, dynamic>.from(item);
        await _db.into(_db.downloadHistory).insert(
          DownloadHistoryCompanion.insert(
            id: m['id'] as String,
            trackName: m['trackName'] as String,
            artistName: m['artistName'] as String,
            downloadedAt: DateTime.tryParse(m['downloadedAt'] as String? ?? '') ?? now,
            albumName: Value(m['albumName'] as String?),
            isrc: Value(m['isrc'] as String?),
            filePath: Value(m['filePath'] as String?),
            service: Value(m['service'] as String?),
            duration: Value(m['duration'] as int?),
            providerTrackId: Value(m['providerTrackId'] as String?),
            providerSource: Value(m['providerSource'] as String?),
            coverUrl: Value(m['coverUrl'] as String?),
            coverPath: Value(m['coverPath'] as String?),
          ),
          mode: InsertMode.replace,
        );
        restored++;
      }
      _log.i('[backup] restored ${data['download_history'].length} download history records');
    }

    // Restore loved tracks
    if (data['loved_tracks'] is List) {
      for (final item in data['loved_tracks'] as List) {
        final m = Map<String, dynamic>.from(item);
        await _db.into(_db.lovedTracks).insert(
          LovedTracksCompanion.insert(
            trackId: m['trackId'] as String,
            trackName: m['trackName'] as String,
            artistName: m['artistName'] as String,
            addedAt: DateTime.tryParse(m['addedAt'] as String? ?? '') ?? now,
            albumName: Value(m['albumName'] as String?),
            coverUrl: Value(m['coverUrl'] as String?),
            coverPath: Value(m['coverPath'] as String?),
            isrc: Value(m['isrc'] as String?),
            durationMs: Value(m['durationMs'] as int?),
            provider: Value(m['provider'] as String?),
          ),
          mode: InsertMode.replace,
        );
        restored++;
      }
    }

    // Restore favorite albums
    if (data['favorite_albums'] is List) {
      for (final item in data['favorite_albums'] as List) {
        final m = Map<String, dynamic>.from(item);
        await _db.into(_db.favoriteAlbums).insert(
          FavoriteAlbumsCompanion.insert(
            albumId: m['albumId'] as String,
            name: m['name'] as String,
            artistId: m['artistId'] as String,
            artistName: m['artistName'] as String,
            coverUrl: m['coverUrl'] as String,
            addedAt: DateTime.tryParse(m['addedAt'] as String? ?? '') ?? now,
            coverPath: Value(m['coverPath'] as String?),
            provider: Value(m['provider'] as String?),
          ),
          mode: InsertMode.replace,
        );
        restored++;
      }
    }

    // Restore favorite artists
    if (data['favorite_artists'] is List) {
      for (final item in data['favorite_artists'] as List) {
        final m = Map<String, dynamic>.from(item);
        await _db.into(_db.favoriteArtists).insert(
          FavoriteArtistsCompanion.insert(
            artistId: m['artistId'] as String,
            name: m['name'] as String,
            imageUrl: m['imageUrl'] as String,
            addedAt: DateTime.tryParse(m['addedAt'] as String? ?? '') ?? now,
            imagePath: Value(m['imagePath'] as String?),
            provider: Value(m['provider'] as String?),
          ),
          mode: InsertMode.replace,
        );
        restored++;
      }
    }

    // Restore collections (playlists)
    if (data['collections'] is List) {
      for (final item in data['collections'] as List) {
        final m = Map<String, dynamic>.from(item);
        await _db.into(_db.collections).insert(
          CollectionsCompanion.insert(
            id: m['id'] as String,
            name: m['name'] as String,
            createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? now,
            updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? now,
            type: Value(m['type'] as String?),
            coverPath: Value(m['coverPath'] as String?),
            customJson: Value(m['customJson'] as String?),
            itemJson: Value(m['itemJson'] as String?),
          ),
          mode: InsertMode.replace,
        );
        restored++;
      }
    }

    if (data['collection_items'] is List) {
      for (final item in data['collection_items'] as List) {
        final m = Map<String, dynamic>.from(item);
        await _db.into(_db.collectionItems).insert(
          CollectionItemsCompanion.insert(
            collectionId: m['collectionId'] as String,
            itemId: m['itemId'] as String,
            addedAt: DateTime.tryParse(m['addedAt'] as String? ?? '') ?? now,
            trackId: Value(m['trackId'] as String?),
            itemJson: Value(m['itemJson'] as String?),
            position: Value(m['position'] as int?),
          ),
          mode: InsertMode.replace,
        );
        restored++;
      }
    }

    // Restore recent searches
    if (data['recent_searches'] is List) {
      for (final item in data['recent_searches'] as List) {
        final m = Map<String, dynamic>.from(item);
        await _db.into(_db.recentSearches).insert(
          RecentSearchesCompanion.insert(
            query: m['query'] as String,
            searchedAt: DateTime.tryParse(m['searchedAt'] as String? ?? '') ?? now,
          ),
          mode: InsertMode.replace,
        );
        restored++;
      }
    }

    _log.i('[backup] import complete: $restored records restored');
    return restored;
  }

  Future<Map<String, dynamic>> _collectBackupData() async {
    final data = <String, dynamic>{};

    // Settings
    final settingsRows = await _db.select(_db.appSettings).get();
    data['settings'] = {
      for (final row in settingsRows) row.key: row.value,
    };

    // Download history
    final historyRows = await _db.select(_db.downloadHistory).get();
    data['download_history'] = historyRows.map((row) => {
      'id': row.id,
      'trackName': row.trackName,
      'artistName': row.artistName,
      'albumName': row.albumName,
      'isrc': row.isrc,
      'filePath': row.filePath,
      'service': row.service,
      'duration': row.duration,
      'downloadedAt': row.downloadedAt.toIso8601String(),
      'providerTrackId': row.providerTrackId,
      'providerSource': row.providerSource,
      'coverUrl': row.coverUrl,
      'coverPath': row.coverPath,
    }).toList();

    // Loved tracks
    final lovedRows = await _db.select(_db.lovedTracks).get();
    data['loved_tracks'] = lovedRows.map((row) => {
      'trackId': row.trackId,
      'trackName': row.trackName,
      'artistName': row.artistName,
      'albumName': row.albumName,
      'coverUrl': row.coverUrl,
      'coverPath': row.coverPath,
      'isrc': row.isrc,
      'durationMs': row.durationMs,
      'provider': row.provider,
      'addedAt': row.addedAt.toIso8601String(),
    }).toList();

    // Favorite albums
    final favAlbums = await _db.select(_db.favoriteAlbums).get();
    data['favorite_albums'] = favAlbums.map((row) => {
      'albumId': row.albumId,
      'name': row.name,
      'artistId': row.artistId,
      'artistName': row.artistName,
      'coverUrl': row.coverUrl,
      'coverPath': row.coverPath,
      'provider': row.provider,
      'addedAt': row.addedAt.toIso8601String(),
    }).toList();

    // Favorite artists
    final favArtists = await _db.select(_db.favoriteArtists).get();
    data['favorite_artists'] = favArtists.map((row) => {
      'artistId': row.artistId,
      'name': row.name,
      'imageUrl': row.imageUrl,
      'imagePath': row.imagePath,
      'provider': row.provider,
      'addedAt': row.addedAt.toIso8601String(),
    }).toList();

    // Collections (playlists)
    final collections = await _db.select(_db.collections).get();
    data['collections'] = collections.map((row) => {
      'id': row.id,
      'name': row.name,
      'type': row.type,
      'coverPath': row.coverPath,
      'createdAt': row.createdAt.toIso8601String(),
      'updatedAt': row.updatedAt.toIso8601String(),
      'customJson': row.customJson,
      'itemJson': row.itemJson,
    }).toList();

    // Collection items
    final collectionItems = await _db.select(_db.collectionItems).get();
    data['collection_items'] = collectionItems.map((row) => {
      'collectionId': row.collectionId,
      'itemId': row.itemId,
      'trackId': row.trackId,
      'itemJson': row.itemJson,
      'addedAt': row.addedAt.toIso8601String(),
      'position': row.position,
    }).toList();

    // Recent searches
    final recentSearches = await _db.select(_db.recentSearches).get();
    data['recent_searches'] = recentSearches.map((row) => {
      'query': row.query,
      'searchedAt': row.searchedAt.toIso8601String(),
    }).toList();

    data['version'] = 1;
    data['exportedAt'] = DateTime.now().toIso8601String();

    return data;
  }
}
