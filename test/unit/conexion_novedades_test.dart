// Test del mininumerito de la burbuja Conexión y su aviso: qué cuenta como
// novedad (el regalo de la prueba de 9 h y los aparatos sin vincular), que no
// cuente lo que ya no es novedad, y que se apague al abrir la pestaña.
//
// Corre contra la base drift real en memoria para comprobar que "visto"
// sobrevive a una recarga, que es lo que evita el mininumerito eterno. Si el
// entorno no expone SQLite nativo, se saltea.

import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/sistema/cache_ajustes.dart';
import 'package:bitly/core/modelos/usuario/dispositivos/dispositivo_conectado.dart';
import 'package:bitly/core/servicios/conexion/novedades/conexion_novedades.dart';
import 'package:bitly/core/servicios/conexion/base/base/servicio_conexion.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  var haySqlite = true;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // Una base NUEVA por test: "ya visto" se guarda en los ajustes, y con una
  // base compartida un test apagaría el aviso del siguiente.
  setUp(() {
    try {
      db = AppDatabase(NativeDatabase.memory());
    } catch (_) {
      haySqlite = false;
    }
  });

  tearDown(() async {
    if (haySqlite) await db.close();
  });

  /// Un servicio nuevo sobre [cache], con el plan que se pida.
  Future<ServicioConexion> armar(
    CacheAjustes cache, {
    bool premium = false,
  }) async {
    final servicio = ServicioConexion(cache, esPremium: () async => premium);
    await servicio.cargar();
    return servicio;
  }

  test(
    'free recién instalado tiene una novedad: el regalo de la prueba',
    () async {
      expect(haySqlite, isTrue, reason: 'SQLite nativo no disponible');
      final servicio = await armar(CacheAjustes(db));
      expect(servicio.novedades, hasLength(1));
      expect(servicio.novedades.single.tipo, TipoNovedadConexion.prueba);
      expect(servicio.novedadesNuevas, 1);
      // El número del mininumerito arranca en 0 hasta que se recalcula.
      expect(novedadesConexion.value, 0);
    },
  );

  test('premium no ve el regalo, y la prueba ya usada tampoco', () async {
    final premium = await armar(CacheAjustes(db), premium: true);
    expect(premium.novedades, isEmpty);

    final conPrueba = await armar(CacheAjustes(db));
    await conPrueba.iniciarTrial();
    expect(conPrueba.novedades, isEmpty);
  });

  test('un aparato sin vincular es novedad, y el propio no', () async {
    final servicio = await armar(CacheAjustes(db));
    await servicio.marcarNovedadesVistas(); // la prueba ya no cuenta
    expect(servicio.novedades, isEmpty);

    await servicio.agregar(
      nombre: 'TV del cuarto',
      tipo: TipoDispositivo.tv,
      id: 'dev_tv',
    );
    expect(servicio.novedades, hasLength(1));
    expect(
      servicio.novedades.single.tipo,
      TipoNovedadConexion.aparatoPendiente,
    );
    expect(servicio.novedades.single.aparato, 'TV del cuarto');

    // Al vincularse deja de ser novedad.
    await servicio.marcarVisto('dev_tv', DateTime.now().millisecondsSinceEpoch);
    expect(servicio.novedades, isEmpty);
  });

  test('marcar vistas apaga el aviso y sobrevive a la recarga', () async {
    final cache = CacheAjustes(db);
    final servicio = await armar(cache);
    expect(servicio.novedadesNuevas, 1);

    await servicio.marcarNovedadesVistas();
    expect(servicio.novedadesNuevas, 0);

    // Un servicio nuevo sobre la misma caché: "visto" quedó guardado.
    final otro = await armar(cache);
    expect(otro.novedadesNuevas, 0);
  });

  test('las novedades ya vistas no vuelven, pero las nuevas sí', () async {
    final cache = CacheAjustes(db);
    final servicio = await armar(cache);
    await servicio.marcarNovedadesVistas();

    await servicio.agregar(
      nombre: 'PC',
      tipo: TipoDispositivo.pc,
      id: 'dev_pc',
    );
    expect(servicio.novedadesNuevas, 1);

    await servicio.marcarNovedadesVistas();
    expect(servicio.novedadesNuevas, 0);

    // Y un segundo aparato declarado después vuelve a contar.
    await servicio.agregar(
      nombre: 'Extra',
      tipo: TipoDispositivo.extra,
      id: 'dev_extra',
    );
    expect(servicio.novedadesNuevas, 1);
  });
}
