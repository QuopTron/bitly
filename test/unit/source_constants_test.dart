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
        'internetarchive',
      ]));
    });

    // 12 fuentes de catálogo + el id agrupado (''). 'youtube' NO es una
    // fuente más de la lista: es el id con el que entra un resultado
    // identificado por Last.fm (nombre canónico + video oficial), porque el
    // audio sale de YouTube sí o sí. Igual necesita icono y etiqueta.
    test('has 13 entries (incl. todas/empty y youtube)', () {
      expect(iconosFuente.length, 13);
      expect(iconosFuente.containsKey('youtube'), isTrue);
      expect(etiquetasFuente['youtube'], 'YouTube');
    });
  });

  group('todasLasFuentes', () {
    test('matches iconosFuente keys', () {
      for (final src in todasLasFuentes) {
        expect(iconosFuente, contains(src));
      }
    });
  });

  group('fuentesSoloRespaldo', () {
    // Internet Archive y Soulseek no son catálogos navegables: existen para el
    // rescate lossless. Si alguno se ofreciera como fuente de búsqueda, sus
    // resultados se mezclarían con los de las extensiones reales.
    test('Internet Archive, Soulseek y flac-rescue no son fuentes de búsqueda',
        () {
      for (final src in const [
        'internetarchive',
        'soulseek',
        'flac-rescue',
        'redacted',
        'musicbrainz',
      ]) {
        expect(esFuenteDeBusqueda(src), isFalse,
            reason: '$src no debe ofrecerse como fuente de búsqueda');
      }
    });

    test('los catálogos reales sí son fuentes de búsqueda', () {
      for (final src in const [
        'deezer',
        'spotify-web',
        'apple-music',
        'soundcloud',
        'qobuz-web',
        'tidal-web',
        'ytmusic-spotiflac',
      ]) {
        expect(esFuenteDeBusqueda(src), isTrue,
            reason: '$src debe seguir siendo buscable');
      }
    });

    test('el id vacío (agrupado, interno) no rompe el filtro', () {
      expect(esFuenteDeBusqueda(''), isTrue);
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