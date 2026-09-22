// busqueda_sin_reintentos_test.dart — Fija que una búsqueda NO se vuelva a
// lanzar por su cuenta.
//
// Antes había tres reintentos en el camino de la búsqueda. Dos de ellos
// re-ejecutaban TODOS los proveedores (resultado vacío "demasiado rápido" y
// ventana de poll agotada sin `done`) y existían para compensar a un backend
// que podía tardar 40s o quedarse colgado; el usuario lo pagaba como "busco y
// tarda 10 segundos". El backend ya acota cada proveedor por tiempo y siempre
// cierra la sesión con `done`, así que esos reintentos solo duplicaban el
// trabajo. Lo que sí sobrevive es el reintento del INIT cuando el backend
// contesta que no arrancó nada (gen == 0) y la tolerancia a un poll caído.
//
// Se conecta con: features/busqueda/bloc/base/busqueda_bloc.dart (el bloc) y
// core/backend_go (el RPC de búsqueda en streaming).
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:bitly/core/backend_go/mixins/musica/feed_busqueda_mixin.dart';
import 'package:bitly/core/backend_go/nucleo/base/contrato_backend.dart';
import 'package:bitly/core/backend_go/nucleo/datos/resultados_busqueda_stream.dart';
import 'package:bitly/core/cache/almacenes/musica/cache_busqueda.dart';
import 'package:bitly/core/modelos/feed/item_feed.dart';
import 'package:bitly/core/modelos/proveedores/base/config_busqueda_fuente.dart';
import 'package:bitly/features/busqueda/bloc/base/busqueda_bloc.dart';
import 'package:bitly/features/busqueda/bloc/base/busqueda_estado.dart';
import 'package:bitly/features/busqueda/bloc/base/busqueda_evento.dart';

class _BackendFalso extends Mock implements BackendService {}

class _CacheFalso extends Mock implements CacheBusqueda {}

/// Backend mínimo que corre el mixin DE VERDAD (no un mock): solo se sustituye
/// el transporte RPC, que es lo único que el mixin usa del backend.
class _BackendConMixin extends BackendService with FeedBusquedaMixin {
  _BackendConMixin(this._responder);

  final Future<dynamic> Function() _responder;
  int llamadasRpc = 0;

  @override
  Future<dynamic> rpcCall(
    String method, [
    Map<String, dynamic>? params,
    Duration? timeout,
  ]) {
    llamadasRpc++;
    return _responder();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} no se usa en el test');
}

const _fuente = 'deezer';
const _query = 'numb';

/// Espera a que el intento termine de verdad (el sondeo avanza cada 80ms).
Future<void> _dejarCorrer([int ms = 900]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

/// Bloc listo para una búsqueda: recientes vacías y sin config de fuente.
BlocBusqueda _bloc(_BackendFalso backend, _CacheFalso cache) {
  when(() => cache.getBusquedasRecientes(limit: any(named: 'limit')))
      .thenAnswer((_) async => const <String>[]);
  when(() => cache.guardarBusquedaReciente(any())).thenAnswer((_) async {});
  when(() => backend.getSearchConfig())
      .thenAnswer((_) async => const <ConfigBusquedaFuente>[]);
  return BlocBusqueda(backend, cache);
}

/// Devuelve la secuencia de polls indicada; repite el último si se sondea más.
void _servirPolls(_BackendFalso backend, List<ResultadosBusquedaStream> polls) {
  var i = 0;
  when(() => backend.getSearchStreamResults()).thenAnswer((_) async {
    final idx = i < polls.length ? i : polls.length - 1;
    i++;
    return polls[idx];
  });
}

/// Un intento como el del usuario: fuente concreta y tipo tracks.
void _buscar(BlocBusqueda bloc) {
  bloc.add(
    const EjecutarBusqueda(
      query: _query,
      fuente: _fuente,
      tipo: 'tracks',
      limite: 25,
    ),
  );
}

void main() {
  late _BackendFalso backend;
  late _CacheFalso cache;
  late BlocBusqueda bloc;

  setUp(() {
    backend = _BackendFalso();
    cache = _CacheFalso();
    bloc = _bloc(backend, cache);
    when(
      () => backend.searchStreaming(
        query: _query,
        source: _fuente,
        type: 'tracks',
        limit: 25,
      ),
    ).thenAnswer((_) async => 1);
  });

  tearDown(() => bloc.close());

  test('un vacío rápido del backend NO vuelve a lanzar la búsqueda', () async {
    // Este es exactamente el caso que antes disparaba el reintento ciego:
    // fuente concreta + `done` con cero items en menos de 3,5s.
    _servirPolls(backend, const [
      ResultadosBusquedaStream(items: [], done: true, generation: 1),
    ]);

    _buscar(bloc);
    await _dejarCorrer();

    // Una sola sesión de búsqueda: nada de proveedores corriendo dos veces.
    verify(
      () => backend.searchStreaming(
        query: _query,
        source: _fuente,
        type: 'tracks',
        limit: 25,
      ),
    ).called(1);

    expect(bloc.state.cargando, isFalse);
    expect(bloc.state.haBuscado, isTrue);
    expect(bloc.state.resultados, isEmpty);
  });

  test('un poll caído no abandona la búsqueda ni la relanza', () async {
    final cancion = const ItemFeed(id: 't1', type: 'track', name: 'Numb');
    _servirPolls(backend, [
      // El RPC del puente falla en el primer sondeo: la sesión sigue viva en
      // Go, así que hay que seguir sondeando, no re-lanzar la búsqueda.
      const ResultadosBusquedaStream(
        items: [],
        done: false,
        generation: 0,
        fallo: true,
      ),
      ResultadosBusquedaStream(items: [cancion], done: true, generation: 1),
    ]);

    _buscar(bloc);
    await _dejarCorrer();

    expect(bloc.state.resultados.single.id, 't1');
    expect(bloc.state.cargando, isFalse);
    verify(
      () => backend.searchStreaming(
        query: _query,
        source: _fuente,
        type: 'tracks',
        limit: 25,
      ),
    ).called(1);
  });

  test('si el backend no arrancó (gen 0), reintenta el init una vez', () async {
    // Reintentar el INIT no duplica proveedores: el backend contestó que no
    // arrancó ninguna búsqueda. Solo el primer init falla acá.
    var init = 0;
    when(
      () => backend.searchStreaming(
        query: _query,
        source: _fuente,
        type: 'tracks',
        limit: 25,
      ),
    ).thenAnswer((_) async => ++init == 1 ? 0 : 7);

    final cancion = const ItemFeed(id: 't2', type: 'track', name: 'Clocks');
    _servirPolls(backend, [
      ResultadosBusquedaStream(items: [cancion], done: true, generation: 7),
    ]);

    _buscar(bloc);
    await _dejarCorrer();

    expect(init, 2);
    expect(bloc.state.resultados.single.id, 't2');
  });

  test('la búsqueda combinada NO se relanza tras un fallo del RPC', () async {
    // Antes: si `search` lanzaba, esperaba 2s y repetía la consulta completa.
    // El puente ya no serializa en un hilo y el timeout real es 45s, así que
    // repetir la misma consulta falla igual: solo duplica el trabajo.
    final backendReal = _BackendConMixin(
      () async => throw Exception('RPC caído'),
    );

    final resultados = await backendReal.search(query: _query, source: _fuente);

    expect(resultados, isEmpty);
    expect(backendReal.llamadasRpc, 1);
  });

  test('si NINGUNA fuente respondió, es error — no "sin resultados"', () async {
    // El caso que se está arreglando: la fuente se cayó y la UI decía "sin
    // resultados", que manda al usuario a revisar la consulta cuando en
    // realidad no se le pudo preguntar a nadie.
    _servirPolls(backend, const [
      ResultadosBusquedaStream(
        items: [],
        done: true,
        generation: 1,
        fallidas: ['deezer'],
        fuentesOk: 0,
      ),
    ]);

    _buscar(bloc);
    await _dejarCorrer();

    expect(bloc.state.error, ErrorBusqueda.fallo);
    expect(bloc.state.fuenteError, _fuente);
    expect(bloc.state.cargando, isFalse);
    expect(bloc.state.haBuscado, isTrue);
  });

  test('un fallo NO se cachea como vacío: la próxima vuelve a preguntar', () async {
    _servirPolls(backend, const [
      ResultadosBusquedaStream(
        items: [],
        done: true,
        generation: 1,
        fallidas: ['deezer'],
        fuentesOk: 0,
      ),
    ]);

    _buscar(bloc);
    await _dejarCorrer();
    _buscar(bloc);
    await _dejarCorrer();

    verify(
      () => backend.searchStreaming(
        query: _query,
        source: _fuente,
        type: 'tracks',
        limit: 25,
      ),
    ).called(2);
  });

  test('un vacío REAL (la fuente contestó) sigue siendo "sin resultados"', () async {
    _servirPolls(backend, const [
      ResultadosBusquedaStream(
        items: [],
        done: true,
        generation: 1,
        fallidas: [],
        fuentesOk: 1,
      ),
    ]);

    _buscar(bloc);
    await _dejarCorrer();

    expect(bloc.state.error, isNull);
    expect(bloc.state.resultados, isEmpty);
    expect(bloc.state.haBuscado, isTrue);
  });

  test('en "Todas", que falle una fuente no tumba las que sí respondieron', () async {
    // 7 fuentes contestaron "no tengo nada" y una se cayó: la verdad para el
    // usuario es "sin resultados", no un error que no puede arreglar.
    when(
      () => backend.searchStreaming(
        query: _query,
        source: '',
        type: 'tracks',
        limit: 25,
      ),
    ).thenAnswer((_) async => 1);
    _servirPolls(backend, const [
      ResultadosBusquedaStream(
        items: [],
        done: true,
        generation: 1,
        fallidas: ['tidal-web'],
        fuentesOk: 7,
      ),
    ]);

    bloc.add(
      const EjecutarBusqueda(query: _query, fuente: '', tipo: 'tracks', limite: 25),
    );
    await _dejarCorrer();

    expect(bloc.state.error, isNull);
    expect(bloc.state.haBuscado, isTrue);
  });

  test('una sesión de streaming perdida no deja la UI cargando', () async {
    // gen 0 con la sesión en 1 = el backend perdió la búsqueda (reinicio del
    // proceso). Antes esto salía sin emitir y el spinner quedaba hasta que el
    // watchdog de la página lo cortaba.
    _servirPolls(backend, const [
      ResultadosBusquedaStream(items: [], done: false, generation: 0),
    ]);

    _buscar(bloc);
    await _dejarCorrer();

    expect(bloc.state.cargando, isFalse);
    expect(bloc.state.haBuscado, isTrue);
  });
}
