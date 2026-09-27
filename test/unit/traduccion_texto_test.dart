// Tests del servicio de traducción de textos cortos (título, artista y
// álbum de la hoja de información de canción).
//
// Lo que se fija acá:
//  · se pide UNA sola vez para todos los textos (una ráfaga de peticiones
//    hace que el traductor gratuito corte);
//  · las entradas vacías (un ítem sin álbum, por ejemplo) no se mandan y la
//    lista de salida mantiene la MISMA cantidad y el mismo orden;
//  · si la respuesta no cuadra, se descarta la traducción entera en vez de
//    mezclar el título de una canción con el álbum de otra;
//  · una falla devuelve null (la hoja queda mostrando los datos originales);
//  · la segunda vez no se vuelve a llamar, y cambiar de idioma sí traduce.

import 'package:bitly/core/servicios/traduccion/servicio_traduccion_texto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Traductor de mentira: registra las llamadas y responde lo que le pidan.
class _FakeTraductor {
  _FakeTraductor({this.repartir = true, this.falla = false});

  /// true = respeta los saltos de línea; false = los colapsa.
  final bool repartir;

  /// true = lanza como si el servicio estuviera bloqueado.
  final bool falla;

  final List<String> llamadas = [];

  Future<({String texto, String idiomaOrigen})> traducir(
    String texto,
    String destino,
  ) async {
    llamadas.add(texto);
    if (falla) throw Exception('bloqueado');
    final lineas = texto.split('\n');
    return (
      texto: repartir
          ? lineas.map((l) => 'EN($l)').join('\n')
          : 'EN(todo junto)',
      idiomaOrigen: 'Spanish',
    );
  }
}

void main() {
  group('ServicioTraduccionTexto', () {
    test('traduce todos los textos en una sola petición', () async {
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionTexto(traductor: fake.traducir);

      final res = await servicio.traducir(
        textos: ['BbY WOW', 'KAROL G', 'El álbum'],
        destino: 'en',
      );

      expect(fake.llamadas, hasLength(1));
      expect(fake.llamadas.single, 'BbY WOW\nKAROL G\nEl álbum');
      expect(res, isNotNull);
      expect(res!.idiomaOrigen, 'Spanish');
      expect(res.textos, ['EN(BbY WOW)', 'EN(KAROL G)', 'EN(El álbum)']);
    });

    test('las entradas vacías no viajan y no desalinean', () async {
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionTexto(traductor: fake.traducir);

      // Caso real: un ítem sin álbum (la posición 2 queda vacía).
      final res = await servicio.traducir(
        textos: ['Tema', 'Artista', ''],
        destino: 'en',
      );

      expect(fake.llamadas.single, 'Tema\nArtista');
      expect(res, isNotNull);
      expect(res!.textos, ['EN(Tema)', 'EN(Artista)', '']);
    });

    test('una respuesta desalineada se descarta entera', () async {
      final fake = _FakeTraductor(repartir: false);
      final servicio = ServicioTraduccionTexto(traductor: fake.traducir);

      final res = await servicio.traducir(
        textos: ['Tema', 'Artista'],
        destino: 'en',
      );

      // Mejor sin traducir que con el nombre y el artista cruzados.
      expect(res, isNull);
    });

    test('una falla devuelve null', () async {
      final fake = _FakeTraductor(falla: true);
      final servicio = ServicioTraduccionTexto(traductor: fake.traducir);

      final res = await servicio.traducir(
        textos: ['Tema'],
        destino: 'en',
      );

      expect(res, isNull);
    });

    test('sin texto que traducir no se llama al traductor', () async {
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionTexto(traductor: fake.traducir);

      final res = await servicio.traducir(textos: ['', '  '], destino: 'en');

      expect(res, isNull);
      expect(fake.llamadas, isEmpty);
    });

    test('la segunda vez no vuelve a llamar al traductor', () async {
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionTexto(traductor: fake.traducir);
      const textos = ['Tema', 'Artista', 'Álbum'];

      await servicio.traducir(textos: textos, destino: 'en');
      await servicio.traducir(textos: textos, destino: 'en');

      expect(fake.llamadas, hasLength(1));
    });

    test('otro idioma sí se traduce (la caché es por destino)', () async {
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionTexto(traductor: fake.traducir);
      const textos = ['Tema'];

      await servicio.traducir(textos: textos, destino: 'en');
      await servicio.traducir(textos: textos, destino: 'pt');

      expect(fake.llamadas, hasLength(2));
    });
  });
}
