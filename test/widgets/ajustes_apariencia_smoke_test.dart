// ─────────────────────────────────────────────────────────────
// ajustes_apariencia_smoke_test.dart — Monta la HOJA DE AJUSTES de verdad (por
// su puerta real, `showSettingsSheet`) y verifica las dos tarjetas nuevas de
// Apariencia: Tipografía y Diseño por vista.
//
// Por qué existe: las tarjetas son PART de `settings_sheet_new.dart`, así que su
// render no lo cubre ningún test unitario — todo lo demás (catálogo, cascada,
// servicio, ámbito) sí. Y es justo la parte que junta lo más frágil: la hoja pide
// DI por todos lados, y una pieza nueva que se olvide de un registro explota
// recién cuando el usuario abre Ajustes.
//
// La hoja se monta con lo mínimo que necesita, pero con lo que la app sí tiene
// (base en memoria + los servicios que consulta sola). Lo que NO existe es el
// backend, así que elegir una tipografía no descargada termina fallando: el
// código lo pide en try/catch a propósito y la prueba verifica esa salida
// —queda la empaquetada y se avisa— en vez de qué tan lindo se ve el happy
// path. Sin plugin de package_info, además, el catálogo tiene que quedar en su
// estado base —sólo lo libre— sin romper. Eso también se está verificando.
//
// Si el entorno no expone SQLite nativo el test se saltea (mismo criterio que
// diseno_deslizador_test.dart).
//
// Parte del flujo: Ajustes → Apariencia (Tipografía y Vistas).
// ─────────────────────────────────────────────────────────────

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/base_datos/daos/biblioteca/historial/play_history_dao.dart';
import 'package:bitly/core/cache/almacenes/sistema/cache_ajustes.dart';
import 'package:bitly/core/cache/almacenes/sistema/cache_premium.dart';
import 'package:bitly/core/cache/reproduccion/stats/reproduccion_stats.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/diseno_vista.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/preferencias_vistas.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/vista_app.dart';
import 'package:bitly/core/modelos/usuario/fuentes/catalogo_fuentes.dart';
import 'package:bitly/core/modelos/usuario/perfil/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/core/servicios/conexion/base/base/servicio_conexion.dart';
import 'package:bitly/core/servicios/fuentes/servicio_fuentes.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/vistas/apariencia_vistas_helper.dart';
import 'package:bitly/estado/cola/cubit_cola.dart';
import 'package:bitly/features/ajustes/sheet/settings_sheet_new.dart';
import 'package:bitly/features/tutorial_interactivo/motor/base/tutorial_claves.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var disponible = true;

  // El vocabulario de Barras y el del cofre, para no escribir los rótulos a
  // mano.
  const barrasEs = StringsAparienciaBarras.es;

  // El vocabulario del menu de Ajustes (el aviso de girar, el contador).
  const ajustesEs = StringsAjustes.es;

  /// La base, para sembrar horas de escucha: las paletas del cofre se abren
  /// con ellas, igual que las tipografías.
  late AppDatabase db;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    try {
      db = AppDatabase(NativeDatabase.memory());
      di.sl.registerSingleton<AppDatabase>(db);
      di.sl.registerSingleton<CacheAjustes>(CacheAjustes(db));
      // Lo que la hoja consulta sola al abrir (regalos del cofre y premium).
      // Se registran para que el test se parezca a la app real; si faltaran,
      // el código los pide en try/catch y la hoja igual montaría.
      di.sl.registerSingleton<ReproduccionStats>(ReproduccionStats(db));
      di.sl.registerSingleton<CachePremium>(CachePremium(db));
      // Datos de conexión (la burbuja de novedades del riel los consulta).
      final cache = di.sl<CacheAjustes>();
      di.sl.registerSingleton<ServicioConexion>(
        ServicioConexion(cache, esPremium: () async => false),
      );
    } catch (_) {
      // Sin SQLite nativo no se puede probar el guardado: el resto igual corre.
      disponible = false;
    }
    di.sl.registerSingleton<CubitCola>(CubitCola());
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(
      ValueNotifier(PreferenciasApariencia.deFabrica),
    );
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(
      ValueNotifier(const PreferenciasEstilo()),
    );
    di.sl.registerSingleton<ValueNotifier<PreferenciasVistas>>(
      ValueNotifier(PreferenciasVistas.deFabrica),
    );
    // La familia tipográfica activa: en la app la publica ServicioFuentes.
    di.sl.registerSingleton<ValueNotifier<String?>>(
      ValueNotifier<String?>(null),
    );
    di.sl.registerSingleton<ValueNotifier<PerfilRendimiento>>(
      ValueNotifier(PerfilRendimiento.alto),
    );
  });

  // Cada prueba arranca como un usuario recién instalado.
  setUp(() {
    di.sl<ValueNotifier<PreferenciasApariencia>>().value =
        PreferenciasApariencia.deFabrica;
    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica;
    di.sl<ValueNotifier<String?>>().value = null;
    // El estado del servicio es estático: sin esto, una bajada fallida de una
    // prueba anterior dejaría el aviso puesto en la siguiente.
    ServicioFuentes.estado.value = EstadoFuente.empaquetada;
  });

  /// App mínima que replica lo que necesita la hoja: localizaciones y tema.
  Widget app() => MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    locale: const Locale('es'),
    supportedLocales: const [Locale('es'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: Builder(
        builder:
            (context) => Center(
              child: ElevatedButton(
                onPressed:
                    () => showSettingsSheet(
                      context,
                      username: 'prueba',
                      isDark: true,
                      onThemeChanged: (_) {},
                      likedCount: '3',
                      downloadedCount: '7',
                    ),
                child: const Text('abrir ajustes'),
              ),
            ),
      ),
    ),
  );

  // Las tarjetas de Apariencia comparten textos ("Tipografía" es el título de
  // una y el rótulo de un eje de la otra), así que cada aserción apunta a la
  // tarjeta que le importa por su clave en vez de al texto suelto.
  Finder enTipografia(Finder f) => find.descendant(
    of: find.byKey(const ValueKey('ajustes-tipografia')),
    matching: f,
  );

  Finder enVistas(Finder f) => find.descendant(
    of: find.byKey(const ValueKey('ajustes-vistas')),
    matching: f,
  );

  Finder enBarras(Finder f) => find.descendant(
    of: find.byKey(const ValueKey('ajustes-barras')),
    matching: f,
  );

  /// Deja terminar las consultas REALES de la hoja y repinta.
  ///
  /// Las horas de escucha -que son las que abren tipografías y paletas- salen
  /// de una consulta a la base, y `pumpAndSettle` no la espera: vive en la zona
  /// de tiempo falso y el reloj real no avanza. Sin este turno la tarjeta se
  /// queda en 0 horas y sus catálogos parecen vacíos por el motivo equivocado
  /// (o peor: la prueba pasa sin haber probado nada).
  Future<void> asentarDatos(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  /// Abre la PESTAÑA de eje [rotulo] de la tarjeta de Vistas.
  ///
  /// Cada eje tiene la suya: sólo se ve un control a la vez, así que las
  /// pruebas tienen que entrar a la pestaña como lo hace el usuario.
  Future<void> abrirEje(WidgetTester tester, String rotulo) async {
    final chip = enVistas(find.text(rotulo));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();
  }

  // Las tarjetas de Apariencia viven en un CARRUSEL, así que una prueba sólo
  // encuentra la que está mirando. Estos son los índices, en el orden en que la
  // pestaña las pasa.
  const paginaBarras = 2;
  const paginaTipografia = 3;
  const paginaVistas = 4;

  /// Cuántos ajustes tiene el carrusel de Apariencia (tema, estilo, barras,
  /// tipografía, vistas, diseño, acciones rápidas e idioma).
  const paginasApariencia = 8;

  /// Las DEMÁS pestañas que también giran: su índice en el riel (el orden de
  /// `StringsAjustes.pestanas`), la clave de su carrusel y cuántos ajustes
  /// tiene. Es la misma lista que la de las burbujas, así que si alguien agrega
  /// una pestaña o le saca el carrusel, esto queda desalineado y hay que
  /// actualizarlo a mano — a propósito: es el recordatorio de que hay que
  /// cubrirla.
  const otrosCarruseles = <(int, String, int)>[
    (1, 'carrusel-descargas', 4),
    (2, 'carrusel-rendimiento', 3),
    (3, 'carrusel-estadisticas', 2),
    (4, 'carrusel-cuenta', 2),
    (5, 'carrusel-proveedores', 2),
    (6, 'carrusel-conexion', 3),
    (7, 'carrusel-mas', 3),
  ];

  /// Abre la pestaña [indice] tocando su burbuja/riel, que es como la abre el
  /// usuario. Se busca DENTRO de la navegación para no agarrar un texto
  /// homónimo de adentro de la pestaña ("Estadísticas" es rótulo de burbuja y
  /// también título de la tarjeta).
  Future<void> abrirPestana(WidgetTester tester, int indice) async {
    final rotulo = ajustesEs.pestanas[indice];
    final burbuja = find.descendant(
      of: find.byKey(keyTutorialAjustesTabs),
      matching: find.text(rotulo),
    );
    expect(burbuja, findsOneWidget, reason: 'no hay burbuja "$rotulo"');
    await tester.ensureVisible(burbuja);
    await tester.pumpAndSettle();
    await tester.tap(burbuja);
    await tester.pumpAndSettle();
    await asentarDatos(tester);
  }

  Finder enCarruselDe(String clave, Finder f) => find.descendant(
    of: find.byKey(ValueKey(clave)),
    matching: f,
  );

  /// En qué página está el carrusel [clave], leído del CONTADOR: es lo que ve el
  /// usuario, así que la prueba no puede estar más de acuerdo que él.
  int paginaActualDe(WidgetTester tester, String clave, int total) {
    for (var p = 1; p <= total; p++) {
      if (enCarruselDe(clave, find.text(ajustesEs.deTotal(p, total)))
          .evaluate()
          .isNotEmpty) {
        return p - 1;
      }
    }
    fail('el carrusel $clave no dice en qué página está');
  }

  /// Gira el carrusel [clave] hasta la página [pagina], venga de donde venga.
  ///
  /// Se usan las FLECHAS y no un gesto: es lo que hace el usuario en la PC y en
  /// la tele (donde no hay "deslizar"), así que la prueba pasa por el mismo
  /// camino que ellos. Y como se gira en los dos sentidos, quedan cubiertas las
  /// dos flechas, no sólo la de avanzar.
  Future<void> giraHasta(
    WidgetTester tester,
    String clave,
    int total,
    int pagina,
  ) async {
    var actual = paginaActualDe(tester, clave, total);
    while (actual != pagina) {
      // Por CLAVE y no por ícono: las tarjetas de adentro usan la misma flecha
      // (chevron), así que buscar por ícono agarraba dos y el tap era ambiguo.
      await tester.tap(
        enCarruselDe(
          clave,
          find.byKey(
            ValueKey(
              actual < pagina ? 'carrusel-siguiente' : 'carrusel-anterior',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final siguiente = paginaActualDe(tester, clave, total);
      // Si la flecha no movió nada, se corta acá: si no, esto sería un bucle
      // infinito y el fallo aparecería como un timeout sin explicación.
      expect(
        siguiente,
        isNot(actual),
        reason: 'la flecha no giró desde la página ${actual + 1}',
      );
      actual = siguiente;
    }
    // Al llegar a una página recién ahí se construye esa tarjeta, así que su
    // consulta a la base (las horas de escucha) empieza EN ESTE momento: sin
    // este turno de reloj real la tarjeta se queda en 0 h y las pruebas de lo
    // que se abre escuchando pasarían por el motivo equivocado.
    await asentarDatos(tester);
  }

  /// Gira el carrusel de Apariencia hasta la página [i].
  Future<void> giraA(WidgetTester tester, int i) =>
      giraHasta(tester, 'carrusel-apariencia', paginasApariencia, i);


  /// Abre la hoja y espera a que se asiente (incluida la carga async del
  /// progreso de la tarjeta).
  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(app());
    // Las localizaciones se resuelven en un microtask: sin este asentamiento
    // el primer frame todavía no tiene árbol y no hay botón que tocar.
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir ajustes'));
    await tester.pumpAndSettle();
    await asentarDatos(tester);
  }

  testWidgets('la hoja monta sin excepciones y abre en Apariencia', (
    tester,
  ) async {
    await abrir(tester);

    expect(tester.takeException(), isNull);
    // Apariencia es la primera pestaña (se toca un ajuste, no se mira un
    // tablero), y adentro abre en su primer ajuste: el tema.
    final carrusel = find.byKey(const ValueKey('carrusel-apariencia'));
    expect(carrusel, findsOneWidget);
    expect(
      find.descendant(of: carrusel, matching: find.text(ajustesEs.deTotal(1, 8))),
      findsOneWidget,
    );

    // Y el carrusel avisa que se puede girar: sin ese cartel el usuario se
    // queda con el ajuste que ve y pierde los otros siete.
    expect(
      find.descendant(
        of: carrusel,
        matching: find.text(ajustesEs.girar),
      ),
      findsOneWidget,
    );

    // Girando se llega a la tipografía, que es un ajuste más del carrusel.
    await giraA(tester, paginaTipografia);
    const t = fuentesEs;
    expect(enTipografia(find.text(t.titulo)), findsOneWidget, reason: t.titulo);
    expect(enTipografia(find.text(t.previaTitulo.toUpperCase())), findsOneWidget);
    expect(enTipografia(find.text(t.previaTexto)), findsOneWidget);
    expect(enTipografia(find.text('Aa')), findsWidgets, reason: 'la muestra');
  });

  testWidgets('el catálogo sale completo y con la de la app marcada', (
    tester,
  ) async {
    await abrir(tester);
    await giraA(tester, paginaTipografia);

    // Todas las tipografías del catálogo tienen su fila.
    for (final fuente in catalogoFuentes) {
      expect(
        enTipografia(find.text(fuentesEs.nombre(fuente.id))),
        findsOneWidget,
        reason: fuente.id,
      );
    }
    // La que trae la app es la que está en uso (no hay ninguna elegida)…
    expect(enTipografia(find.text(fuentesEs.enUso)), findsOneWidget);
    // …y las que se abren con horas lo dicen, con su candado.
    expect(enTipografia(find.text(fuentesEs.horas(5))), findsOneWidget);
    expect(enTipografia(find.byIcon(Icons.lock_outline_rounded)), findsWidgets);
  });

  testWidgets('los controles viejos de la pestaña siguen montados', (
    tester,
  ) async {
    // La tarjeta nueva se metió en medio de la pestaña: si algo de lo que ya
    // estaba se rompe, tiene que verse acá y no en la app.
    await abrir(tester);
    await giraA(tester, paginaTipografia);

    expect(tester.takeException(), isNull);
    expect(enTipografia(find.text(fuentesEs.liberar)), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('tocar una tipografía la deja en uso y la guarda', (
    tester,
  ) async {
    if (!disponible) return;
    await abrir(tester);
    await giraA(tester, paginaTipografia);

    // Inter es libre: se puede elegir sin horas de escucha.
    final fila = enTipografia(find.text(fuentesEs.nombre('inter')));
    await tester.ensureVisible(fila);
    await tester.pumpAndSettle();
    await tester.tap(fila);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // La elección quedó en las preferencias…
    expect(
      di.sl<ValueNotifier<PreferenciasApariencia>>().value.fuenteId,
      'inter',
    );
    // …la fila pasó a "En uso"…
    expect(enTipografia(find.text(fuentesEs.enUso)), findsOneWidget);
    // …y como acá no hay backend, la bajada falla y lo dice, en vez de dejar
    // la app sin tipografía en silencio.
    expect(enTipografia(find.text(fuentesEs.sinRed)), findsOneWidget);
    expect(enTipografia(find.text(fuentesEs.reintentar)), findsOneWidget);

    // Y sobrevive el viaje a disco.
    final guardado = await di.sl<CacheAjustes>().getPreferenciasApariencia();
    expect(guardado.fuenteId, 'inter');
  });

  testWidgets('la tarjeta de Vistas monta con las pantallas y sus ejes', (
    tester,
  ) async {
    await abrir(tester);
    await giraA(tester, paginaVistas);

    expect(tester.takeException(), isNull);
    const t = vistasEs;
    expect(enVistas(find.text(t.titulo)), findsOneWidget);
    // Todas las pantallas se pueden elegir…
    for (final v in VistaApp.values) {
      expect(enVistas(find.text(t.nombre(v.clave))), findsOneWidget, reason: v.clave);
    }
    // Las cinco PESTAÑAS de eje están siempre a la vista: es lo que separa
    // color, letra, forma, aire y grilla en vez de un rollo de controles.
    for (final rotulo in [
      t.ejeColor,
      t.ejeLetra,
      t.ejeForma,
      t.ejeAire,
      t.ejeGrilla,
    ]) {
      expect(enVistas(find.text(rotulo)), findsOneWidget, reason: rotulo);
    }

    // Abre en COLOR, el eje que se aplica ya (y sin haber bajado nada)…
    expect(enVistas(find.text(t.cofre)), findsOneWidget);
    // …con la muestra de cada paleta —su nombre— y la opción del cover.
    expect(enVistas(find.text(t.cofreCover)), findsOneWidget);
    expect(enVistas(find.text(t.cofreAyuda)), findsOneWidget);
    expect(enVistas(find.text(cofreEs.nombre('paleta_ambar'))), findsOneWidget);
    // Lo que todavía no se abrió se VE, con candado y con cómo se abre.
    expect(enVistas(find.byIcon(Icons.lock_outline_rounded)), findsWidgets);
    expect(enVistas(find.text(cofreEs.horas(2))), findsOneWidget);
    // Un eje por vez: en la pestaña de color no hay ningún deslizador.
    expect(enVistas(find.byType(Slider)), findsNothing);

    // LETRA: sólo las tipografías desbloqueadas, en su propia pestaña.
    await abrirEje(tester, t.ejeLetra);
    expect(enVistas(find.text(t.tipografia)), findsOneWidget);
    expect(enVistas(find.text(fuentesEs.nombre('google_sans'))), findsOneWidget);
    expect(enVistas(find.text(t.heredado)), findsOneWidget);
    expect(
      enVistas(find.text(cofreEs.nombre('paleta_ambar'))),
      findsNothing,
      reason: 'el eje de color ya no está a la vista',
    );

    // FORMA y AIRE: un deslizador cada uno, en su pestaña.
    await abrirEje(tester, t.ejeForma);
    expect(enVistas(find.text(t.radio)), findsOneWidget);
    expect(enVistas(find.byType(Slider)), findsOneWidget);

    await abrirEje(tester, t.ejeAire);
    expect(enVistas(find.text(t.densidad)), findsOneWidget);
    expect(enVistas(find.byType(Slider)), findsOneWidget);

    // GRILLA: el tope de columnas. No hereda del global —las decide el ancho—,
    // así que su marca dice "Automático" (dos veces: la marca y el valor).
    await abrirEje(tester, t.ejeGrilla);
    expect(enVistas(find.text(t.columnas)), findsOneWidget);
    expect(enVistas(find.text(t.automatico)), findsNWidgets(2));
    expect(enVistas(find.text(t.heredado)), findsNothing);
  });

  testWidgets('el aire se guarda en la pantalla elegida y no en las demás', (
    tester,
  ) async {
    if (!disponible) return;
    await abrir(tester);
    await giraA(tester, paginaVistas);

    // Se entra a la pestaña de AIRE: es la única que tiene deslizador ahí.
    await abrirEje(tester, vistasEs.ejeAire);
    final aire = enVistas(find.byType(Slider));
    await tester.ensureVisible(aire);
    await tester.pumpAndSettle();
    await tester.drag(aire, const Offset(60, 0));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final propio = AparienciaVistas.actual().para(VistaApp.feed);
    expect(propio.densidad, isNotNull);
    expect(propio.densidad! > 1.0, isTrue, reason: 'se arrastró hacia más aire');
    // El redondeo quedó heredado: sólo se tocó el aire.
    expect(propio.radioTarjeta, isNull);

    // Se cambia de pantalla: la otra sigue limpia. La tira queda arriba de
    // todo, así que hay que volver a subir hasta ella (el deslizador de abajo
    // scrolleó la pestaña).
    final chip = enVistas(find.text(vistasEs.nombre('reproductor')));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(
      AparienciaVistas.actual().para(VistaApp.reproductor).esHereda,
      isTrue,
    );
    // Y la tarjeta vuelve a mostrar el AIRE de la otra —heredado—. Sin esto el
    // toque podría haber fallado y la prueba pasaría igual, porque la vista
    // limpia lo está por definición.
    expect(enVistas(find.text(vistasEs.heredado)), findsOneWidget);
    expect(enVistas(find.text(vistasEs.propio)), findsNothing);

    // Y sobrevive el viaje a disco.
    final guardado = await di.sl<CacheAjustes>().getPreferenciasVistas();
    expect(guardado.para(VistaApp.feed).densidad, propio.densidad);
    expect(guardado.cantidadPersonalizadas, 1);
  });

  testWidgets('una pantalla sólo ofrece lo que el usuario ya desbloqueó', (
    tester,
  ) async {
    await abrir(tester);
    await giraA(tester, paginaVistas);

    // Con 0 horas, la única tipografía abierta es la que trae la app. Se mira
    // en la pestaña de LETRA de la pantalla, que es donde vive ese eje.
    await abrirEje(tester, vistasEs.ejeLetra);
    expect(enVistas(find.text(fuentesEs.nombre('google_sans'))), findsOneWidget);
    expect(enVistas(find.text(fuentesEs.nombre('manrope'))), findsNothing);
    // Y siempre se puede volver a heredar: el chip está en la lista de letras.
    expect(enVistas(find.text(vistasEs.heredar)), findsWidgets);
    // …y la misma está bloqueada en el catálogo de al lado: la regla es una.
    // (Se vuelve girando para ATRÁS: la tarjeta de tipografía es la anterior.)
    await giraA(tester, paginaTipografia);
    expect(enTipografia(find.text(fuentesEs.horas(5))), findsOneWidget);
    expect(enVistas(find.text(fuentesEs.horas(5))), findsNothing);
    // Y al volver a la pantalla, sus ejes siguen ahí.
    await giraA(tester, paginaVistas);
    expect(enVistas(find.text(vistasEs.ejeColor)), findsOneWidget);
  });

  testWidgets('una paleta de fábrica se aplica sin horas y tiñe esa pantalla', (
    tester,
  ) async {
    if (!disponible) return;
    await abrir(tester);
    await giraA(tester, paginaVistas);

    // Ámbar viene ABIERTA: se aplica sin haber escuchado nada. Si todo el
    // catálogo arrancara con candado, el usuario elegiría y no pasaría nada.
    final chip = enVistas(find.text(cofreEs.nombre('paleta_ambar')));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      AparienciaVistas.actual().para(VistaApp.feed).disenoId,
      'paleta_ambar',
    );
    // Y sólo en ella.
    expect(AparienciaVistas.actual().para(VistaApp.busqueda).esHereda, isTrue);
    // El eje pasa a marcar "Propio": el usuario ya ve que cambió algo.
    expect(enVistas(find.text(vistasEs.propio)), findsOneWidget);
    // Su paleta se resuelve de verdad (es lo que después tiñe las cards).
    expect(
      paletaDeDiseno(AparienciaVistas.actual().para(VistaApp.feed).disenoId),
      paletaDeDiseno('paleta_ambar'),
    );
    // Lo bloqueado se sigue viendo, con cómo se abre.
    expect(enVistas(find.text(cofreEs.horas(2))), findsOneWidget);
    // Y la previa muestra la LETRA de la vista junto al color: la previa fiel.
    // Dos veces: la previa dibuja DOS filas, como una lista de verdad.
    expect(
      enVistas(find.text(fuentesEs.previaTexto)),
      findsNWidgets(2),
      reason: 'la previa escribe el texto de muestra',
    );

    // Y sobrevive el viaje a disco.
    final guardado = await di.sl<CacheAjustes>().getPreferenciasVistas();
    expect(guardado.para(VistaApp.feed).disenoId, 'paleta_ambar');
  });

  testWidgets('las horas abren tipografías y paletas en la hoja real', (
    tester,
  ) async {
    if (!disponible) return;
    // 6 h escuchadas: abre Manrope (5 h) y Aurora (2 h).
    final historial = PlayHistoryDao(db);
    await historial.logPlay(
      PlayHistoryCompanion.insert(
        trackName: 'prueba',
        artistName: 'prueba',
        playedAt: DateTime.now(),
        durationMs: const Value(6 * 3600000),
      ),
    );
    addTearDown(historial.clear);
    await abrir(tester);
    await giraA(tester, paginaVistas);

    // El eje de LETRA lee las horas de la BASE: si no las leyera, Manrope no se
    // ofrecería aunque el usuario ya la tenga abierta por escuchar.
    await abrirEje(tester, vistasEs.ejeLetra);
    expect(
      enVistas(find.text(fuentesEs.nombre('manrope'))),
      findsOneWidget,
      reason: 'con 6 h ya se abrió (pide 5)',
    );

    // Y el de COLOR: Aurora (2 h) tampoco tiene candado.
    await abrirEje(tester, vistasEs.ejeColor);
    expect(enVistas(find.text(cofreEs.horas(2))), findsNothing);

    final chip = enVistas(find.text(cofreEs.nombre('paleta_aurora')));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // La paleta quedó en ESTA pantalla…
    expect(
      AparienciaVistas.actual().para(VistaApp.feed).disenoId,
      'paleta_aurora',
    );
    // …y sólo en ella.
    expect(AparienciaVistas.actual().para(VistaApp.busqueda).esHereda, isTrue);
    // El eje pasa a marcar "Propio": el usuario ya ve que cambió algo.
    expect(enVistas(find.text(vistasEs.propio)), findsOneWidget);
    // Y su paleta se resuelve de verdad (es lo que después tiñe las cards):
    // sin esto el id se guardaría y las tarjetas seguirían igual.
    expect(paletaDeDiseno('paleta_aurora'), isNotEmpty);
    expect(
      paletaDeDiseno(AparienciaVistas.actual().para(VistaApp.feed).disenoId),
      paletaDeDiseno('paleta_aurora'),
    );

    // Y sobrevive el viaje a disco.
    final guardado = await di.sl<CacheAjustes>().getPreferenciasVistas();
    expect(guardado.para(VistaApp.feed).disenoId, 'paleta_aurora');
  });

  testWidgets('el miniplayer tiene su tamaño y su forma, pero el navbar no', (
    tester,
  ) async {
    if (!disponible) return;
    await abrir(tester);
    await giraA(tester, paginaBarras);

    // De entrada se edita el NAVBAR: ahí no hay carátula que agrandar ni barra
    // que despegar, así que los presets no se ofrecen.
    expect(enBarras(find.text(barrasEs.tamano)), findsNothing);

    // Se pasa a editar el miniplayer.
    final selector = enBarras(find.text(barrasEs.miniplayer));
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(enBarras(find.text(barrasEs.tamano)), findsOneWidget);
    expect(enBarras(find.text(barrasEs.forma)), findsOneWidget);
    // Los tres tamaños, con "Normal" puesto (el de siempre).
    for (final t in [barrasEs.compacto, barrasEs.normal, barrasEs.grande]) {
      expect(enBarras(find.text(t)), findsOneWidget, reason: t);
    }
    expect(enBarras(find.text(barrasEs.formaPegado)), findsOneWidget);
    expect(enBarras(find.text(barrasEs.formaFlotante)), findsOneWidget);
    // Y el ancho máximo, con sus tres opciones.
    expect(enBarras(find.text(barrasEs.ancho)), findsOneWidget);
    expect(enBarras(find.text(barrasEs.anchoContenido)), findsOneWidget);
    expect(enBarras(find.text(barrasEs.anchoCompleto)), findsOneWidget);
    // Los DOS ejes con "auto" (forma y ancho) dicen a qué equivale: si no, el
    // usuario la elige, no ve cambios en su pantalla y parece que el control
    // está roto. (Los dos rótulos son la misma palabra, por eso son dos.)
    expect(enBarras(find.textContaining(barrasEs.anchoAuto)), findsNWidgets(2));
    // El de la forma aclara que en ESTE aparato resuelve a pegado.
    expect(
      enBarras(find.textContaining(barrasEs.formaPegado)),
      findsNWidgets(2),
      reason: 'el chip de auto + el de pegado al borde',
    );

    // Se elige "Grande" y viaja a disco.
    await tester.tap(enBarras(find.text(barrasEs.grande)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      di.sl<ValueNotifier<PreferenciasApariencia>>().value.tamanoMiniplayer,
      TamanoMiniplayer.grande,
    );
    final guardado = await di.sl<CacheAjustes>().getPreferenciasApariencia();
    expect(guardado.tamanoMiniplayer, TamanoMiniplayer.grande);
    // Y el navbar sigue intacto.
    expect(guardado.radioNavbar, PreferenciasApariencia.deFabrica.radioNavbar);
  });

  testWidgets('el ancho del miniplayer se elige y se guarda', (tester) async {
    if (!disponible) return;
    await abrir(tester);
    await giraA(tester, paginaBarras);

    final selector = enBarras(find.text(barrasEs.miniplayer));
    await tester.ensureVisible(selector);
    await tester.pumpAndSettle();
    await tester.tap(selector);
    await tester.pumpAndSettle();

    final chip = enBarras(find.text(barrasEs.anchoContenido));
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      di.sl<ValueNotifier<PreferenciasApariencia>>().value.anchoMiniplayer,
      AnchoMiniplayer.contenido,
    );
    final guardado = await di.sl<CacheAjustes>().getPreferenciasApariencia();
    expect(guardado.anchoMiniplayer, AnchoMiniplayer.contenido);
  });

  testWidgets('restablecer una vista la devuelve al diseño general', (
    tester,
  ) async {
    if (!disponible) return;
    AparienciaVistas.notifier().value = PreferenciasVistas.deFabrica.conVista(
      VistaApp.feed,
      const DisenoVista(radioTarjeta: 2, densidad: 1.4),
    );
    await abrir(tester);
    await giraA(tester, paginaVistas);

    final boton = enVistas(find.text(vistasEs.restablecer));
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(AparienciaVistas.actual().para(VistaApp.feed).esHereda, isTrue);
    expect(di.sl<ValueNotifier<PreferenciasVistas>>().value.esDeFabrica, isTrue);
    // Y se confirma en el lugar, sin abrir un aviso encima de la hoja.
    expect(enVistas(find.text(vistasEs.restablecida)), findsOneWidget);

    final guardado = await di.sl<CacheAjustes>().getPreferenciasVistas();
    expect(guardado.esDeFabrica, isTrue);
  });

  // Las pestañas que NO son Apariencia también giran sus ajustes. Se prueban
  // una por una y no con un bucle adentro de un test: cada una es un `part`
  // distinto del sheet y una que se olvide de pasar por el carrusel deja al
  // usuario con un solo ajuste a la vista, sin enterarse de que hay más. Un
  // test por pestaña hace que el fallo diga CUÁL.
  for (final (indice, clave, paginas) in otrosCarruseles) {
    testWidgets('la pestaña ${ajustesEs.pestanas[indice]} gira sus $paginas ajustes', (
      tester,
    ) async {
      if (!disponible) return;
      await abrir(tester);
      await abrirPestana(tester, indice);

      expect(tester.takeException(), isNull);
      expect(find.byKey(ValueKey(clave)), findsOneWidget, reason: clave);
      // Abre en el primero y el contador lo dice: es lo único que le avisa al
      // usuario que faltan más ajustes.
      expect(
        enCarruselDe(clave, find.text(ajustesEs.deTotal(1, paginas))),
        findsOneWidget,
      );
      // …y el cartel de girar sigue estando (sin él, el carrusel existe pero
      // nadie sabe que se puede girar).
      expect(enCarruselDe(clave, find.text(ajustesEs.girar)), findsOneWidget);

      // Se llega hasta la última con las flechas: si el carrusel perdiera una
      // página, el recorrido se corta acá.
      await giraHasta(tester, clave, paginas, paginas - 1);
      expect(
        enCarruselDe(clave, find.text(ajustesEs.deTotal(paginas, paginas))),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
