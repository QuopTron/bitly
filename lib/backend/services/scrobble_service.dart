import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class ScrobbleService {
  static final ScrobbleService _instance = ScrobbleService._();
  factory ScrobbleService() => _instance;
  ScrobbleService._();

  String? _lastfmApiKey;
  String? _lastfmSharedSecret;
  String? _lastfmSessionKey;
  String? _listenBrainzToken;

  bool get hasLastfm =>
      _lastfmApiKey != null &&
      _lastfmApiKey!.isNotEmpty &&
      _lastfmSessionKey != null;

  bool get hasListenBrainz => _listenBrainzToken != null;
  Future<void> updateNowPlaying({
    required String artist,
    required String track,
    String? album,
    int? duration,
  }) async {
    if (hasLastfm) {
      await _lastfmNowPlaying(
        artist: artist,
        track: track,
        album: album,
        duration: duration,
      );
    }
    if (hasListenBrainz) {
      await _listenBrainzNowPlaying(
        artist: artist,
        track: track,
        album: album,
      );
    }
  }

  Future<void> scrobble({
    required String artist,
    required String track,
    required int timestamp,
    String? album,
    int? duration,
  }) async {
    if (hasLastfm) {
      await _lastfmScrobble(
        artist: artist,
        track: track,
        timestamp: timestamp,
        album: album,
        duration: duration,
      );
    }
    if (hasListenBrainz) {
      await _listenBrainzScrobble(
        artist: artist,
        track: track,
        timestamp: timestamp,
        album: album,
      );
    }
  }

  String _lastfmSign(Map<String, String> params) {
    final sorted = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final concat = sorted.map((e) => '${e.key}${e.value}').join();
    final full = '$concat$_lastfmSharedSecret';
    return md5.convert(utf8.encode(full)).toString();
  }

  Future<void> _lastfmNowPlaying({
    required String artist,
    required String track,
    String? album,
    int? duration,
  }) async {
    try {
      final params = <String, String>{
        'method': 'track.updateNowPlaying',
        'artist': artist,
        'track': track,
        'sk': _lastfmSessionKey!,
        'api_key': _lastfmApiKey!,
      };
      if (album != null && album.isNotEmpty) params['album'] = album;
      if (duration != null) params['duration'] = duration.toString();
      params['format'] = 'json';
      params['api_sig'] = _lastfmSign(params);
      await http.post(
        Uri.parse('https://ws.audioscrobbler.com/2.0/'),
        body: params,
      );
    } catch (_) {}
  }

  Future<void> _lastfmScrobble({
    required String artist,
    required String track,
    required int timestamp,
    String? album,
    int? duration,
  }) async {
    try {
      final params = <String, String>{
        'method': 'track.scrobble',
        'artist': artist,
        'track': track,
        'timestamp': timestamp.toString(),
        'sk': _lastfmSessionKey!,
        'api_key': _lastfmApiKey!,
      };
      if (album != null && album.isNotEmpty) params['album'] = album;
      if (duration != null) params['duration'] = duration.toString();
      params['format'] = 'json';
      params['api_sig'] = _lastfmSign(params);
      await http.post(
        Uri.parse('https://ws.audioscrobbler.com/2.0/'),
        body: params,
      );
    } catch (_) {}
  }

  Future<void> _listenBrainzNowPlaying({
    required String artist,
    required String track,
    String? album,
  }) async {
    try {
      final body = {
        'listen_type': 'playing_now',
        'payload': [
          {
            'track_metadata': {
              'artist_name': artist,
              'track_name': track,
              if (album != null && album.isNotEmpty) 'release_name': album,
            }
          }
        ],
      };
      await http.post(
        Uri.parse('https://api.listenbrainz.org/1/submit-listens'),
        headers: {
          'Authorization': 'Token $_listenBrainzToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (_) {}
  }

  Future<void> _listenBrainzScrobble({
    required String artist,
    required String track,
    required int timestamp,
    String? album,
  }) async {
    try {
      final body = {
        'listen_type': 'import',
        'payload': [
          {
            'listened_at': timestamp,
            'track_metadata': {
              'artist_name': artist,
              'track_name': track,
              if (album != null && album.isNotEmpty) 'release_name': album,
            },
          }
        ],
      };
      await http.post(
        Uri.parse('https://api.listenbrainz.org/1/submit-listens'),
        headers: {
          'Authorization': 'Token $_listenBrainzToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (_) {}
  }
}
