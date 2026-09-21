// Test del vínculo entre aparatos en la red local: el protocolo puro
// (anuncios, token, nombres de archivo, qué falta) y el traspaso REAL entre
// dos aparatos, con dos mini-servidores en 127.0.0.1.
//
// El traspaso es el que importa: se vinculan, el que tiene el archivo lo
// presta y el otro termina con el archivo en su carpeta y en su base, como si
// lo hubiera bajado él. Sin servidor en el medio.
//
// Si el entorno no expone SQLite nativo, se saltea la parte de traspaso (el
// protocolo puro se prueba igual).

import 'dart:convert';
import 'dart:io' as io;

import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/sistema/cache_ajustes.dart';
import 'package:bitly/core/cache/almacenes/descargas/cache_descargas.dart';
import 'package:bitly/core/servicios/lan/modelos/lan_modelos.dart';
import 'package:bitly/core/servicios/lan/modelos/lan_protocolo.dart';
import 'package:bitly/core/servicios/lan/servicio/base/servicio_lan.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('protocolo', () {
    test('el anuncio se lee y se ignoran los ajenos', () {
      final bueno = armarAnuncio(id: 'dev_a', nombre: 'Celu', puerto: 5000);
      final par = leerAnuncio(bueno, idPropio: 'dev_b');
      expect(par?.id, 'dev_a');
      expect(par?.nombre, 'Celu');
      expect(par?.puerto, 5000);

      // El propio aparato se escucha a sí mismo: no es un vecino.
      expect(leerAnuncio(bueno, idPropio: 'dev_a'), isNull);
      // Otro programa en el mismo puerto, o versión distinta.
      expect(
        leerAnuncio(
          '{"app":"otra","v":1,"id":"x","puerto":1}',
          idPropio: 'dev_b',
        ),
        isNull,
      );
      expect(
        leerAnuncio(
          '{"app":"bitly","v":99,"id":"x","puerto":1}',
          idPropio: 'dev_b',
        ),
        isNull,
      );
      expect(leerAnuncio('no es json', idPropio: 'dev_b'), isNull);
    });

    test('el token solo pasa si es igual', () {
      expect(tokenValido('abc123', 'abc123'), isTrue);
      expect(tokenValido('abc124', 'abc123'), isFalse);
      expect(tokenValido('abc12', 'abc123'), isFalse);
      expect(tokenValido(null, 'abc123'), isFalse);
      // Un aparato sin token configurado no autoriza a nadie.
      expect(tokenValido('', ''), isFalse);
    });

    test('el nombre de archivo no puede salirse de la carpeta', () {
      expect(nombreArchivoSeguro('tema-1.flac'), 'tema-1.flac');
      expect(nombreArchivoSeguro('../secretos.txt'), isNull);
      expect(nombreArchivoSeguro('carpeta/tema.flac'), isNull);
      expect(nombreArchivoSeguro(r'carpeta\tema.flac'), isNull);
      expect(nombreArchivoSeguro('  '), isNull);
      expect(nombreArchivoSeguro(null), isNull);
      expect(nombreArchivoSeguro('a' * 200), isNull);
      expect(nombreArchivoSeguro('con espacio.flac'), isNull);
    });

    test('la identidad de una canción usa el ISRC y si no nombre+artista', () {
      const conIsrc = CancionLan(
        id: '1',
        nombre: 'Cualquiera',
        artista: 'Alguien',
        isrc: 'usrc17607839',
      );
      expect(conIsrc.clave, 'isrc:USRC17607839');

      const sinIsrc = CancionLan(
        id: '2',
        nombre: 'Canción Ñoña!',
        artista: 'Beyoncé',
      );
      const igual = CancionLan(
        id: '3',
        nombre: 'cancion nona',
        artista: 'beyonce',
      );
      expect(sinIsrc.clave, igual.clave);
    });

    test('faltantes: lo que hay allá y no acá, por identidad', () {
      const alla = [
        CancionLan(id: 'a', nombre: 'Uno', artista: 'X', isrc: 'AAA111'),
        CancionLan(id: 'b', nombre: 'Dos', artista: 'Y'),
        CancionLan(id: 'c', nombre: 'Tres', artista: 'Z'),
      ];
      final faltan = faltantesPara(alla, {
        'isrc:AAA111',
        CancionLan(id: 'x', nombre: 'DOS', artista: 'y').clave,
      });
      expect(faltan.map((c) => c.id), ['c']);
    });

    test('un par sin verse hace rato no está en línea', () {
      const par = ParLan(
        id: 'dev',
        nombre: 'PC',
        host: '10.0.0.2',
        puerto: 1,
        token: 'tok',
        ultimaVezMs: 1000,
      );
      expect(par.enLineaEn(2000), isTrue);
      expect(par.enLineaEn(1000 + 60000), isFalse);
      // Un par sin token está descubierto, pero no vinculado.
      expect(
        const ParLan(id: 'd', nombre: 'n', host: 'h', puerto: 2).vinculado,
        isFalse,
      );
    });
  });

  group('traspaso entre dos aparatos', () {
    late io.Directory dirA;
    late io.Directory dirB;
    late AppDatabase dbA;
    late AppDatabase dbB;
    late ServicioLan aparatoA;
    late ServicioLan aparatoB;
    var haySqlite = true;

    setUpAll(() {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      try {
        dbA = AppDatabase(NativeDatabase.memory());
        dbB = AppDatabase(NativeDatabase.memory());
      } catch (_) {
        haySqlite = false;
        return;
      }
      dirA = await io.Directory.systemTemp.createTemp('bitly_lan_a');
      dirB = await io.Directory.systemTemp.createTemp('bitly_lan_b');

      // El aparato A tiene una canción descargada de verdad (archivo + fila)
      // con su carátula y su letra al lado, como las deja una descarga normal.
      final sep = io.Platform.pathSeparator;
      final archivo = io.File('${dirA.path}${sep}tema1.flac');
      await archivo.writeAsBytes(List<int>.generate(64, (i) => i));
      final cover = io.File('${dirA.path}${sep}tema1.jpg');
      await cover.writeAsBytes(List<int>.filled(16, 7));
      final letra = io.File('${dirA.path}$sep${_nombreLetra('tema1')}');
      await letra.writeAsString('[00:01.00] Hola\n');
      await dbA.downloadDao.saveEntry(
        DownloadHistoryCompanion.insert(
          id: 'tema1',
          trackName: 'Tema uno',
          artistName: 'Artista',
          downloadedAt: DateTime.now(),
          isrc: const Value('USRC17607839'),
          filePath: Value(archivo.path),
          duration: const Value(180000),
          service: const Value('youtube'),
          coverUrl: const Value('https://ejemplo/c.jpg'),
          coverPath: Value(cover.path),
        ),
      );

      final cacheA = CacheAjustes(dbA);
      await cacheA.guardarAjuste('download_path', dirA.path);
      aparatoA = ServicioLan(
        cache: cacheA,
        descargas: CacheDescargas(dbA),
        db: dbA,
        identidad: () async => ('dev_a', 'PC del cuarto'),
      );
      await aparatoA.iniciar();

      // B no tiene nada descargado todavía.
      final cacheB = CacheAjustes(dbB);
      await cacheB.guardarAjuste('download_path', dirB.path);
      aparatoB = ServicioLan(
        cache: cacheB,
        descargas: CacheDescargas(dbB),
        db: dbB,
        identidad: () async => ('dev_b', 'Celu de Pablo'),
      );
      await aparatoB.iniciar();
    });

    tearDown(() async {
      await aparatoA.detener();
      await aparatoB.detener();
      if (haySqlite) {
        await dbA.close();
        await dbB.close();
      }
      if (dirA.existsSync()) await dirA.delete(recursive: true);
      if (dirB.existsSync()) await dirB.delete(recursive: true);
    });

    test('el que no está vinculado no puede pedir el catálogo', () async {
      expect(haySqlite, isTrue, reason: 'SQLite nativo no disponible');
      final curioso = ParLan(
        id: 'dev_b',
        nombre: 'Celu',
        host: '127.0.0.1',
        puerto: aparatoA.puerto,
      );
      // Sin token: el mini-servidor de A no le da nada.
      expect(await aparatoA.traerIndice(curioso), isNull);
      // Con un token inventado, tampoco.
      expect(
        await aparatoA.traerIndice(curioso.copiarCon(token: 'falso')),
        isNull,
      );
    });

    test('se vinculan y el archivo llega al otro aparato', () async {
      expect(haySqlite, isTrue, reason: 'SQLite nativo no disponible');
      final vecinoA = ParLan(
        id: 'dev_a',
        nombre: 'PC del cuarto',
        host: '127.0.0.1',
        puerto: aparatoA.puerto,
        ultimaVezMs: DateTime.now().millisecondsSinceEpoch,
      );

      // B pide el vínculo; A lo decide (el usuario acepta).
      final pidiendo = aparatoB.pedirVinculo(vecinoA);
      await _esperarSolicitud(aparatoA);
      await aparatoA.responderSolicitud(true);
      final vinculado = await pidiendo;
      expect(vinculado, isNotNull);
      expect(vinculado!.vinculado, isTrue);

      // Ahora sí: B lee el catálogo de A y lo que le falta es la canción.
      final faltan = await aparatoB.faltantesDe(vinculado);
      expect(faltan, isNotNull);
      expect(faltan!.map((c) => c.id), ['tema1']);
      expect(faltan.single.bytes, 64);
      expect(faltan.single.ext, 'flac');
      // El catálogo dice que trae carátula y letra, así se piden.
      expect(faltan.single.extCover, 'jpg');
      expect(faltan.single.tieneLetra, isTrue);
      expect(faltan.single.coverUrl, 'https://ejemplo/c.jpg');

      // Y la trae: el archivo queda en la carpeta de B y en su base.
      final (copiadas, cancelado) = await aparatoB.traerFaltantes(vinculado);
      expect(copiadas, 1);
      expect(cancelado, isFalse);
      final traido = io.File(
        '${dirB.path}${io.Platform.pathSeparator}tema1.flac',
      );
      expect(traido.existsSync(), isTrue);
      expect(traido.lengthSync(), 64);
      expect(await aparatoB.clavesLocales(), contains('isrc:USRC17607839'));

      // Y la canción viaja COMPLETA: carátula y letra al lado del audio, con
      // los nombres que la app espera en la carpeta de B.
      final sep = io.Platform.pathSeparator;
      expect(io.File('${dirB.path}${sep}tema1.jpg').lengthSync(), 16);
      expect(
        io.File('${dirB.path}$sep${_nombreLetra('tema1')}').existsSync(),
        isTrue,
      );
      final filaB = (await dbB.downloadDao.getAllHistory()).single;
      expect(filaB.coverPath, '${dirB.path}${sep}tema1.jpg');
      expect(filaB.coverUrl, 'https://ejemplo/c.jpg');

      // Y ya no falta nada.
      expect(await aparatoB.faltantesDe(vinculado), isEmpty);
    });

    test('cancelar corta el traspaso y lo que llegó se queda', () async {
      expect(haySqlite, isTrue, reason: 'SQLite nativo no disponible');
      // Tres canciones allá, para que haya algo que cancelar a mitad.
      for (var i = 2; i <= 3; i++) {
        final archivo = io.File(
          '${dirA.path}${io.Platform.pathSeparator}tema$i.flac',
        );
        await archivo.writeAsBytes(List<int>.filled(32, i));
        await dbA.downloadDao.saveEntry(
          DownloadHistoryCompanion.insert(
            id: 'tema$i',
            trackName: 'Tema $i',
            artistName: 'Artista',
            downloadedAt: DateTime.now(),
            filePath: Value(archivo.path),
          ),
        );
      }

      final vecinoA = ParLan(
        id: 'dev_a',
        nombre: 'PC',
        host: '127.0.0.1',
        puerto: aparatoA.puerto,
      );
      final pidiendo = aparatoB.pedirVinculo(vecinoA);
      await _esperarSolicitud(aparatoA);
      await aparatoA.responderSolicitud(true);
      final vinculado = await pidiendo;
      expect(vinculado, isNotNull);

      // El usuario corta apenas llegó la primera: la copia se frena ahí.
      var cortado = false;
      void oyente() {
        final (hechas, total) = aparatoB.traspaso.value;
        if (!cortado && hechas >= 1 && total > 1) {
          cortado = true;
          aparatoB.cancelarTraspaso();
        }
      }

      aparatoB.traspaso.addListener(oyente);
      final (copiadas, cancelado) = await aparatoB.traerFaltantes(vinculado!);
      aparatoB.traspaso.removeListener(oyente);

      expect(cancelado, isTrue);
      expect(copiadas, 1);
      expect(await aparatoB.traerIndice(vinculado), hasLength(3));
      // Lo que no llegó sigue faltando: la próxima pasada lo trae.
      expect(await aparatoB.faltantesDe(vinculado), hasLength(2));
    });

    test('el que dijo que no no queda vinculado', () async {
      expect(haySqlite, isTrue, reason: 'SQLite nativo no disponible');
      final vecinoA = ParLan(
        id: 'dev_a',
        nombre: 'PC',
        host: '127.0.0.1',
        puerto: aparatoA.puerto,
      );
      final pidiendo = aparatoB.pedirVinculo(vecinoA);
      await _esperarSolicitud(aparatoA);
      await aparatoA.responderSolicitud(false);
      expect(await pidiendo, isNull);
      // Puede haberlo VISTO por la difusión (eso es descubrir), pero no quedó
      // vinculado: rechazar no deja entrar a nadie.
      expect(
        aparatoA.lista.any((p) => p.id == 'dev_b' && p.vinculado),
        isFalse,
      );
    });
  });
}

/// El nombre de la letra en el disco (`lyrics_<sha1>`, como las descargas).
String _nombreLetra(String id) =>
    'lyrics_${sha1.convert(utf8.encode(id)).toString()}.lrc';

/// Espera a que el aparato reciba el pedido de vínculo (la red local tarda
/// milisegundos, pero no es instantáneo).
Future<void> _esperarSolicitud(ServicioLan lan) async {
  for (var i = 0; i < 100; i++) {
    if (lan.solicitudVinculo.value != null) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('el aparato no recibió el pedido de vínculo');
}
