// track_descargado_test.dart — Fija cómo se decide si una canción ya está en
// disco. Los detalles de álbum/playlist lo usan para contar ("2 / 17") y para
// no volver a bajar lo que ya está: con solo la clave exacta (id + fuente), un
// track bajado desde otra extensión no contaba y el álbum decía "0 descargado"
// con el archivo ya en la carpeta.
import 'package:bitly/core/cache/estado/estado_descarga.dart';
import 'package:bitly/core/servicios/utilidades/huella_item.dart';
import 'package:bitly/estado/descargas/track_descargado.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const completo = DatosEstadoDescarga(
    estado: EstadoDescarga.completado,
    progreso: 1.0,
  );

  test('la clave exacta (id + fuente) cuenta como descargada', () {
    expect(
      trackDescargadoEnEstado(
        descargas: {'track_123_deezer': completo},
        huellasDescargadas: const {},
        trackId: 'deezer:123',
        source: 'deezer',
      ),
      isTrue,
    );
  });

  test('otra fuente con el mismo ISRC también cuenta', () {
    expect(
      trackDescargadoEnEstado(
        descargas: {'track_123_deezer': completo},
        huellasDescargadas: {huellaIsrc('USUG11904206')},
        trackId: 'spotify:XYZ',
        source: 'spotify-web',
        isrc: 'usug11904206',
      ),
      isTrue,
    );
  });

  test('sin ISRC, otra fuente no cuenta (nada de falsos positivos)', () {
    expect(
      trackDescargadoEnEstado(
        descargas: {'track_123_deezer': completo},
        huellasDescargadas: const {},
        trackId: 'spotify:XYZ',
        source: 'spotify-web',
      ),
      isFalse,
    );
  });

  test('estados a medias (cola/progreso) no cuentan', () {
    expect(
      trackDescargadoEnEstado(
        descargas: {
          'track_123_deezer': const DatosEstadoDescarga(
            estado: EstadoDescarga.enProgreso,
            progreso: 0.5,
          ),
        },
        huellasDescargadas: const {},
        trackId: 'deezer:123',
        source: 'deezer',
      ),
      isFalse,
    );
    expect(
      trackDescargadoEnEstado(
        descargas: const {},
        huellasDescargadas: const {},
        trackId: '',
        source: 'deezer',
      ),
      isFalse,
    );
  });
}
