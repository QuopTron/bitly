// ─────────────────────────────────────────────────────────────
// ajustes_reinicio_test.dart — Lo elegido en Ajustes tiene que SOBREVIVIR el
// reinicio de la app.
//
// Por qué existe: guardar y leer son dos caminos distintos, y el error clásico
// es que falte uno de los dos —se elige, se ve en el momento, y al reabrir la app
// volvió todo al diseño de fábrica—. Eso no lo ve ningún test de modelo (el JSON
// está perfecto) ni el de la tarjeta (la elección se ve al instante): se ve
// recién al reabrir. Acá se simula el arranque REAL: valores de fábrica en los
// notificadores y después `cargarAjustesGuardadosApp`, que es lo que corre la
// app al abrir.
//
// Se cubre el diseño por VISTA —el más nuevo y el que más ejes tiene: color,
// letra, forma, aire y grilla— junto con la apariencia global, que es de donde
// hereda todo lo que la vista no toca.
//
// Parte del flujo: arranque (app.dart → cargarAjustesGuardadosApp).
// ─────────────────────────────────────────────────────────────

import 'package:bitly/app/base/helpers/app_helpers.dart';
import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/sistema/cache_ajustes.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/diseno_vista.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/preferencias_vistas.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/vista_app.dart';
import 'package:bitly/core/modelos/usuario/perfil/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/shared/utilidades/plataforma/pantalla/efectos_app.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/vistas/apariencia_vistas_helper.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CacheAjustes cache;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    di.sl.registerSingleton<AppDatabase>(db);
    cache = CacheAjustes(db);
    di.sl.registerSingleton<CacheAjustes>(cache);
    // Los seis notificadores que el arranque adopta (NotificadoresAjustesApp).
    di.sl.registerSingleton<ValueNotifier<Locale>>(ValueNotifier(const Locale('es')));
    di.sl.registerSingleton<ValueNotifier<ThemeMode>>(
      ValueNotifier(ThemeMode.dark),
    );
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(
      ValueNotifier(const PreferenciasEstilo()),
    );
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(
      ValueNotifier(PreferenciasApariencia.deFabrica),
    );
    di.sl.registerSingleton<ValueNotifier<PreferenciasVistas>>(
      ValueNotifier(PreferenciasVistas.deFabrica),
    );
    di.sl.registerSingleton<ValueNotifier<String?>>(ValueNotifier<String?>(null));
    // El perfil de rendimiento y el modo fluido se cargan por OTRO camino
    // (cargarPerfilRendimiento, ver inyeccion_perfil.dart), pero también en el
    // arranque: mismo riesgo de que se elija y se pierda.
    di.sl.registerSingleton<ValueNotifier<PerfilRendimiento>>(
      ValueNotifier(PerfilRendimiento.alto),
    );
  });

  tearDown(() {
    // Los interruptores son estáticos: sin esto, una prueba deja el modo
    // fluido prendido para la siguiente y todo pasa por el motivo equivocado.
    EfectosApp.reiniciar();
  });

  /// Deja la app como recién abierta: los notificadores en valores de fábrica.
  void recienAbierta() {
    di.sl<ValueNotifier<PreferenciasApariencia>>().value =
        PreferenciasApariencia.deFabrica;
    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica;
    di.sl<ValueNotifier<PreferenciasEstilo>>().value = const PreferenciasEstilo();
    di.sl<ValueNotifier<String?>>().value = null;
  }

  /// Corre el arranque real.
  Future<void> arrancar() => cargarAjustesGuardadosApp(
    ajustes: NotificadoresAjustesApp(),
    estaMontado: () => true,
  );

  test('una instalación nueva arranca con el diseño de fábrica', () async {
    recienAbierta();

    await arrancar();

    // Nada guardado = nada personalizado. Si esto fallara, el arranque estaría
    // inventando preferencias que el usuario nunca eligió.
    expect(AparienciaVistas.actual().esDeFabrica, isTrue);
    expect(di.sl<ValueNotifier<PreferenciasApariencia>>().value.esDeFabrica, isTrue);
  });

  test('el tema y el idioma sobreviven el reinicio', () async {
    // El usuario cambia a claro y a inglés (dos ajustes que se ven al instante
    // y que, si no se releen al abrir, vuelven al oscuro y al español).
    await cache.guardarTema('light');
    await cache.guardarIdioma('en');

    // La app se cierra y se vuelve a abrir.
    di.sl<ValueNotifier<ThemeMode>>().value = ThemeMode.dark;
    di.sl<ValueNotifier<Locale>>().value = const Locale('es');
    await arrancar();

    expect(di.sl<ValueNotifier<ThemeMode>>().value, ThemeMode.light);
    expect(di.sl<ValueNotifier<Locale>>().value, const Locale('en'));
  });

  test('el perfil de rendimiento y el modo fluido sobreviven el reinicio', () async {
    // Se elige en Ajustes → Rendimiento.
    await cache.guardarNivelRendimiento(NivelRendimiento.bajo);
    await cache.guardarModoFluido(true);

    // Se cierra y se vuelve a abrir: el arranque relee los dos.
    di.sl<ValueNotifier<PerfilRendimiento>>().value = PerfilRendimiento.alto;
    EfectosApp.reiniciar();
    await di.cargarPerfilRendimiento();

    expect(
      di.sl<ValueNotifier<PerfilRendimiento>>().value.nivel,
      NivelRendimiento.bajo,
      reason: 'la elección del perfil manda sobre la gama detectada',
    );
    expect(
      EfectosApp.modoFluido.value,
      isTrue,
      reason: 'el modo fluido es una elección explícita: no se revierte sola',
    );
  });

  test('lo elegido en la vista sobrevive el reinicio', () async {
    // 1) El usuario personaliza Inicio por los MISMOS caminos que usa Ajustes:
    //    la vista por su helper, y el estilo global por su notifier + caché.
    AparienciaVistas.poner(
      VistaApp.feed,
      const DisenoVista(
        disenoId: 'paleta_ambar',
        tipografiaId: 'inter',
        radioTarjeta: 18,
        densidad: 1.3,
        columnasMax: 5,
      ),
    );
    final globalGuardado = PreferenciasApariencia.deFabrica.copiarCon(
      radioCards: 22,
      fuenteId: 'rubik',
    );
    di.sl<ValueNotifier<PreferenciasApariencia>>().value = globalGuardado;
    await cache.guardarPreferenciasApariencia(globalGuardado);

    // 2) Se CIERRA y se vuelve a abrir: la app arranca de fábrica y rehidrata.
    recienAbierta();
    expect(AparienciaVistas.actual().esDeFabrica, isTrue, reason: 'acá empieza limpia');

    await arrancar();

    // 3) Y todo lo elegido está de vuelta, eje por eje.
    final deFeed = AparienciaVistas.declarado(VistaApp.feed);
    expect(deFeed.disenoId, 'paleta_ambar', reason: 'el color de la pantalla');
    expect(deFeed.tipografiaId, 'inter');
    expect(deFeed.radioTarjeta, 18);
    expect(deFeed.densidad, 1.3);
    expect(deFeed.columnasMax, 5);
    // La paleta se resuelve otra vez (es lo que tiñe las cards al arrancar).
    expect(paletaDeDiseno(deFeed.disenoId), isNotEmpty);
    // El estilo global también volvió: es de donde heredan las demás vistas.
    final global = di.sl<ValueNotifier<PreferenciasApariencia>>().value;
    expect(global.radioCards, 22);
    expect(global.fuenteId, 'rubik');
    // Y las otras pantallas siguen heredando (no se personalizaron de más).
    expect(AparienciaVistas.actual().para(VistaApp.busqueda).esHereda, isTrue);
  });
}
