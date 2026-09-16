// Tests del sembrado de cola con CONTEXTO (reproducir una fila de un álbum,
// playlist o artista).
//
// Lo que fija: el track tocado SIEMPRE queda como actual. Antes, cuando el
// contexto no contenía el item tocado (id de proveedor distinto o lista
// recortada), el índice caía a 0 y el player abría OTRA canción; al terminar,
// el avance continuaba desde un lugar equivocado de la cola.

import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/estado/cola/cubit_cola.dart';
import 'package:flutter_test/flutter_test.dart';

ItemFeed _track(String id, {String? name, String? source, String? artists}) =>
    ItemFeed(
      id: id,
      type: 'track',
      name: name ?? 'Tema $id',
      source: source ?? 'deezer',
      artists: artists,
    );

void main() {
  group('reproducirConContexto', () {
    test('la fila tocada queda como actual (no la primera de la lista)', () {
      final items = [_track('a'), _track('b'), _track('c')];
      final cola = CubitCola()..reproducirConContexto(items, items[2]);
      expect(cola.state.indiceActual, 2);
      expect(cola.state.actual?.id, 'c');
    });

    test('al terminar sigue con la SIGUIENTE de la lista', () {
      final items = [_track('a'), _track('b'), _track('c'), _track('d')];
      final cola = CubitCola()..reproducirConContexto(items, items[1]);
      expect(cola.siguiente(), isTrue);
      expect(cola.state.actual?.id, 'c');
    });

    test('encuentra la fila aunque cambie el prefijo de proveedor del id', () {
      final items = [_track('1'), _track('deezer:2'), _track('3')];
      final cola = CubitCola()..reproducirConContexto(items, _track('2'));
      expect(cola.state.actual?.id, 'deezer:2');
      expect(cola.state.indiceActual, 1);
    });

    test('encuentra la fila por nombre + artista cuando el id no coincide', () {
      final items = [
        _track('x', name: 'Otra', artists: 'Nadie'),
        _track('y', name: 'Tema', artists: 'Artista'),
      ];
      final cola = CubitCola()
        ..reproducirConContexto(items, _track('z', name: 'Tema', artists: 'Artista'));
      expect(cola.state.actual?.id, 'y');
    });

    test('si el contexto no la contiene, la fila tocada va primera', () {
      final items = [_track('a'), _track('b')];
      final tocada = _track('z', name: 'Distinta');
      final cola = CubitCola()..reproducirConContexto(items, tocada);
      expect(cola.state.indiceActual, 0);
      expect(cola.state.actual?.id, 'z');
      // Y el contexto sigue detrás, sin perderse.
      expect(cola.state.tracks.length, 3);
      expect(cola.siguiente(), isTrue);
      expect(cola.state.actual?.id, 'a');
    });

    test('contexto vacío cae a cola de un solo item', () {
      final cola = CubitCola()..reproducirConContexto(const [], _track('solo'));
      expect(cola.state.tracks.length, 1);
      expect(cola.state.actual?.id, 'solo');
    });
  });
}
