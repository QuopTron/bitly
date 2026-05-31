/// Operaciones de consulta y búsqueda en el historial de descargas.
/// Proporciona métodos para localizar entradas existentes por Spotify ID,
/// ISRC, nombre de track + artista, o combinaciones de estos criterios
/// delegando en el backend Go.
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/services/history/history_models.dart';
import 'package:bitly/core/bridge/bridge_client.dart';
import 'package:bitly/utils/logger.dart';

final _lookupLog = AppLogger('HistoryLookup');

HistoryLookupRequest historyLookupForTrack(Track track) {
  return HistoryLookupRequest(
    spotifyId: track.id,
    isrc: track.isrc,
    trackName: track.name,
    artistName: track.artistName,
  );
}

class HistoryLookup {
  static final HistoryLookup instance = HistoryLookup._init();
  HistoryLookup._init();

  Future<Map<String, dynamic>?> getBySpotifyId(String sid) async {
    return _getEntry('getDownloadEntryBySpotifyID', sid);
  }

  Future<Map<String, dynamic>?> getByIsrc(String isrc) async {
    return _getEntry('getDownloadEntryByISRC', isrc);
  }

  Future<Map<String, dynamic>?> getById(String id) async {
    return _getEntry('getDownloadEntryByID', id);
  }

  Future<Map<String, dynamic>?> findFirstByTrackAndArtist(String t, String a) async {
    try {
      final result = await PlatformBridge.invoke('findDownloadEntryByTrackAndArtist', {
        'track_name': t, 'artist_name': a,
      });
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = _decodeJson(result);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      _lookupLog.w('Go findFirstByTrackAndArtist failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> findByTrackAndArtist(String? trackName, String? artistName) async {
    if (trackName == null || artistName == null) return null;
    return findFirstByTrackAndArtist(trackName, artistName);
  }

  Future<bool> existsTrack(dynamic idOrRequest) async {
    if (idOrRequest is String) return (await getBySpotifyId(idOrRequest)) != null;
    if (idOrRequest is HistoryLookupRequest) return (await findExisting(request: idOrRequest)) != null;
    return false;
  }

  Future<Map<String, dynamic>?> findExisting({HistoryLookupRequest? request, String? spotifyId, String? isrc}) async {
    if (request != null) {
      final sid = request.spotifyId;
      final isrcFromRequest = request.isrc;

      if (sid.isNotEmpty) {
        final res = await getBySpotifyId(sid);
        if (res != null) return res;
      }
      if (isrcFromRequest != null && isrcFromRequest.isNotEmpty) {
        final res = await getByIsrc(isrcFromRequest);
        if (res != null) return res;
      }
      try {
        final result = await PlatformBridge.invoke('findDownloadEntryByTrackAndArtist', {
          'track_name': request.trackName, 'artist_name': request.artistName,
        });
        if (result is String && result.isNotEmpty && result != '{}') {
          final decoded = _decodeJson(result);
          if (decoded is Map) return decoded.cast<String, dynamic>();
        }
      } catch (e) {
        if (e is PlatformException && e.message?.contains('no rows in result set') == true) return null;
        _lookupLog.w('Go findDownloadEntryByTrackAndArtist failed: $e');
      }
      return null;
    }
    if (spotifyId != null && spotifyId.isNotEmpty) {
      final res = await getBySpotifyId(spotifyId);
      if (res != null) return res;
    }
    if (isrc != null && isrc.isNotEmpty) {
      final res = await getByIsrc(isrc);
      if (res != null) return res;
    }
    return null;
  }

  Future<Map<String, dynamic>?> findExistingTrack(HistoryLookupRequest? request) async => findExisting(request: request);

  Future<Map<String, dynamic>?> _getEntry(String method, String id) async {
    try {
      final result = await PlatformBridge.invoke(method, {'request': id});
      if (result is String && result.isNotEmpty && result != '{}') {
        final decoded = _decodeJson(result);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      if (e is PlatformException && e.message?.contains('no rows in result set') == true) return null;
      _lookupLog.w('Go $method failed: $e');
      return null;
    }
  }

  dynamic _decodeJson(String json) {
    try { return jsonDecode(json); } catch (_) { return null; }
  }
}
