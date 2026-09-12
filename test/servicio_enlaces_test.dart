// servicio_enlaces_test.dart — Guard de la detección de enlaces.
//
// Por qué existe: pegar un enlace en la búsqueda disparaba una búsqueda de la
// URL completa y devolvía resultados que no eran esa canción. Estos casos fijan
// qué se considera enlace de música (y qué NO), con los enlaces reales que el
// usuario reportó.
//
// Se conecta con: core/servicios/servicio_enlaces.dart.
// Parte del flujo: enlaces pegados/compartidos.
import 'package:bitly/core/servicios/servicio_enlaces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('enlaceEnTexto detecta enlaces de música', () {
    test('Spotify con parámetro si', () {
      const url = 'https://open.spotify.com/track/3h5T5JypYU7huFiVYhv1dr?si=f1d4f0f8ba624400';
      expect(ServicioEnlaces.enlaceEnTexto(url), url);
    });

    test('YouTube corto con si', () {
      const url = 'https://youtu.be/zriaybLwatM?si=JXtvlVgsWpr6lnIy';
      expect(ServicioEnlaces.enlaceEnTexto(url), url);
    });

    test('YouTube corto con feature=shared', () {
      const url = 'https://youtu.be/IA0uSub1xy4?feature=shared';
      expect(ServicioEnlaces.enlaceEnTexto(url), url);
    });

    test('YouTube watch con lista', () {
      const url = 'https://www.youtube.com/watch?v=IA0uSub1xy4&list=RDAMVM';
      expect(ServicioEnlaces.enlaceEnTexto(url), url);
    });

    test('YouTube Music', () {
      const url = 'https://music.youtube.com/watch?v=dQw4w9WgXcQ';
      expect(ServicioEnlaces.enlaceEnTexto(url), url);
    });

    test('URI de Spotify', () {
      expect(
        ServicioEnlaces.enlaceEnTexto('spotify:track:4cOdK2wGLETKBW3PvgPWqT'),
        'spotify:track:4cOdK2wGLETKBW3PvgPWqT',
      );
    });

    test('enlace dentro de un texto compartido', () {
      const texto = 'Escuchá esto https://open.spotify.com/track/3h5T5JypYU7huFiVYhv1dr?si=abc y decime';
      expect(
        ServicioEnlaces.enlaceEnTexto(texto),
        'https://open.spotify.com/track/3h5T5JypYU7huFiVYhv1dr?si=abc',
      );
    });

    test('host sin esquema', () {
      expect(
        ServicioEnlaces.enlaceEnTexto('open.spotify.com/track/3h5T5JypYU7huFiVYhv1dr'),
        'open.spotify.com/track/3h5T5JypYU7huFiVYhv1dr',
      );
    });
  });

  group('enlaceEnTexto NO confunde búsquedas normales', () {
    test('nombre de canción', () {
      expect(ServicioEnlaces.enlaceEnTexto('Rick Astley - Never Gonna Give You Up'), isNull);
    });

    test('nombre con la palabra spotify', () {
      expect(ServicioEnlaces.enlaceEnTexto('spotify playlist 2026'), isNull);
    });

    test('URL que no es de música', () {
      expect(ServicioEnlaces.enlaceEnTexto('https://www.google.com/search?q=musica'), isNull);
    });

    test('vacío', () {
      expect(ServicioEnlaces.enlaceEnTexto('   '), isNull);
    });
  });
}
