import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/shared/constantes/constantes_fuente.dart';

void main() {
  group('formatearId', () {
    test('formats hyphenated ID correctly', () {
      expect(formatearId('spotify-web'), 'Spotify Web');
    });

    test('formats double-hyphenated ID correctly', () {
      expect(formatearId('ytmusic-spotiflac'), 'Ytmusic Spotiflac');
    });

    test('handles single word ID', () {
      expect(formatearId('deezer'), 'Deezer');
    });

    test('handles empty string', () {
      expect(formatearId(''), '');
    });

    test('formats apple-music correctly', () {
      expect(formatearId('apple-music'), 'Apple Music');
    });

    test('formats qobuz-web correctly', () {
      expect(formatearId('qobuz-web'), 'Qobuz Web');
    });
  });

  group('iconosFuente', () {
    test('contains all known sources', () {
      expect(iconosFuente.keys, containsAll([
        'deezer', 'apple-music', 'soundcloud', 'spotify-web',
        'pandora', 'amazon', 'qobuz-web', 'tidal-web', 'ytmusic-spotiflac',
      ]));
    });

    test('has 11 entries (incl. todas/empty)', () {
      expect(iconosFuente.length, 11);
    });
  });

  group('todasLasFuentes', () {
    test('matches iconosFuente keys', () {
      for (final src in todasLasFuentes) {
        expect(iconosFuente, contains(src));
      }
    });
  });

  group('etiquetasFuente', () {
    test('all sources have labels', () {
      for (final src in todasLasFuentes) {
        expect(etiquetasFuente, containsPair(src, isA<String>()));
      }
    });

    test('deezer label is Deezer', () {
      expect(etiquetasFuente['deezer'], 'Deezer');
    });

    test('spotify-web label is Spotify', () {
      expect(etiquetasFuente['spotify-web'], 'Spotify');
    });
  });
}