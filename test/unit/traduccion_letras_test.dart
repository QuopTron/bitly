// Tests del servicio de traducción de letras del karaoke.
//
// Lo que se fija acá:
//  · se pide UNA sola vez para toda la letra (no una petición por línea: eso
//    era lo que hace que el traductor gratuito corte la ráfaga);
//  · las líneas traducidas quedan ALINEADAS con las originales, con las vacías
//    (silencios) intactas — si se desalinean, el karaoke muestra la traducción
//    de otro verso;
//  · si el traductor no respeta los saltos de línea, se cae al camino por
//    línea en vez de desalinear;
//  · una falla (sin red, bloqueo) devuelve null y la letra sigue andando;
//  · la segunda vez que se pide lo mismo no se vuelve a llamar al traductor.

import 'package:bitly/core/cache/almacenes/cache_traducciones.dart';
import 'package:bitly/core/servicios/traduccion/servicio_traduccion_letras.dart';
import 'package:flutter_test/flutter_test.dart';

/// Almacén de mentira: guarda en memoria lo mismo que guardaría la base.
class _FakeAlmacen implements AlmacenTraducciones {
  final Map<String, TraduccionGuardada> filas = {};

  String _clave(String cancion, String destino, String huella) =>
      '$cancion|$destino|$huella';

  @override
  Future<TraduccionGuardada?> leer({
    required String cancion,
    required String destino,
    required String huella,
  }) async => filas[_clave(cancion, destino, huella)];

  @override
  Future<void> guardar({
    required String cancion,
    required String destino,
    required String huella,
    required String idiomaOrigen,
    required List<String?> lineas,
  }) async {
    filas[_clave(cancion, destino, huella)] = (
      idiomaOrigen: idiomaOrigen,
      lineas: lineas,
    );
  }
}

/// Traductor de mentira: registra las llamadas y responde lo que le pidan.
class _FakeTraductor {
  _FakeTraductor({this.repartir = true, this.falla = false});

  /// true = respeta los saltos de línea; false = los colapsa (un solo bloque).
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
      texto: repartir ? lineas.map((l) => 'EN($l)').join('\n') : 'EN(todo)',
      idiomaOrigen: 'Spanish',
    );
  }
}

void main() {
  group('ServicioTraduccionLetras', () {
    test('traduce toda la letra en una sola petición', () async {
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionLetras(traductor: fake.traducir);

      final res = await servicio.traducir(
        lineas: ['Primera linea', 'Segunda linea', 'Tercera linea'],
        destino: 'en',
      );

      expect(fake.llamadas, hasLength(1));
      expect(res, isNotNull);
      expect(res!.idiomaOrigen, 'Spanish');
      expect(res.lineas, [
        'EN(Primera linea)',
        'EN(Segunda linea)',
        'EN(Tercera linea)',
      ]);
    });

    test('las líneas vacías no se traducen ni desalinean', () async {
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionLetras(traductor: fake.traducir);

      final res = await servicio.traducir(
        lineas: ['Hola', '', '   ', 'Mundo'],
        destino: 'en',
      );

      expect(res, isNotNull);
      expect(res!.lineas, ['EN(Hola)', null, null, 'EN(Mundo)']);
      // Solo viajó lo que tiene texto.
      expect(fake.llamadas.single, 'Hola\nMundo');
    });

    test(
      'si el reparto de líneas no cuadra, traduce línea por línea',
      () async {
        final fake = _FakeTraductor(repartir: false);
        final servicio = ServicioTraduccionLetras(traductor: fake.traducir);

        final res = await servicio.traducir(
          lineas: ['Una', 'Dos'],
          destino: 'en',
        );

        expect(res, isNotNull);
        // 1 petición en bloque (que no sirvió) + 1 por cada línea.
        expect(fake.llamadas, hasLength(3));
        expect(res!.lineas, ['EN(todo)', 'EN(todo)']);
      },
    );

    test('una falla devuelve null (el karaoke sigue sin traducción)', () async {
      final fake = _FakeTraductor(falla: true);
      final servicio = ServicioTraduccionLetras(traductor: fake.traducir);

      final res = await servicio.traducir(
        lineas: ['Una', 'Dos'],
        destino: 'en',
      );

      expect(res, isNull);
    });

    test(
      'sin texto que traducir devuelve null sin llamar al traductor',
      () async {
        final fake = _FakeTraductor();
        final servicio = ServicioTraduccionLetras(traductor: fake.traducir);

        final res = await servicio.traducir(lineas: ['', '  '], destino: 'en');

        expect(res, isNull);
        expect(fake.llamadas, isEmpty);
      },
    );

    test('la segunda vez no vuelve a llamar al traductor', () async {
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionLetras(traductor: fake.traducir);
      const letra = ['Una linea', 'Otra linea'];

      await servicio.traducir(lineas: letra, destino: 'en');
      await servicio.traducir(lineas: letra, destino: 'en');

      expect(fake.llamadas, hasLength(1));
    });

    test(
      'un idioma distinto sí se traduce (la caché es por destino)',
      () async {
        final fake = _FakeTraductor();
        final servicio = ServicioTraduccionLetras(traductor: fake.traducir);
        const letra = ['Una linea'];

        await servicio.traducir(lineas: letra, destino: 'en');
        await servicio.traducir(lineas: letra, destino: 'pt');

        expect(fake.llamadas, hasLength(2));
      },
    );
  });

  group('persistencia en la base', () {
    const letra = ['Nunca es suficiente', '', 'Yo te quiero'];

    test('al traducir se guarda en la base', () async {
      final fake = _FakeTraductor();
      final almacen = _FakeAlmacen();
      final servicio = ServicioTraduccionLetras(
        traductor: fake.traducir,
        cache: almacen,
      );

      await servicio.traducir(
        lineas: letra,
        destino: 'en',
        claveCancion: 'isrc:USRC17607839',
      );

      expect(almacen.filas, hasLength(1));
      final guardada = almacen.filas.values.single;
      expect(guardada.idiomaOrigen, 'Spanish');
      expect(guardada.lineas, [
        'EN(Nunca es suficiente)',
        null,
        'EN(Yo te quiero)',
      ]);
    });

    test(
      'una app nueva (servicio nuevo) NO vuelve a llamar al traductor',
      () async {
        final almacen = _FakeAlmacen();
        final primero = _FakeTraductor();
        await ServicioTraduccionLetras(
          traductor: primero.traducir,
          cache: almacen,
        ).traducir(lineas: letra, destino: 'en', claveCancion: 'isrc:AAA');
        expect(primero.llamadas, hasLength(1));

        // Simula reabrir la app: servicio nuevo, misma base.
        final segundo = _FakeTraductor();
        final res = await ServicioTraduccionLetras(
          traductor: segundo.traducir,
          cache: almacen,
        ).traducir(lineas: letra, destino: 'en', claveCancion: 'isrc:AAA');

        expect(
          segundo.llamadas,
          isEmpty,
          reason: 'no debe pedir la traducción de nuevo',
        );
        expect(res, isNotNull);
        expect(res!.lineas, [
          'EN(Nunca es suficiente)',
          null,
          'EN(Yo te quiero)',
        ]);
      },
    );

    test('dos canciones distintas guardan cada una su traducción', () async {
      final almacen = _FakeAlmacen();
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionLetras(
        traductor: fake.traducir,
        cache: almacen,
      );

      await servicio.traducir(
        lineas: const ['Letra de la primera'],
        destino: 'en',
        claveCancion: 'isrc:AAA',
      );
      await servicio.traducir(
        lineas: const ['Letra de la segunda'],
        destino: 'en',
        claveCancion: 'isrc:BBB',
      );

      expect(fake.llamadas, hasLength(2));
      expect(almacen.filas, hasLength(2));
    });

    test(
      'la MISMA letra en otra canción reusa la traducción de la sesión',
      () async {
        // Dos versiones de la misma canción (p. ej. la de álbum y la del single)
        // comparten letra: no hay razón para pedirla dos veces.
        final almacen = _FakeAlmacen();
        final fake = _FakeTraductor();
        final servicio = ServicioTraduccionLetras(
          traductor: fake.traducir,
          cache: almacen,
        );

        await servicio.traducir(
          lineas: letra,
          destino: 'en',
          claveCancion: 'isrc:AAA',
        );
        await servicio.traducir(
          lineas: letra,
          destino: 'en',
          claveCancion: 'isrc:BBB',
        );

        expect(fake.llamadas, hasLength(1));
      },
    );

    test('si la LETRA cambia, la traducción guardada no se reusa', () async {
      final almacen = _FakeAlmacen();
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionLetras(
        traductor: fake.traducir,
        cache: almacen,
      );

      await servicio.traducir(
        lineas: const ['Version vieja de la letra'],
        destino: 'en',
        claveCancion: 'isrc:AAA',
      );
      final res = await servicio.traducir(
        lineas: const ['Version nueva y mas larga de la letra'],
        destino: 'en',
        claveCancion: 'isrc:AAA',
      );

      expect(fake.llamadas, hasLength(2));
      expect(res!.lineas.single, 'EN(Version nueva y mas larga de la letra)');
    });

    test('sin clave de canción no se toca la base', () async {
      final almacen = _FakeAlmacen();
      final fake = _FakeTraductor();
      final servicio = ServicioTraduccionLetras(
        traductor: fake.traducir,
        cache: almacen,
      );

      await servicio.traducir(lineas: letra, destino: 'en');

      expect(almacen.filas, isEmpty);
    });
  });
}
