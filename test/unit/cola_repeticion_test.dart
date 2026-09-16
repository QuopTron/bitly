// Tests de la navegación de la cola: siguiente/anterior y, sobre todo, el
// principio de repetición que pidió el usuario.
//
// Lo que fija (y antes estaba mal): el shuffle SOLO cambia el ORDEN. Sin
// repetición marcada la cola se recorre UNA vez y termina; con repetición de
// toda la cola vuelve a empezar; con el "1" repite la misma canción.

import 'package:bitly/core/cache/estado/estado_cola.dart';
import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/estado/cola/cubit_cola.dart';
import 'package:flutter_test/flutter_test.dart';

List<ItemFeed> _tracks(int n) => List.generate(
      n,
      (i) => ItemFeed(id: 't$i', type: 'track', name: 'Tema $i', source: 'test'),
    );

void main() {
  group('Cola sin shuffle', () {
    test('sin repetición la cola se recorre una sola vez y termina', () {
      final cola = CubitCola()..reproducirLista(_tracks(3));
      expect(cola.siguiente(), isTrue);
      expect(cola.siguiente(), isTrue);
      // Cuarta llamada: se acabó.
      expect(cola.siguiente(), isFalse);
      expect(cola.state.tieneActual, isFalse);
    });

    test('con repetición de toda la cola vuelve al principio', () {
      final cola = CubitCola()
        ..reproducirLista(_tracks(3))
        ..setModoRepeticionStr('all');
      cola.siguiente();
      cola.siguiente();
      expect(cola.siguiente(), isTrue);
      expect(cola.state.indiceActual, 0);
    });

    test('anterior en la primera canción con repetición va a la última', () {
      final cola = CubitCola()
        ..reproducirLista(_tracks(3))
        ..setModoRepeticionStr('all');
      expect(cola.state.indiceActual, 0);
      cola.anterior();
      expect(cola.state.indiceActual, 2);
    });
  });

  group('Cola con shuffle', () {
    test('sin repetición pasa por TODAS las canciones y después termina', () {
      final cola = CubitCola()
        ..reproducirLista(_tracks(6))
        ..setShuffle(true);
      final vistas = <int>{cola.state.indiceActual};
      // 5 avances = las 6 canciones exactamente una vez.
      for (var i = 0; i < 5; i++) {
        expect(cola.siguiente(), isTrue, reason: 'avance ${i + 1}');
        expect(
          vistas.add(cola.state.indiceActual),
          isTrue,
          reason: 'el shuffle repitió una canción antes de recorrerlas todas',
        );
      }
      expect(vistas.length, 6);
      // Y ahora sí: agotada.
      expect(cola.siguiente(), isFalse);
    });

    test('con repetición de toda la cola sigue sonando (nueva vuelta)', () {
      final cola = CubitCola()
        ..reproducirLista(_tracks(4))
        ..setShuffle(true)
        ..setModoRepeticionStr('all');
      for (var i = 0; i < 12; i++) {
        expect(cola.siguiente(), isTrue, reason: 'avance ${i + 1}');
      }
      expect(cola.state.tieneActual, isTrue);
    });

    test('el shuffle no rompe el repeat de una sola canción', () {
      final cola = CubitCola()
        ..reproducirLista(_tracks(3))
        ..setShuffle(true)
        ..setModoRepeticionStr('one');
      // Con repeat-one el replay del tema lo hace el player al terminar; el
      // avance manual sigue funcionando y la cola nunca se agota.
      for (var i = 0; i < 8; i++) {
        expect(cola.siguiente(), isTrue, reason: 'avance ${i + 1}');
      }
    });

    test('volver atrás y avanzar cae en la MISMA canción', () {
      final cola = CubitCola()
        ..reproducirLista(_tracks(8))
        ..setShuffle(true);
      cola.siguiente();
      final segunda = cola.state.indiceActual;
      cola.siguiente();
      cola.anterior();
      expect(cola.state.indiceActual, segunda);
      expect(cola.siguiente(), isTrue);
    });

    test('agregar un tema a la cola rebaraja sin trabarse', () {
      final cola = CubitCola()
        ..reproducirLista(_tracks(3))
        ..setShuffle(true);
      cola.agregarAlFinal(ItemFeed(id: 'nuevo', type: 'track', name: 'Nuevo'));
      expect(cola.state.tracks.length, 4);
      expect(cola.siguiente(), isTrue);
    });
  });

  group('Ciclo de la tecla de repetición', () {
    test('sin marcar → toda la cola → una canción → sin marcar', () {
      final cola = CubitCola()..reproducirLista(_tracks(2));
      expect(cola.state.modoRepeticion, ModoRepeticion.ninguno);
      cola.ciclarModoRepeticion();
      expect(cola.state.modoRepeticion, ModoRepeticion.todos);
      cola.ciclarModoRepeticion();
      expect(cola.state.modoRepeticion, ModoRepeticion.uno);
      cola.ciclarModoRepeticion();
      expect(cola.state.modoRepeticion, ModoRepeticion.ninguno);
    });
  });
}
