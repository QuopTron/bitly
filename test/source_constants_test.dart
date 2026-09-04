import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/frontend/shared/constants/source_constants.dart';

void main() {
  group('formatId', () {
    test('formats hyphenated ID correctly', () {
      expect(formatId('spotify-web'), 'Spotify Web');
    });

    test('formats double-hyphenated ID correctly', () {
      expect(formatId('ytmusic-spotiflac'), 'Ytmusic Spotiflac');
    });

    test('handles single word ID', () {
      expect(formatId('deezer'), 'Deezer');
    });

    test('handles empty string', () {
      expect(formatId(''), '');
    });

    test('formats apple-music correctly', () {
      expect(formatId('apple-music'), 'Apple Music');
    });

    test('formats qobuz-web correctly', () {
      expect(formatId('qobuz-web'), 'Qobuz Web');
    });
  });

  group('sourceIcons', () {
    test('contains all known sources', () {
      expect(sourceIcons.keys, containsAll([
        'deezer', 'apple-music', 'soundcloud', 'spotify-web',
        'pandora', 'amazon', 'qobuz-web', 'tidal-web', 'ytmusic-spotiflac',
      ]));
    });

    test('has 11 entries (incl. todas/empty)', () {
      expect(sourceIcons.length, 11);
    });
  });

  group('allSources', () {
    test('matches sourceIcons keys', () {
      for (final src in allSources) {
        expect(sourceIcons, contains(src));
      }
    });
  });

  group('sourceLabels', () {
    test('all sources have labels', () {
      for (final src in allSources) {
        expect(sourceLabels, containsPair(src, isA<String>()));
      }
    });

    test('deezer label is Deezer', () {
      expect(sourceLabels['deezer'], 'Deezer');
    });

    test('spotify-web label is Spotify', () {
      expect(sourceLabels['spotify-web'], 'Spotify');
    });
  });
}

