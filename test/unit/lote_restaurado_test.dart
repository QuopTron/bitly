// lote_restaurado_test.dart — Fija la decisión de cómo se restaura un lote
// (álbum/playlist) guardado en la BD. El bug que evita: la fila del lote se
// escribe al EMPEZAR la descarga, así que un álbum con 2 de 17 canciones
// bajadas se levantaba como "completado" (tilde verde, botón apagado y el
// álbum listado como descargado en Mi Espacio).
import 'package:bitly/core/cache/estado/estado_descarga.dart';
import 'package:bitly/estado/descargas/lote_restaurado.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('evaluarLoteRestaurado', () {
    final keys = List.generate(17, (i) => 'track_${i}_ytmusic-spotiflac');

    test('un lote con TODOS sus tracks en disco queda completo', () {
      final r = evaluarLoteRestaurado(keys, (_) => true);
      expect(r.completo, isTrue);
      expect(r.listos, 17);
      expect(r.total, 17);
      expect(estadoDeLoteRestaurado(r).estado, EstadoDescarga.completado);
    });

    test('un lote con 2 de 17 queda PARCIAL, nunca verde', () {
      final descargados = keys.take(2).toSet();
      final r = evaluarLoteRestaurado(keys, descargados.contains);

      expect(r.completo, isFalse);
      expect(r.listos, 2);
      expect(r.total, 17);
      expect(r.progreso, closeTo(2 / 17, 1e-9));
      final estado = estadoDeLoteRestaurado(r);
      expect(estado.estado, EstadoDescarga.ninguno);
      expect(estado.progreso, closeTo(2 / 17, 1e-9));
    });

    test('un lote sin ids guardados no se da por completo', () {
      final r = evaluarLoteRestaurado(const [], (_) => true);
      expect(r.completo, isFalse);
      expect(r.total, 0);
      expect(r.progreso, 0.0);
    });
  });

  group('claves de lote', () {
    test('solo álbum y playlist son colecciones', () {
      expect(esClaveDeColeccion('album_abc_spotify-web'), isTrue);
      expect(esClaveDeColeccion('playlist_abc_deezer'), isTrue);
      expect(esClaveDeColeccion('_singles'), isFalse);
      expect(esClaveDeColeccion('track_abc_deezer'), isFalse);
      expect(esClaveDeColeccion(''), isFalse);
    });

    test('acepta el formato viejo (strings) y el enriquecido (mapas)', () {
      expect(
        idsStateKeysDeLote('["track_1_deezer","track_2_deezer"]'),
        ['track_1_deezer', 'track_2_deezer'],
      );
      expect(
        idsStateKeysDeLote(
          '[{"id":"track_1_deezer","name":"A","artist":"B","cover":""}]',
        ),
        ['track_1_deezer'],
      );
      expect(idsStateKeysDeLote('[]'), isEmpty);
      expect(idsStateKeysDeLote('no-es-json'), isEmpty);
    });

    test('el id se corta con la fuente conocida, no con el último _', () {
      // El id de Internet Archive trae '_' adentro: cortar por el último '_'
      // devolvería 'gran' y el lote quedaría parcial para siempre.
      expect(
        idDeStateKey('track_gran_salon_de_baile_internetarchive', 'internetarchive'),
        'gran_salon_de_baile',
      );
      expect(idDeStateKey('track_123_spotify-web', 'spotify-web'), '123');
      // Sin fuente conocida cae al último separador.
      expect(idDeStateKey('track_123_spotify-web', ''), '123');
    });
  });
}
