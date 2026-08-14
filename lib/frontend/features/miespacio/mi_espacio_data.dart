import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../backend/cache/favorite_cache.dart';
import '../../../backend/cache/settings_cache.dart';
import '../../shared/utils/download_strategy.dart';
import '../../l10n/app_localizations.dart';
import '../../../backend/services/download_cubit.dart';
import '../../../backend/services/like_cubit.dart';
import 'mi_espacio_content.dart';

Future<String> loadUsername() async {
  try {
    final cache = GetIt.instance<SettingsCache>();
    final setup = await cache.loadSetupData();
    return setup?.username ?? '';
  } catch (_) {
    return '';
  }
}

Future<List<Item>> loadPlaylists(AppLocalizations loc) async {
  try {
    final fav = GetIt.instance<FavoriteCache>();
    final json = await fav.getFavoritePlaylists();
    if (json.isNotEmpty && json != '[]') {
      final list = jsonDecode(json) as List;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return Item(
          m['name'] as String? ?? loc.setup.miSpacePlaylist,
          '${m['itemCount'] ?? 0} ${loc.setup.miSpaceSongCount}',
          ItemType.playlist,
          coverUrl: cleanLocalCoverPath(m['coverPath'] as String?),
          realId: (m['playlistId'] as String? ?? ''),
          source: m['provider'] as String? ?? '',
        );
      }).toList();
    }
  } catch (_) {}
  return [];
}

/// Normalizes a display name for cross-extension deduplication:
/// lowercased, trimmed, collapses whitespace.
String _normalizeName(String n) => n.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

List<Item> itemsForTab(LikeState likeState, int tab, List<Item> createdPlaylists, {DownloadCubit? downloadCubit}) {
  switch (tab) {
    case 0: {
      // Dedup por ID normalizado y por nombre+artista: dos canciones con el
      // mismo título pero distinto artista (o viceversa) NO deben colisionar.
      final seenId = <String>{};
      final seenKey = <String>{};
      final liked = <Item>[];
      for (final i in likeState.allLiked.values.where((i) => i.type == 'track')) {
        final normId = normalizeTrackId(i.id);
        final key = '${_normalizeName(i.name)}|${_normalizeName(i.artists ?? '')}';
        if (seenId.contains(normId)) continue;
        if (seenKey.contains(key)) continue;
        seenId.add(normId);
        seenKey.add(key);
        liked.add(Item(i.name, i.artists ?? '', ItemType.song,
            coverUrl: (i.localCoverPath?.isNotEmpty == true) ? i.localCoverPath! : i.coverUrl,
            realId: i.id, source: i.source ?? ''));
      }
      if (downloadCubit != null) {
        for (final t in downloadCubit.completedTracks) {
          final normId = normalizeTrackId(t.id);
          final key = '${_normalizeName(t.name)}|${_normalizeName(t.artists ?? '')}';
          if (seenId.contains(normId)) continue;
          if (seenKey.contains(key)) continue;
          seenId.add(normId);
          seenKey.add(key);
          liked.add(Item(t.name, t.artists ?? '', ItemType.song,
              coverUrl: t.coverUrl, realId: t.id, source: t.source ?? ''));
        }
      }
      return liked;
    }
    case 1: {
      final createdIds = createdPlaylists.map((i) => normalizeTrackId(i.realId)).toSet();
      final createdNames = createdPlaylists.map((i) => _normalizeName(i.title)).toSet();
      final seenId = <String>{...createdIds};
      final seenName = <String>{...createdNames};
      final likedPlaylists = <Item>[];
      for (final i in likeState.allLiked.values.where((i) => i.type == 'playlist')) {
        final normId = normalizeTrackId(i.id);
        final normName = _normalizeName(i.name);
        if (seenId.contains(normId) || seenName.contains(normName)) continue;
        seenId.add(normId);
        seenName.add(normName);
        likedPlaylists.add(Item(i.name, i.source ?? '', ItemType.playlist,
            coverUrl: (i.localCoverPath?.isNotEmpty == true) ? i.localCoverPath! : i.coverUrl,
            realId: i.id, source: i.source ?? ''));
      }
      if (downloadCubit != null) {
        for (final entry in downloadCubit.state.downloads.entries) {
          if (entry.value.state != DownloadState.completed) continue;
          if (!entry.key.startsWith('playlist_')) continue;
          final parts = entry.key.split('_');
          if (parts.length < 3) continue;
          final src = parts.last;
          final playlistId = parts.sublist(1, parts.length - 1).join('_');
          final normId = normalizeTrackId(playlistId);
          final name = downloadCubit.batchNameFor(entry.key);
          final normName = _normalizeName(name.isNotEmpty ? name : playlistId);
          if (seenId.contains(normId) || seenName.contains(normName)) continue;
          seenId.add(normId);
          seenName.add(normName);
          likedPlaylists.add(Item(name.isNotEmpty ? name : playlistId, src, ItemType.playlist,
              realId: playlistId, source: src));
        }
      }
      return [...createdPlaylists, ...likedPlaylists];
    }
    case 2: {
      // Dedup por ID y por nombre+artista (dos álbumes homónimos de distintos
      // artistas no deben colisionar).
      final seenId = <String>{};
      final seenKey = <String>{};
      final albums = <Item>[];
      for (final i in likeState.allLiked.values.where((i) => i.type == 'album')) {
        final normId = normalizeTrackId(i.id);
        final key = '${_normalizeName(i.name)}|${_normalizeName(i.artists ?? '')}';
        if (seenId.contains(normId)) continue;
        if (seenKey.contains(key)) continue;
        seenId.add(normId);
        seenKey.add(key);
        albums.add(Item(i.name, i.artists ?? '', ItemType.album,
            coverUrl: (i.localCoverPath?.isNotEmpty == true) ? i.localCoverPath! : i.coverUrl,
            realId: i.id, source: i.source ?? ''));
      }
      if (downloadCubit != null) {
        for (final entry in downloadCubit.state.downloads.entries) {
          if (entry.value.state != DownloadState.completed) continue;
          if (!entry.key.startsWith('album_')) continue;
          final parts = entry.key.split('_');
          if (parts.length < 3) continue;
          final src = parts.last;
          final albumId = parts.sublist(1, parts.length - 1).join('_');
          final normId = normalizeTrackId(albumId);
          final name = downloadCubit.batchNameFor(entry.key);
          final key = '${_normalizeName(name.isNotEmpty ? name : albumId)}|$src';
          if (seenId.contains(normId)) continue;
          if (seenKey.contains(key)) continue;
          seenId.add(normId);
          seenKey.add(key);
          albums.add(Item(name.isNotEmpty ? name : albumId, src, ItemType.album,
              realId: albumId, source: src));
        }
      }
      return albums;
    }
    case 3: {
      final seen = <String>{};
      return likeState.allLiked.values
        .where((i) => i.type == 'artist' && seen.add(normalizeTrackId(i.id)))
        .map((i) => Item(i.name, '', ItemType.artist,
            coverUrl: (i.localCoverPath?.isNotEmpty == true) ? i.localCoverPath! : i.coverUrl,
            realId: i.id, source: i.source ?? ''))
        .toList();
    }
    default: return [];
  }
}

int tracksCount(LikeState state, {DownloadCubit? downloadCubit}) {
  final seenId = state.allLiked.values
      .where((i) => i.type == 'track').map((i) => normalizeTrackId(i.id)).toSet();
  final seenName = state.allLiked.values
      .where((i) => i.type == 'track').map((i) => _normalizeName(i.name)).toSet();
  var count = seenId.length;
  if (downloadCubit != null) {
    for (final t in downloadCubit.completedTracks) {
      final normId = normalizeTrackId(t.id);
      final normName = _normalizeName(t.name);
      if (!seenId.contains(normId) && !seenName.contains(normName)) {
        seenId.add(normId);
        seenName.add(normName);
        count++;
      }
    }
  }
  return count;
}

String emptyMessage(AppLocalizations loc, int tab) {
  switch (tab) {
    case 0: return loc.setup.miSpaceEmptySongs;
    case 1: return loc.setup.miSpaceEmptyPlaylists;
    case 2: return loc.setup.miSpaceEmptyAlbums;
    case 3: return loc.setup.miSpaceEmptyArtists;
    default: return '';
  }
}

void unlikeItem(Item item, BuildContext context, int tab) {
  if (item.realId.isEmpty) return;
  final type = typeForTab(tab);
  context.read<LikeCubit>().unlikeById(item.realId, type, item.title, item.subtitle, item.coverUrl);
}

String typeForTab(int tab) {
  switch (tab) {
    case 0: return 'track';
    case 1: return 'playlist';
    case 2: return 'album';
    case 3: return 'artist';
    default: return '';
  }
}


