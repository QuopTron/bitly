// Test del modo fiesta: lo que el aparato que manda publica (qué suena, en qué
// minuto, con qué reloj) y la cuenta que hace el invitado para sonar al mismo
// tiempo. Es la parte difícil de la fiesta y se prueba sin dos aparatos.
//
// Se cubren los tres casos que se sienten en el oído: el invitado que llega
// tarde y hay que adelantar, el que va adelantado y hay que atrasar, y el
// desfase de reloj entre aparatos (cada uno tiene su propia hora).

import 'package:bitly/core/modelos/fiesta/fiesta_estado.dart';
import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/servicios/fiesta/base/servicio_fiesta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('estado publicado', () {
    test('ida y vuelta por JSON', () {
      const estado = FiestaEstado(
        clave: 'ISRC123',
        titulo: 'Una canción',
        artista: 'Alguien',
        album: 'Un disco',
        duracionMs: 210000,
        posicionMs: 42000,
        enMs: 1700000000000,
        sonando: true,
      );
      final vuelto = FiestaEstado.desdeJson(estado.aJson());
      expect(vuelto.clave, 'ISRC123');
      expect(vuelto.titulo, 'Una canción');
      expect(vuelto.artista, 'Alguien');
      expect(vuelto.album, 'Un disco');
      expect(vuelto.duracionMs, 210000);
      expect(vuelto.posicionMs, 42000);
      expect(vuelto.enMs, 1700000000000);
      expect(vuelto.sonando, isTrue);
      expect(vuelto.mismaPistaQue(estado), isTrue);
    });

    test('un mapa roto queda en vacío, sin romper la fiesta', () {
      final vacio = FiestaEstado.desdeJson(const {'v': 1});
      expect(vacio.hayPista, isFalse);
      expect(vacio.sonando, isFalse);
    });
  });

  group('posición esperada', () {
    const estado = FiestaEstado(
      clave: 'X',
      duracionMs: 200000,
      posicionMs: 30000,
      enMs: 1000000,
      sonando: true,
    );

    test('sin desfase de reloj, avanza con el reloj local', () {
      // Pasaron 5 s desde que el host publicó.
      expect(estado.posicionEsperadaMs(1005000, 0), 35000);
    });

    test('con el reloj del invitado atrasado, la cuenta lo compensa', () {
      // El invitado va 2 s atrás (-2000): su "ahora" es 1003000 y, sumado el
      // desfase, vuelve a dar los 5 s del host.
      expect(estado.posicionEsperadaMs(1003000, 2000), 35000);
    });

    test('nunca se pasa de la duración de la canción', () {
      expect(estado.posicionEsperadaMs(1300000, 0), 200000);
    });

    test('en pausa, la posición se queda donde estaba', () {
      const pausado = FiestaEstado(
        clave: 'X',
        posicionMs: 12000,
        enMs: 1000000,
        duracionMs: 200000,
      );
      expect(pausado.posicionEsperadaMs(1099000, 0), 12000);
    });

    test('un reloj adelantado no dispara la cuenta hacia atrás', () {
      // Si el invitado cree que el host publicó en el futuro (reloj raro), no
      // se resta: se queda en la posición publicada.
      expect(estado.posicionEsperadaMs(999000, 0), 30000);
    });
  });

  group('deriva', () {
    test('por debajo de lo tolerado no se toca nada', () {
      const estado = FiestaEstado(clave: 'X');
      expect(estado.hayDeriva(100000, 100000 + derivaFiestaMs - 1), isFalse);
    });

    test('por encima, hay que corregir', () {
      const estado = FiestaEstado(clave: 'X');
      expect(estado.hayDeriva(100000, 100000 + derivaFiestaMs + 1), isTrue);
      expect(estado.hayDeriva(100000 + derivaFiestaMs + 1, 100000), isTrue);
    });

    test('cambio de canción se detecta por la clave', () {
      const a = FiestaEstado(clave: 'ISRC-A');
      const b = FiestaEstado(clave: 'ISRC-B');
      expect(a.cambioDePistaRespectoA(b), isTrue);
      expect(a.mismaPistaQue(b), isFalse);
    });
  });

  group('estado desde el reproductor', () {
    const track = ItemFeed(
      id: 'yt:abc',
      type: 'track',
      name: 'Tema',
      artists: 'Artista',
      albumName: 'Disco',
      isrc: 'ISRC-1',
      durationMs: 180000,
    );

    test('publica la pista, el minuto y el reloj', () {
      final estado = estadoDeInstantanea((
        track: track,
        url: 'http://127.0.0.1:9000/audio',
        posicion: const Duration(seconds: 42),
        sonando: true,
      ));
      expect(estado.clave, 'ISRC-1');
      expect(estado.titulo, 'Tema');
      expect(estado.artista, 'Artista');
      expect(estado.album, 'Disco');
      expect(estado.duracionMs, 180000);
      expect(estado.posicionMs, 42000);
      expect(estado.sonando, isTrue);
      expect(estado.enMs, greaterThan(0));
    });

    test('sin URL no hay nada que prestar: queda vacío', () {
      final estado = estadoDeInstantanea((
        track: track,
        url: null,
        posicion: const Duration(seconds: 10),
        sonando: true,
      ));
      expect(estado.hayPista, isFalse);
      expect(estado.sonando, isFalse);
      expect(estado.posicionMs, 10000);
    });

    test('sin pista tampoco (nada puesto todavía)', () {
      final estado = estadoDeInstantanea((
        track: null,
        url: 'http://x/audio',
        posicion: Duration.zero,
        sonando: false,
      ));
      expect(estado.hayPista, isFalse);
    });

    test('sin ISRC la clave cae al id (igual identifica la pista)', () {
      const sinIsrc = ItemFeed(id: 'deezer:9', type: 'track', name: 'Otra');
      final estado = estadoDeInstantanea((
        track: sinIsrc,
        url: 'http://x/audio',
        posicion: Duration.zero,
        sonando: true,
      ));
      expect(estado.clave, 'deezer:9');
    });
  });
}
