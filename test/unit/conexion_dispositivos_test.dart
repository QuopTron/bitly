// Test de la burbuja Conexión: la prueba de 9 horas, la lista de aparatos
// (con su dueño) y las reglas de quién puede meter y sacar.
//
// Corre contra la base drift REAL en memoria: así se prueba también que lo
// guardado vuelve igual al recargar, que es lo que el usuario espera al
// cerrar y volver a abrir Ajustes. Si el entorno no expone SQLite nativo,
// se saltea (los modelos puros igual se prueban aparte).

import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/sistema/cache_ajustes.dart';
import 'package:bitly/core/modelos/usuario/dispositivos/dispositivo_conectado.dart';
import 'package:bitly/core/modelos/usuario/dispositivos/trial_conexion.dart';
import 'package:bitly/core/servicios/conexion/base/base/conexion_almacen.dart';
import 'package:bitly/core/servicios/conexion/base/base/servicio_conexion.dart';
import 'package:bitly/core/servicios/conexion/base/reglas/servicio_conexion_reglas.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  var haySqlite = true;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    try {
      db = AppDatabase(NativeDatabase.memory());
    } catch (_) {
      haySqlite = false;
    }
  });

  tearDownAll(() async {
    if (haySqlite) await db.close();
  });

  group('prueba de 9 horas', () {
    // Un "ahora" fijo: la prueba no depende del reloj real.
    const t0 = 1000000000000;

    test('no corre hasta que el usuario la arranca', () {
      const trial = TrialConexion();
      expect(trial.activo, isFalse);
      expect(trial.sirveEn(t0), isFalse);
      // Sin arrancar tiene las 9 horas enteras.
      expect(trial.msRestantesEn(t0), TrialConexion.totalMs);
    });

    test('corre desde la activación y no revive al agotarse', () {
      final trial = const TrialConexion().iniciar(t0);
      expect(trial.activo, isTrue);
      expect(trial.sirveEn(t0 + 60000), isTrue);
      expect(trial.msRestantesEn(t0 + 60000), TrialConexion.totalMs - 60000);

      expect(trial.sirveEn(t0 + TrialConexion.totalMs - 1), isTrue);
      expect(trial.sirveEn(t0 + TrialConexion.totalMs), isFalse);
      expect(trial.terminadaEn(t0 + TrialConexion.totalMs), isTrue);
      expect(trial.msRestantesEn(t0 + 999999999), 0);
      // Arrancarla de nuevo no la revive ni regala 9 horas.
      expect(trial.iniciar(t0 + 999999999).sirveEn(t0 + 999999999), isFalse);
    });

    test('el restante se separa en horas y minutos', () {
      final trial = TrialConexion(
        iniciadoMs: t0 - (20 * 60000), // 20 minutos usados
      );
      expect(trial.restanteEnHorasMinutos(t0), (8, 40));
    });
  });

  group('reparación de la lista guardada', () {
    test('lista vacía: el aparato propio entra mandando', () {
      final lista = conexionRepararPropio(
        const <DispositivoConectado>[],
        'dev_yo',
      );
      expect(lista, hasLength(1));
      expect(lista.first.id, 'dev_yo');
      expect(lista.first.esDueno, isTrue);
      expect(lista.first.vinculado, isTrue);
    });

    test('si ya hay dueño, el propio entra sin mando', () {
      final lista = conexionRepararPropio(const [
        DispositivoConectado(
          id: 'dev_otro',
          nombre: 'PC',
          tipo: TipoDispositivo.pc,
          esDueno: true,
          vinculado: true,
        ),
      ], 'dev_yo');
      expect(lista, hasLength(2));
      expect(lista.last.esDueno, isFalse);
    });

    test('si nadie manda, manda el propio', () {
      final lista = conexionRepararPropio(const [
        DispositivoConectado(
          id: 'dev_yo',
          nombre: 'Celu',
          tipo: TipoDispositivo.celu,
          vinculado: true,
        ),
      ], 'dev_yo');
      expect(lista.single.esDueno, isTrue);
    });
  });

  group('servicio de conexión', () {
    /// Un servicio limpio sobre una base nueva, con el plan que se pida.
    /// El segundo valor es si es premium, para poder cambiarlo en el test.
    Future<(ServicioConexion, bool Function())> armar({
      bool premium = false,
    }) async {
      final cache = CacheAjustes(db);
      var esPremium = premium;
      final servicio = ServicioConexion(
        cache,
        esPremium: () async => esPremium,
      );
      await servicio.cargar();
      return (servicio, () => esPremium);
    }

    test('la primera carga registra este aparato como dueño', () async {
      expect(haySqlite, isTrue, reason: 'SQLite nativo no disponible');
      final (servicio, _) = await armar();
      expect(servicio.dispositivos, hasLength(1));
      expect(servicio.esteDispositivo?.esDueno, isTrue);
      expect(servicio.dueno?.id, servicio.idPropio);
      expect(servicio.idPropio, isNotEmpty);
    });

    test('free tiene 1 lugar y no deja agregar', () async {
      final (servicio, _) = await armar();
      expect(servicio.cupo, cupoFree);
      expect(servicio.lugaresLibres, 0);
      expect(servicio.motivoParaAgregar(), MotivoConexion.cupoLleno);
      expect(servicio.puedeAgregar, isFalse);
    });

    test('la prueba habilita los 4 lugares y premium también', () async {
      final (servicio, _) = await armar();
      expect(servicio.trialSirve, isFalse);
      await servicio.iniciarTrial();
      expect(servicio.trialSirve, isTrue);
      expect(servicio.cupo, cupoPremium);
      expect(servicio.lugaresLibres, 3);
      expect(servicio.motivoParaAgregar(), isNull);

      final (premium, _) = await armar(premium: true);
      expect(premium.cupo, cupoPremium);
      expect(premium.esPremium, isTrue);
    });

    test('agregar, renombrar y sacar quedan guardados', () async {
      final (servicio, _) = await armar();
      await servicio.agregar(
        nombre: 'PC del cuarto',
        tipo: TipoDispositivo.pc,
        id: 'dev_pc',
      );
      expect(servicio.dispositivos, hasLength(2));

      // Un aparato declarado pero sin vincular se puede sacar sin más.
      final agregado = servicio.dispositivos.last;
      expect(agregado.vinculado, isFalse);
      expect(servicio.puedeQuitar(agregado), isTrue);

      await servicio.renombrar('dev_pc', 'PC grande');
      await servicio.cargar(); // recarga desde el disco
      expect(servicio.dispositivos, hasLength(2));
      expect(servicio.dispositivos.last.nombre, 'PC grande');

      await servicio.quitar('dev_pc');
      await servicio.cargar();
      expect(servicio.dispositivos, hasLength(1));
    });

    test(
      'no te podés sacar a vos mismo, y un aparato no conectado no sale',
      () async {
        final (servicio, _) = await armar();
        await servicio.agregar(
          nombre: 'TV',
          tipo: TipoDispositivo.tv,
          id: 'dev_tv',
        );
        // El propio nunca se puede sacar.
        final propio = servicio.dispositivos.first;
        expect(servicio.motivoParaQuitar(propio), MotivoConexion.esEste);

        // Vinculado pero visto hace mucho: hay que conectarlo para sacarlo.
        await servicio.marcarVisto('dev_tv', 1);
        final tv = servicio.dispositivos.last;
        expect(tv.vinculado, isTrue);
        expect(servicio.motivoParaQuitar(tv), MotivoConexion.noConectado);

        // Recién visto: ahí sí se puede.
        await servicio.marcarVisto(
          'dev_tv',
          DateTime.now().millisecondsSinceEpoch,
        );
        expect(servicio.puedeQuitar(servicio.dispositivos.last), isTrue);
      },
    );

    test('la prueba activada sobrevive a la recarga', () async {
      final (servicio, _) = await armar();
      await servicio.iniciarTrial();
      final arranque = servicio.trial.iniciadoMs;
      expect(arranque, greaterThan(0));

      await servicio.cargar();
      expect(servicio.trial.activo, isTrue);
      expect(servicio.trial.iniciadoMs, arranque);
      expect(servicio.cupo, cupoPremium);
    });
  });
}
