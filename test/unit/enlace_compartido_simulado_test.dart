// ignore_for_file: avoid_print
//
// Simulación de "compartir una canción": usa el código REAL
// (ServicioCompartir + CifradoCompartir) para mostrar exactamente qué
// enlace sale por WhatsApp y comprobar que Bitly lo entiende al volver.
//
// Corre con:  flutter test test/unit/enlace_compartido_simulado_test.dart
// Imprime la línea `ENLACE: ...` que se puede pegar en un dispositivo:
//   adb shell am start -a android.intent.action.VIEW -d "<enlace>" -p com.example.bitly

import 'dart:convert';

import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/servicios/compartir/cifrado_compartir.dart';
import 'package:bitly/core/servicios/compartir/datos_compartido.dart';
import 'package:bitly/core/servicios/compartir/servicio_compartir.dart';
import 'package:flutter_test/flutter_test.dart';

/// La canción que "comparte" el usuario. La carátula es una URL REAL
/// (la del álbum que ya está en la biblioteca del dispositivo), así al
/// abrir el enlace se ve la portada de verdad.
const _cancion = ItemFeed(
  id: 'spotify:track:5TFD2bmFKGhoCRbX61nXY5',
  type: 'track',
  name: 'NUEVAYoL',
  artists: 'Bad Bunny',
  albumName: 'DeBÍ TiRAR MáS FOToS',
  coverUrl: 'https://i.scdn.co/image/ab67616d000082c1bbd45c8d36e0e045ef640411',
  durationMs: 183685,
  isrc: 'USUM72500857',
  spotifyId: '5TFD2bmFKGhoCRbX61nXY5',
  deezerId: '1516857112',
);

void main() {
  test('simula compartir y muestra el enlace que se envía', () {
    final datos = DatosCompartido.desdeItem(_cancion, emisor: 'Pablo');
    final enlace = ServicioCompartir.instance.construirEnlace(datos);
    final texto = '🎵 ${_cancion.name} — ${_cancion.artists}\n$enlace';

    // Lo que viaja dentro del enlace (no se ve: está cifrado).
    final json = jsonEncode(datos.aJson());

    print('── MENSAJE QUE SALE POR WHATSAPP ───────────────────────');
    print(texto);
    print('── DETALLE ─────────────────────────────────────────────');
    print('largo del enlace : ${enlace.length} caracteres');
    print('payload en claro : $json');
    print('payload cifrado  : ${enlace.split('s=').last}');
    print('ENLACE: $enlace');

    // Vuelta: lo que Bitly lee al abrir el enlace.
    final leido = ServicioCompartir.instance.leerEnlace(enlace);
    expect(leido, isNotNull);
    print('── LO QUE LEE BITLY ────────────────────────────────────');
    print('emisor   : ${leido!.emisor}');
    print('canción  : ${leido.nombre}');
    print('artista  : ${leido.artista}');
    print('ISRC     : ${leido.isrc}');
    print('álbum    : ${leido.album}');
    print('duración : ${leido.duracionMs} ms');
    print('carátula : ${leido.caratula}');
    expect(leido.isrc, 'USUM72500857');
    expect(leido.emisor, 'Pablo');
    // El texto en claro NO viaja en el enlace.
    expect(enlace.contains('NUEVAYoL'), isFalse);
    expect(enlace.contains('USUM72500857'), isFalse);

    // Un enlace tocado a mano se rechaza.
    final partes = enlace.split('');
    partes[partes.length - 2] = partes[partes.length - 2] == 'A' ? 'B' : 'A';
    expect(CifradoCompartir.descifrar(partes.join().split('s=').last), isNull);
  });
}
