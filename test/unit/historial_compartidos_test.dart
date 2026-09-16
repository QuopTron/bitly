// Tests del historial de compartidos (la parte pura: orden, dedupe, tope y
// serialización). Es lo que respalda la pestaña Ajustes → Compartidos.

import 'package:bitly/core/servicios/compartir/compartido_recibido.dart';
import 'package:bitly/core/servicios/compartir/datos_compartido.dart';
import 'package:bitly/core/servicios/compartir/historial_compartidos_puro.dart';
import 'package:flutter_test/flutter_test.dart';

CompartidoRecibido _entrada({
  String emisor = 'Pablo',
  String isrc = 'USUM71703861',
  String nombre = 'Todo de Ti',
  int minuto = 0,
}) =>
    CompartidoRecibido(
      datos: DatosCompartido(
        isrc: isrc,
        nombre: nombre,
        artista: 'Rauw Alejandro',
        emisor: emisor,
      ),
      fecha: DateTime(2026, 9, 15, 12, minuto),
    );

void main() {
  group('nuevoHistorial', () {
    test('lo nuevo va primero', () {
      final lista = nuevoHistorial(
        [_entrada(nombre: 'Vieja', isrc: 'AAA')],
        _entrada(nombre: 'Nueva', isrc: 'BBB'),
      );
      expect(lista.first.datos.nombre, 'Nueva');
      expect(lista.length, 2);
    });

    test('no repite la misma canción del mismo emisor: la reubica', () {
      final lista = nuevoHistorial(
        [
          _entrada(nombre: 'Otra', isrc: 'AAA'),
          _entrada(nombre: 'Todo de Ti', isrc: 'USUM71703861'),
        ],
        _entrada(),
      );
      expect(lista.length, 2);
      expect(lista.first.datos.isrc, 'USUM71703861');
    });

    test('la misma canción de otro emisor sí se guarda aparte', () {
      final lista = nuevoHistorial(
        [_entrada(emisor: 'Ana')],
        _entrada(emisor: 'Pablo'),
      );
      expect(lista.length, 2);
    });

    test('respeta el tope', () {
      var lista = <CompartidoRecibido>[];
      for (var i = 0; i < 12; i++) {
        lista = nuevoHistorial(
          lista,
          _entrada(isrc: 'ISRC$i', nombre: 'Cancion $i', minuto: i),
          maximo: 5,
        );
      }
      expect(lista.length, 5);
      expect(lista.first.datos.nombre, 'Cancion 11');
    });
  });

  group('codificar / decodificar', () {
    test('round-trip conserva emisor, canción, ISRC y fecha', () {
      final original = _entrada(minuto: 30);
      final vuelta = decodificarHistorial(codificarHistorial([original]));
      expect(vuelta.length, 1);
      expect(vuelta.first.datos.emisor, 'Pablo');
      expect(vuelta.first.datos.nombre, 'Todo de Ti');
      expect(vuelta.first.datos.isrc, 'USUM71703861');
      expect(vuelta.first.fecha.minute, 30);
    });

    test('tolera vacío, basura y entradas sin datos', () {
      expect(decodificarHistorial(null), isEmpty);
      expect(decodificarHistorial(''), isEmpty);
      expect(decodificarHistorial('no-json'), isEmpty);
      expect(decodificarHistorial('{"a":1}'), isEmpty);
      expect(decodificarHistorial('[{"t":"track","u":"Ana"}'), isEmpty);
      expect(decodificarHistorial('[{"t":"track","u":"Ana"}]'), isEmpty);
    });

    test('entrada sin fecha válida no rompe (usa ahora)', () {
      final vuelta = decodificarHistorial(
        '[{"t":"track","u":"Ana","n":"Cancion","ts":"malo"}]',
      );
      expect(vuelta.length, 1);
      expect(vuelta.first.datos.emisor, 'Ana');
    });
  });
}
