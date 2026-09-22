// ─────────────────────────────────────────────────────────────
// huella_item_rendimiento_test.dart — Fija dos cosas:
//
// 1. Que refactorizar las expresiones regulares de `huella_item`
//    (sacarlas de dentro de las funciones, donde se recompilaban en
//    cada llamada) NO cambió el resultado de ninguna huella.
// 2. Que resolver la carátula de un favorito por índice de mapa es
//    mucho más barato que el recorrido O(N) que se hacía por tarjeta.
//    Ese recorrido corría en el `build()` de cada tarjeta: era la
//    causa de los tirones en celular, TV y PC.
//
// Parte del flujo: feed, búsqueda, Mi Espacio, detalle (huellas y carátulas).
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/servicios/utilidades/huella_item.dart';
import 'package:flutter_test/flutter_test.dart';

ItemFeed _track(
  int i, {
  String? name,
  String? artists,
  String? isrc,
  String type = 'track',
}) => ItemFeed(
  id: 'id$i',
  type: type,
  name: name ?? 'Cancion $i',
  artists: artists ?? 'Artista $i',
  coverUrl: 'https://cdn.test/$i.jpg',
  source: 'deezer',
  isrc: isrc,
);

void main() {
  group('huellaItem conserva el resultado', () {
    test('normaliza mayúsculas, signos y espacios de más', () {
      final item = _track(
        1,
        name: '  Beyoncé —   Halo!!  ',
        artists: 'Beyoncé',
      );
      expect(huellaTrack(item), 'track:beyonc halo|beyonc');
    });

    test('separa artistas por feat./ft./&/y y los ordena igual', () {
      expect(
        extraerArtistas('KAROL G, Judeline & rusowsky'),
        ['karol g', 'judeline', 'rusowsky'],
      );
      expect(extraerArtistas('A ft. B feat. C'), ['a', 'b', 'c']);
      expect(extraerArtistas('A y B'), ['a', 'b']);
      expect(extraerArtistas(null), isEmpty);
      expect(extraerArtistas('   '), isEmpty);
    });

    test('cada tipo tiene su prefijo de huella', () {
      expect(huellaItem(_track(1)), startsWith('track:'));
      expect(huellaItem(_track(1, type: 'album')), startsWith('album:'));
      expect(huellaItem(_track(1, type: 'artist')), startsWith('artist:'));
      expect(huellaItem(_track(1, type: 'playlist')), startsWith('playlist:'));
    });

    test('la huella de ISRC cruza extensiones sin importar el formato', () {
      expect(
        huellaIsrc(' us-rc1-23-45678 '),
        huellaIsrc('US-RC1-23-45678'),
      );
    });
  });

  group('resolver la carátula de un favorito', () {
    // 400 favoritos: el tamaño de una biblioteca ya cargada.
    final amados = List.generate(400, (i) => _track(i));
    // Lo que se pregunta en una pantalla llena de tarjetas.
    final consultas = List.generate(400, (i) => _track(400 + i));

    /// Cómo se hacía antes: recorrer TODOS los favoritos construyendo un
    /// `ItemFeed` y calculando su huella, por cada tarjeta y por cada build.
    int viejo() {
      var encontrados = 0;
      for (final consulta in consultas) {
        final fp = huellaItem(consulta);
        for (final v in amados) {
          if (identical(v, consulta)) encontrados++;
          if (huellaItem(v) == fp) {
            encontrados++;
            break;
          }
        }
      }
      return encontrados;
    }

    /// Cómo se hace ahora: un índice armado una vez por versión de la
    /// biblioteca y una búsqueda directa por huella.
    int nuevo() {
      final indice = <String, ItemFeed>{
        for (final v in amados) huellaItem(v): v,
      };
      var encontrados = 0;
      for (final consulta in consultas) {
        if (indice[huellaItem(consulta)] != null) encontrados++;
      }
      return encontrados;
    }

    test('el índice no cambia el resultado', () {
      expect(nuevo(), viejo());
    });

    test('el índice es mucho más barato que el recorrido por tarjeta', () {
      final cronoViejo = Stopwatch()..start();
      viejo();
      cronoViejo.stop();

      final cronoNuevo = Stopwatch()..start();
      nuevo();
      cronoNuevo.stop();

      // 400 consultas × 400 favoritos = 160.000 comparaciones frente a 400
      // accesos a mapa. El margen es enorme a propósito para que no sea
      // frágil en una máquina de CI lenta.
      expect(
        cronoNuevo.elapsedMicroseconds * 4,
        lessThan(cronoViejo.elapsedMicroseconds),
        reason:
            'viejo=${cronoViejo.elapsedMicroseconds}us '
            'nuevo=${cronoNuevo.elapsedMicroseconds}us',
      );
    });
  });
}
