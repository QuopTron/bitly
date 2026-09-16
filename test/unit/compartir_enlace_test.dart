// Tests del enlace compartido: cifrado, autenticidad y round-trip.
//
// Cubre lo que realmente importa de la función: que el payload NO viaje
// legible, que un enlace manipulado se rechace y que los datos de la canción
// (ISRC incluido) sobrevivan el viaje completo.

import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/servicios/compartir/cifrado_compartir.dart';
import 'package:bitly/core/servicios/compartir/datos_compartido.dart';
import 'package:bitly/core/servicios/compartir/servicio_compartir.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CifradoCompartir', () {
    test('cifra y descifra sin perder el texto', () {
      const original = '{"n":"Canción de prueba","i":"USUM71703861"}';
      final cifrado = CifradoCompartir.cifrar(original);
      expect(cifrado, isNot(contains('Canción')));
      expect(CifradoCompartir.descifrar(cifrado), original);
    });

    test('dos enlaces del mismo texto salen distintos (nonce aleatorio)', () {
      final a = CifradoCompartir.cifrar('hola');
      final b = CifradoCompartir.cifrar('hola');
      expect(a, isNot(equals(b)));
      expect(CifradoCompartir.descifrar(a), 'hola');
      expect(CifradoCompartir.descifrar(b), 'hola');
    });

    test('un payload manipulado se rechaza', () {
      final cifrado = CifradoCompartir.cifrar('{"n":"x"}');
      final partes = cifrado.split('');
      // Cambia un byte del cuerpo: el MAC ya no valida.
      partes[partes.length - 2] = partes[partes.length - 2] == 'A' ? 'B' : 'A';
      expect(CifradoCompartir.descifrar(partes.join()), isNull);
    });

    test('basura y vacío devuelven null en vez de romper', () {
      expect(CifradoCompartir.descifrar(''), isNull);
      expect(CifradoCompartir.descifrar('no-es-base64!!'), isNull);
      expect(CifradoCompartir.descifrar('QUJD'), isNull);
    });
  });

  group('ServicioCompartir', () {
    const item = ItemFeed(
      id: 'spotify:track:1',
      type: 'track',
      name: 'Nombre Canción',
      artists: 'Artista',
      albumName: 'Álbum',
      coverUrl: 'https://img/x.jpg',
      isrc: 'USUM71703861',
      spotifyId: '1',
      durationMs: 200000,
    );

    test('el enlace lleva los datos y no el nombre en claro', () {
      final enlace = ServicioCompartir.instance
          .construirEnlace(DatosCompartido.desdeItem(item, emisor: 'Pablo'));
      // El host sale de la constante: es el mismo declarado en el manifest de
      // Android y en el entitlement de iOS (si no coinciden, el enlace no abre
      // la app directo).
      expect(
        enlace.startsWith('https://${ServicioCompartir.host}/open?s='),
        isTrue,
      );
      expect(enlace, isNot(contains('Nombre Canción')));
      expect(enlace, isNot(contains('USUM71703861')));
    });

    test('round-trip completo conserva ISRC, nombre y emisor', () {
      final datos = DatosCompartido.desdeItem(item, emisor: 'Pablo');
      final enlace = ServicioCompartir.instance.construirEnlace(datos);
      final leido = ServicioCompartir.instance.leerEnlace(enlace);
      expect(leido, isNotNull);
      expect(leido!.isrc, 'USUM71703861');
      expect(leido.nombre, 'Nombre Canción');
      expect(leido.artista, 'Artista');
      expect(leido.album, 'Álbum');
      expect(leido.emisor, 'Pablo');
      expect(leido.duracionMs, 200000);
      expect(leido.comoItem.isrc, 'USUM71703861');
    });

    test('acepta el esquema bitly:// y rechaza otros hosts', () {
      final datos = DatosCompartido.desdeItem(item);
      final payload = CifradoCompartir.cifrar(
        '{"t":"track","n":"Nombre","i":"USUM71703861"}',
      );
      expect(
        ServicioCompartir.instance.leerEnlace('bitly://open?s=$payload'),
        isNotNull,
      );
      expect(
        ServicioCompartir.instance.leerEnlace('https://otro.com/open?s=$payload'),
        isNull,
      );
      expect(datos.valido, isTrue);
    });

    test('un enlace sin datos útiles se ignora', () {
      final payload = CifradoCompartir.cifrar('{"t":"track"}');
      expect(
        ServicioCompartir.instance.leerEnlace(
          'https://bitly.app/open?s=$payload',
        ),
        isNull,
      );
    });
  });
}
