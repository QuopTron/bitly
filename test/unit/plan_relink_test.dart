// Tests de la re-vinculación de descargas cuando el usuario MUEVE la carpeta.
//
// Lo que importa: que un archivo que sigue en su sitio NUNCA se reescriba, que
// el audio perdido se encuentre por nombre, tallo o id, y que un archivo que no
// es audio (carátula, .lrc) jamás se tome como el audio del track.

import 'package:bitly/core/servicios/descargas/plan_relink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final carpeta = ArchivosEnCarpeta.desde(<String>[
    r'D:\Musica\Nueva\abc123def_audio.flac',
    r'D:\Musica\Nueva\otra.mp3',
    r'D:\Musica\Nueva\cover.jpg',
    r'D:\Musica\Nueva\lyrics_9f8.lrc',
  ]);

  test('el archivo que sigue en su lugar no se toca', () {
    final plan = planificarRelink(
      entradas: const [
        EntradaHistorialDescarga(id: 'abc123def', ruta: r'D:\Musica\Vieja\abc123def_audio.flac'),
      ],
      carpeta: carpeta,
      existe: (r) => r == r'D:\Musica\Vieja\abc123def_audio.flac',
    );
    expect(plan.vacio, isTrue);
  });

  test('el audio movido se reencuentra por nombre en la carpeta nueva', () {
    final plan = planificarRelink(
      entradas: const [
        EntradaHistorialDescarga(id: 'abc123def', ruta: r'D:\Musica\Vieja\abc123def_audio.flac'),
      ],
      carpeta: carpeta,
      existe: (_) => false,
    );
    expect(plan.total, 1);
    expect(plan.rutas['abc123def'], r'D:\Musica\Nueva\abc123def_audio.flac');
  });

  test('el audio se reencuentra por tallo cuando cambió la extensión', () {
    final plan = planificarRelink(
      entradas: const [
        EntradaHistorialDescarga(id: 'zzz', ruta: r'D:\Musica\Vieja\otra.ogg'),
      ],
      carpeta: carpeta,
      existe: (_) => false,
    );
    expect(plan.rutas['zzz'], r'D:\Musica\Nueva\otra.mp3');
  });

  test('se reencuentra por id aunque el nombre cambió del todo', () {
    final plan = planificarRelink(
      entradas: const [
        EntradaHistorialDescarga(id: 'abc123def', ruta: r'D:\Musica\Vieja\tema.flac'),
      ],
      carpeta: carpeta,
      existe: (_) => false,
    );
    expect(plan.rutas['abc123def'], r'D:\Musica\Nueva\abc123def_audio.flac');
  });

  test('un archivo no-audio nunca reemplaza al audio', () {
    final plan = planificarRelink(
      entradas: const [
        EntradaHistorialDescarga(id: 'lyrics_9f8', ruta: r'D:\Musica\Vieja\lyrics_9f8.lrc'),
      ],
      carpeta: carpeta,
      existe: (_) => false,
    );
    expect(plan.rutas, isEmpty);
  });

  test('carátula guardada junto al audio se rescata del cover de la carpeta', () {
    final plan = planificarRelink(
      entradas: const [
        EntradaHistorialDescarga(
          id: 'abc123def',
          ruta: r'D:\Musica\Vieja\abc123def_audio.flac',
          caratula: r'D:\Musica\Vieja\cover.jpg',
        ),
      ],
      carpeta: carpeta,
      existe: (_) => false,
    );
    expect(plan.rutas['abc123def'], r'D:\Musica\Nueva\abc123def_audio.flac');
    expect(plan.caratulas['abc123def'], r'D:\Musica\Nueva\cover.jpg');
  });

  test('una carátula de la caché de la app (otra carpeta) no se toca', () {
    final plan = planificarRelink(
      entradas: const [
        EntradaHistorialDescarga(
          id: 'abc123def',
          ruta: r'D:\Musica\Nueva\abc123def_audio.flac',
          caratula: r'D:\App\covers\hash.jpg',
        ),
      ],
      carpeta: carpeta,
      existe: (r) => r == r'D:\Musica\Nueva\abc123def_audio.flac',
    );
    expect(plan.vacio, isTrue);
  });

  test('sin coincidencias no se inventa ninguna ruta', () {
    final plan = planificarRelink(
      entradas: const [
        EntradaHistorialDescarga(id: 'nada', ruta: r'D:\Musica\Vieja\inexistente.flac'),
      ],
      carpeta: carpeta,
      existe: (_) => false,
    );
    expect(plan.vacio, isTrue);
  });
}
