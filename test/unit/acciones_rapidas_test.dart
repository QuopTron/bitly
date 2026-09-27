// acciones_rapidas_test.dart — Prueba el mapa gesto → acción de las
// tarjetas de canción contra la base real.
//
// Lo que se fija acá:
//  · de fábrica SOLO deslizar a la derecha encola (el resto apagado), así
//    la app se comporta igual que antes de que existiera la burbuja;
//  · lo guardado se relee tal cual, y lo que no está guardado cae en el
//    valor de fábrica de ESE gesto (una instalación vieja no se rompe);
//  · un valor desconocido en la base se lee como "nada" en vez de
//    reventar;
//  · cambiar un gesto no toca los otros cuatro.
//
// Si el entorno no expone SQLite nativo el test se saltea.

import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/sistema/cache_ajustes.dart';
import 'package:bitly/core/modelos/ajustes_acciones_rapidas.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  var disponible = true;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    try {
      db = AppDatabase(NativeDatabase.memory());
    } catch (_) {
      disponible = false;
      return;
    }
  });

  tearDownAll(() async {
    if (disponible) await db.close();
  });

  test('de fábrica solo el gesto de siempre está encendido', () {
    const d = AjustesAccionesRapidas.porDefecto;
    expect(d.derecha, AccionRapida.agregarCola);
    expect(d.izquierda, AccionRapida.ninguna);
    expect(d.arriba, AccionRapida.ninguna);
    expect(d.abajo, AccionRapida.ninguna);
    expect(d.dobleToque, AccionRapida.ninguna);
    expect(d.hayAlgo, isTrue);
    expect(d.hayHorizontal, isTrue);
    expect(d.hayVertical, isFalse);
  });

  // Va ANTES de cualquier guardado: es el caso de una instalación nueva, y la
  // base es la misma para todo el archivo.
  test('sin nada guardado se arranca en el valor de fábrica', () async {
    if (!disponible) return;
    final leido = await AjustesAccionesRapidas.leer(CacheAjustes(db));
    expect(leido, equals(AjustesAccionesRapidas.porDefecto));
  });

  test('guardar y releer devuelve exactamente lo elegido', () async {
    if (!disponible) return;
    final cache = CacheAjustes(db);
    final elegido = AjustesAccionesRapidas.porDefecto.copyWith(
      izquierda: AccionRapida.meGusta,
      arriba: AccionRapida.irAlbum,
      abajo: AccionRapida.quitarMiEspacio,
      dobleToque: AccionRapida.descargar,
    );

    await elegido.guardar(cache);

    expect(await AjustesAccionesRapidas.leer(cache), equals(elegido));
  });

  test('un valor desconocido en la base cae en "nada"', () async {
    if (!disponible) return;
    final cache = CacheAjustes(db);
    await cache.guardarAjuste(
      '${AjustesAccionesRapidas.id}_${AjustesAccionesRapidas.claveDerecha}',
      'bailar',
    );

    final leido = await AjustesAccionesRapidas.leer(cache);

    expect(leido.derecha, AccionRapida.ninguna);
  });

  test('cambiar un gesto no toca los otros', () {
    var a = AjustesAccionesRapidas.porDefecto;

    a = a.conGesto(AjustesAccionesRapidas.claveArriba, AccionRapida.info);

    expect(a.arriba, AccionRapida.info);
    expect(a.derecha, AccionRapida.agregarCola);
    expect(a.izquierda, AccionRapida.ninguna);
    expect(a.abajo, AccionRapida.ninguna);
    expect(a.dobleToque, AccionRapida.ninguna);
    expect(a.gesto(AjustesAccionesRapidas.claveArriba), AccionRapida.info);
  });

  test('con todos los gestos apagados la tarjeta no envuelve nada', () {
    final apagado = AjustesAccionesRapidas.porDefecto.copyWith(
      derecha: AccionRapida.ninguna,
    );
    expect(apagado.hayAlgo, isFalse);
    expect(apagado.hayHorizontal, isFalse);
  });

  test('el notifier arranca con los valores de fábrica', () {
    expect(accionesRapidas.value, equals(AjustesAccionesRapidas.porDefecto));
  });
}
