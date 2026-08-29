import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import '../../../backend/cache/collection_cache.dart';
import '../../../backend/cache/settings_cache.dart';
import '../../shared/utils/download_strategy.dart';
import '../../l10n/app_localizations.dart';
import '../../../backend/services/download_cubit.dart';
import '../../../backend/services/like_cubit.dart';
import 'mi_espacio_content.dart';

/// Loads the user's own created playlists (local Drift `collections` of type
/// 'playlist'). These are distinct from liked/downloaded playlists and are
/// shown mixed into the Playlists tab with an "own" origin badge.
Future<List<Item>> loadOwnPlaylists() async {
  try {
    final cache = GetIt.instance<CollectionCache>();
    final cols = await cache.getAllPlaylists();
    return cols.map((c) {
      final cover = cleanLocalCoverPath(c.coverPath ?? '');
      return Item(
        c.name,
        '',
        ItemType.playlist,
        coverUrl: cover?.isNotEmpty == true ? cover : null,
        realId: c.id,
        origin: ItemOrigin.own,
      );
    }).toList();
  } catch (_) {
    return [];
  }
}

Future<String> loadUsername() async {
  try {
    final cache = GetIt.instance<SettingsCache>();
    final setup = await cache.loadSetupData();
    return setup?.username ?? '';
  } catch (_) {
    return '';
  }
}

/// Normalizes a display name for cross-extension deduplication:
/// lowercased, trimmed, collapses whitespace.
String _normalizeName(String n) =>
    n.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

List<Item> itemsForTab(
  LikeState likeState,
  int tab,
  List<Item> createdPlaylists, {
  DownloadCubit? downloadCubit,
}) {
  switch (tab) {
    case 0:
      {
        // Dedup por ID normalizado y por nombre+artista: dos canciones con el
        // mismo título pero distinto artista (o viceversa) NO deben colisionar.
        final seenId = <String>{};
        final seenKey = <String>{};
        final liked = <Item>[];
        final likedIds = <String>{};
        for (final i in likeState.allLiked.values.where(
          (i) => i.type == 'track',
        )) {
          final normId = normalizeTrackId(i.id);
          final key =
              '${_normalizeName(i.name)}|${_normalizeName(i.artists ?? '')}';
          if (seenId.contains(normId)) continue;
          if (seenKey.contains(key)) continue;
          seenId.add(normId);
          seenKey.add(key);
          likedIds.add(normId);
          liked.add(
            Item(
              i.name,
              i.artists ?? '',
              ItemType.song,
              coverUrl:
                  (i.localCoverPath?.isNotEmpty == true)
                      ? i.localCoverPath!
                      : i.coverUrl,
              realId: i.id,
              source: i.source ?? '',
              origin: ItemOrigin.liked,
            ),
          );
        }
        if (downloadCubit != null) {
          for (final t in downloadCubit.completedTracks) {
            final normId = normalizeTrackId(t.id);
            final key =
                '${_normalizeName(t.name)}|${_normalizeName(t.artists ?? '')}';
            if (seenId.contains(normId)) continue;
            if (seenKey.contains(key)) continue;
            seenId.add(normId);
            seenKey.add(key);
            liked.add(
              Item(
                t.name,
                t.artists ?? '',
                ItemType.song,
                coverUrl: t.coverUrl,
                realId: t.id,
                source: t.source ?? '',
                origin:
                    likedIds.contains(normId)
                        ? ItemOrigin.liked
                        : ItemOrigin.downloaded,
              ),
            );
          }
        }
        return liked;
      }
    case 1:
      {
        final createdIds =
            createdPlaylists.map((i) => normalizeTrackId(i.realId)).toSet();
        final createdNames =
            createdPlaylists.map((i) => _normalizeName(i.title)).toSet();
        final seenId = <String>{...createdIds};
        final seenName = <String>{...createdNames};
        final likedPlaylists = <Item>[];
        final likedIds = <String>{};
        for (final i in likeState.allLiked.values.where(
          (i) => i.type == 'playlist',
        )) {
          final normId = normalizeTrackId(i.id);
          final normName = _normalizeName(i.name);
          if (seenId.contains(normId) || seenName.contains(normName)) continue;
          seenId.add(normId);
          seenName.add(normName);
          likedIds.add(normId);
          likedPlaylists.add(
            Item(
              i.name,
              i.source ?? '',
              ItemType.playlist,
              coverUrl:
                  (i.localCoverPath?.isNotEmpty == true)
                      ? i.localCoverPath!
                      : i.coverUrl,
              realId: i.id,
              source: i.source ?? '',
              origin: ItemOrigin.liked,
            ),
          );
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
            final normName = _normalizeName(
              name.isNotEmpty ? name : playlistId,
            );
            if (seenId.contains(normId) || seenName.contains(normName)) {
              continue;
            }
            seenId.add(normId);
            seenName.add(normName);
            likedPlaylists.add(
              Item(
                name.isNotEmpty ? name : playlistId,
                src,
                ItemType.playlist,
                coverUrl: downloadCubit.batchCoverFor(entry.key).isNotEmpty
                    ? downloadCubit.batchCoverFor(entry.key)
                    : null,
                realId: playlistId,
                source: src,
                origin:
                    likedIds.contains(normId)
                        ? ItemOrigin.liked
                        : ItemOrigin.downloaded,
              ),
            );
          }
        }
        return [...createdPlaylists, ...likedPlaylists];
      }
    case 2:
      {
        // Dedup por ID y por nombre+artista (dos álbumes homónimos de distintos
        // artistas no deben colisionar).
        final seenId = <String>{};
        final seenKey = <String>{};
        final albums = <Item>[];
        final likedIds = <String>{};
        for (final i in likeState.allLiked.values.where(
          (i) => i.type == 'album',
        )) {
          final normId = normalizeTrackId(i.id);
          final key =
              '${_normalizeName(i.name)}|${_normalizeName(i.artists ?? '')}';
          if (seenId.contains(normId)) continue;
          if (seenKey.contains(key)) continue;
          seenId.add(normId);
          seenKey.add(key);
          likedIds.add(normId);
          albums.add(
            Item(
              i.name,
              i.artists ?? '',
              ItemType.album,
              coverUrl:
                  (i.localCoverPath?.isNotEmpty == true)
                      ? i.localCoverPath!
                      : i.coverUrl,
              realId: i.id,
              source: i.source ?? '',
              origin: ItemOrigin.liked,
            ),
          );
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
            // Use name|artist for dedup consistency with liked albums above.
            // The artist is not stored in the download key, so fall back to
            // source — but prefer matching by ID first (seenId).
            final key =
                '${_normalizeName(name.isNotEmpty ? name : albumId)}|$src';
            if (seenId.contains(normId)) continue;
            if (seenKey.contains(key)) continue;
            seenId.add(normId);
            seenKey.add(key);
            albums.add(
              Item(
                name.isNotEmpty ? name : albumId,
                src,
                ItemType.album,
                coverUrl: downloadCubit.batchCoverFor(entry.key).isNotEmpty
                    ? downloadCubit.batchCoverFor(entry.key)
                    : null,
                realId: albumId,
                source: src,
                origin:
                    likedIds.contains(normId)
                        ? ItemOrigin.liked
                        : ItemOrigin.downloaded,
              ),
            );
          }
        }
        return albums;
      }
    case 3:
      {
        final seen = <String>{};
        return likeState.allLiked.values
            .where(
              (i) => i.type == 'artist' && seen.add(normalizeTrackId(i.id)),
            )
            .map(
              (i) => Item(
                i.name,
                '',
                ItemType.artist,
                coverUrl:
                    (i.localCoverPath?.isNotEmpty == true)
                        ? i.localCoverPath!
                        : i.coverUrl,
                realId: i.id,
                source: i.source ?? '',
                origin: ItemOrigin.liked,
              ),
            )
            .toList();
      }
    default:
      return [];
  }
}

int tracksCount(LikeState state, {DownloadCubit? downloadCubit}) {
  // Use the same dedup logic as itemsForTab case 0: normalizeTrackId +
  // name|artist key so the profile badge count matches the actual list.
  final seenId = <String>{};
  final seenKey = <String>{};
  for (final i in state.allLiked.values.where((i) => i.type == 'track')) {
    seenId.add(normalizeTrackId(i.id));
    seenKey.add('${_normalizeName(i.name)}|${_normalizeName(i.artists ?? '')}');
  }
  var count = seenId.length;
  if (downloadCubit != null) {
    for (final t in downloadCubit.completedTracks) {
      final normId = normalizeTrackId(t.id);
      final key =
          '${_normalizeName(t.name)}|${_normalizeName(t.artists ?? '')}';
      if (!seenId.contains(normId) && !seenKey.contains(key)) {
        seenId.add(normId);
        seenKey.add(key);
        count++;
      }
    }
  }
  return count;
}

String emptyMessage(AppLocalizations loc, int tab) {
  switch (tab) {
    case 0:
      return loc.setup.miSpaceEmptySongs;
    case 1:
      return loc.setup.miSpaceEmptyPlaylists;
    case 2:
      return loc.setup.miSpaceEmptyAlbums;
    case 3:
      return loc.setup.miSpaceEmptyArtists;
    default:
      return '';
  }
}

void unlikeItem(Item item, BuildContext context, int tab) {
  if (item.realId.isEmpty) return;
  final type = typeForTab(tab);
  context.read<LikeCubit>().unlikeById(
    item.realId,
    type,
    item.title,
    item.subtitle,
    item.coverUrl,
  );
}

String typeForTab(int tab) {
  switch (tab) {
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
