// ─────────────────────────────────────────────────────────────
// apariencia_vistas_ambito_test.dart — El corazón del diseño por vista: que una
// card que pide `AparienciaEspacios.radioCards(context)` obtenga LO QUE PIDIÓ LA
// VISTA, sin que la card sepa que existen las vistas.
//
// Por qué acá y no en un test de Ajustes: si esto se rompe, la UI de Ajustes
// sigue perfecta y las pantallas no cambian nada —el usuario elige y no pasa
// nada, el peor de los fracasos—. Es la costura entre el modelo y el pintado, y
// es lo que hay que cubrir.
//
// Se prueba con una sonda que sólo LEE los helpers, igual que una card real.
//
// La segunda mitad cubre el COLOR: la paleta del cofre que el usuario le puso a
// una vista. Ahí las reglas no son obvias (la paleta le gana al color de la
// carátula, tiene un piso para que no la apague el deslizador de Estilo y evita
// extraer el dominante del cover), así que se prueban una por una.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/sistema/cache_ajustes.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/diseno_vista.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/preferencias_vistas.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/vista_app.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/barras/apariencia_espacios_helper.dart';
import 'package:bitly/shared/utilidades/formato/comun/formato/estilo_helper.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/vistas/apariencia_vistas_helper.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/vistas/tinte_vista_helper.dart';
import 'package:bitly/shared/widgets/vista/base/ambito_vista.dart';
import 'package:bitly/shared/widgets/vista/base/diseno_de_vista.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lo que la sonda midió.
class _Medido {
  final double radio;
  final double espacioY;
  final double espacioXCancion;
  final VistaApp? vista;

  /// La paleta del cofre que la vista tiene puesta (vacía = ninguna).
  final List<Color> paleta;

  const _Medido(
    this.radio,
    this.espacioY,
    this.espacioXCancion,
    this.vista,
    this.paleta,
  );
}

void main() {
  late _Medido medido;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final db = AppDatabase(NativeDatabase.memory());
    di.sl.registerSingleton<AppDatabase>(db);
    di.sl.registerSingleton<CacheAjustes>(CacheAjustes(db));
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(
      ValueNotifier(PreferenciasApariencia.deFabrica),
    );
    di.sl.registerSingleton<ValueNotifier<PreferenciasVistas>>(
      ValueNotifier(PreferenciasVistas.deFabrica),
    );
    // La intensidad del color del cover: la que mide la grilla de cada pantalla.
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(
      ValueNotifier(const PreferenciasEstilo()),
    );
  });

  /// Estado del usuario antes de cada prueba: todo de fábrica.
  setUp(() {
    di.sl<ValueNotifier<PreferenciasApariencia>>().value =
        PreferenciasApariencia.deFabrica;
    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica;
  });

  /// El estilo global del usuario en este momento.
  PreferenciasApariencia global() =>
      di.sl<ValueNotifier<PreferenciasApariencia>>().value;

  /// Sonda: lee los helpers EXACTAMENTE como lo hace una card.
  Widget sonda() => Builder(
    builder: (context) {
      medido = _Medido(
        AparienciaEspacios.radioCards(context),
        AparienciaEspacios.espacioY(context),
        AparienciaEspacios.espacioXCancion(context),
        AmbitoVista.of(context)?.vista,
        AmbitoVista.paletaDe(context),
      );
      return const SizedBox();
    },
  );

  Future<void> montar(WidgetTester tester, {VistaApp? vista}) => tester.pumpWidget(
    MaterialApp(
      home: vista == null
          ? sonda()
          : DisenoDeVista(vista: vista, child: sonda()),
    ),
  );

  testWidgets('sin ninguna vista, manda el estilo global', (tester) async {
    await montar(tester);
    expect(medido.vista, isNull);
    expect(medido.radio, global().radioCards);
    expect(medido.espacioY, global().espacioY);
    expect(medido.espacioXCancion, global().cancionX);
  });

  testWidgets('la vista que se personalizó manda sobre el global', (
    tester,
  ) async {
    final prefs = PreferenciasVistas.deFabrica.conVista(
      VistaApp.busqueda,
      const DisenoVista(radioTarjeta: 4, densidad: 0.5),
    );
    di.sl<ValueNotifier<PreferenciasVistas>>().value = prefs;

    await montar(tester, vista: VistaApp.busqueda);

    expect(medido.vista, VistaApp.busqueda);
    expect(medido.radio, 4);
    // La densidad multiplica el valor global en vez de reemplazarlo: mover el
    // control general sigue moviendo todas las vistas juntas.
    expect(medido.espacioY, closeTo(global().espacioY * 0.5, 0.001));
    expect(medido.espacioXCancion, closeTo(global().cancionX * 0.5, 0.001));
  });

  testWidgets('personalizar una vista NO toca a las demás', (tester) async {
    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica.conVista(
          VistaApp.busqueda,
          const DisenoVista(radioTarjeta: 4, densidad: 0.5),
        );

    await montar(tester, vista: VistaApp.feed);

    expect(medido.vista, VistaApp.feed);
    expect(medido.radio, global().radioCards);
    expect(medido.espacioY, global().espacioY);
  });

  testWidgets('un eje suelto hereda y el otro no', (tester) async {
    // Sólo eligió redondeo: el aire tiene que seguir siendo el global.
    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica.conVista(
          VistaApp.feed,
          const DisenoVista(radioTarjeta: 2),
        );

    await montar(tester, vista: VistaApp.feed);

    expect(medido.radio, 2);
    expect(medido.espacioY, global().espacioY);
  });

  testWidgets('cambiar el diseño de la vista se ve al instante', (tester) async {
    await montar(tester, vista: VistaApp.feed);
    expect(medido.radio, global().radioCards);

    // Igual que en Ajustes: se guarda por el helper y la vista repinta.
    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica.conVista(
          VistaApp.feed,
          const DisenoVista(radioTarjeta: 20),
        );
    await tester.pump();

    expect(medido.radio, 20);
    expect(
      medido.espacioY,
      global().espacioY,
      reason: 'lo que no se toca no se mueve',
    );
  });

  testWidgets('las columnas de la vista llegan a la grilla', (tester) async {
    // Es el eje que consumen las grillas de feed, búsqueda y mi espacio: si la
    // cascada no lo pasara, el deslizador de Ajustes no haría nada.
    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica.conVista(
          VistaApp.feed,
          const DisenoVista(columnasMax: 3),
        );

    var tope = -1;
    await tester.pumpWidget(
      MaterialApp(
        home: DisenoDeVista(
          vista: VistaApp.feed,
          child: Builder(
            builder: (context) {
              tope = AmbitoVista.columnasDe(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(tope, 3);
  });

  /// Un contexto REAL adentro de [vista]: el mismo lugar desde el que una card
  /// consulta el tinte.
  Future<BuildContext> contextoDe(WidgetTester tester, VistaApp vista) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: DisenoDeVista(
          vista: vista,
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  /// Deja a [vista] con la paleta [id] del cofre puesta.
  void conPaleta(VistaApp vista, String id) =>
      di.sl<ValueNotifier<PreferenciasVistas>>().value = PreferenciasVistas
          .deFabrica
          .conVista(vista, DisenoVista(disenoId: id));

  testWidgets('la paleta del cofre que eligió la vista llega al ámbito', (
    tester,
  ) async {
    conPaleta(VistaApp.miEspacio, 'paleta_aurora');

    await montar(tester, vista: VistaApp.miEspacio);

    // Es lo que después leen las cards: si la cascada no lo pasara, elegir una
    // paleta en Ajustes no teñiría nada.
    expect(medido.paleta, isNotEmpty);
    expect(medido.paleta, paletaDeDiseno('paleta_aurora'));
  });

  testWidgets('una vista sin paleta no tiñe (y la de al lado tampoco)', (
    tester,
  ) async {
    conPaleta(VistaApp.miEspacio, 'paleta_aurora');

    await montar(tester, vista: VistaApp.feed);

    expect(medido.paleta, isEmpty, reason: 'Feed no eligió ninguna');
    // La otra SÍ tiene la suya: personalizar una vista no se filtra a las demás.
    expect(paletaDeDiseno('paleta_aurora'), isNotEmpty);
  });

  testWidgets('la paleta de la vista le gana al color de la carátula', (
    tester,
  ) async {
    conPaleta(VistaApp.feed, 'paleta_aurora');
    final ctx = await contextoDe(tester, VistaApp.feed);
    const delCover = Color(0xFF123456);

    // Elegir una paleta es una decisión explícita: si el cover pudiera pisarla,
    // elegirla no serviría de nada.
    expect(
      TinteVista.acentoDeCards(ctx, delCover),
      paletaDeDiseno('paleta_aurora').first,
    );
    // Y con paleta no se decodifica el dominante del cover.
    expect(TinteVista.extraerDelCover(ctx), isFalse);
  });

  testWidgets('la paleta se ve aunque el Estilo esté en cero', (tester) async {
    conPaleta(VistaApp.feed, 'paleta_aurora');
    final ctx = await contextoDe(tester, VistaApp.feed);

    // Con el deslizador de Estilo en 0, la card del tema no tiene color. Si la
    // paleta no tuviera piso, elegirla no se vería: un control que no hace nada.
    expect(TinteVista.nivelDeCards(ctx, 0), TinteVista.piso);
    // Por encima del piso el deslizador sigue mandando.
    expect(TinteVista.nivelDeCards(ctx, 0.9), 0.9);
  });

  testWidgets('la GRILLA mide la misma intensidad que sus cards', (
    tester,
  ) async {
    final ctx = await contextoDe(tester, VistaApp.feed);
    // Sin paleta mide el estilo global, tal cual (acá, en cero).
    expect(TinteVista.nivelDeGrilla(ctx), EstiloHelper.cardsGrilla(ctx));

    conPaleta(VistaApp.feed, 'paleta_aurora');
    final ctxPaleta = await contextoDe(tester, VistaApp.feed);

    // Con paleta, la grilla SÍ se cierra (el espaciado acompaña al color): si
    // midiera el global, las cards saldrían teñidas y la grilla con el aire de
    // "sin color" — dos piezas de la misma pantalla diciendo cosas distintas.
    expect(TinteVista.nivelDeGrilla(ctxPaleta), TinteVista.piso);
  });

  testWidgets('sin paleta, todo sigue como siempre', (tester) async {
    final ctx = await contextoDe(tester, VistaApp.feed);
    const delCover = Color(0xFF123456);

    expect(TinteVista.activo(ctx), isFalse);
    expect(TinteVista.acentoDeCards(ctx, delCover), delCover);
    expect(TinteVista.nivelDeCards(ctx, 0.3), 0.3, reason: 'sin piso');
    expect(TinteVista.extraerDelCover(ctx), isTrue);
  });

  testWidgets('un diseño que no trae paleta (una forma) no tiñe', (
    tester,
  ) async {
    conPaleta(VistaApp.feed, 'pastilla');
    final ctx = await contextoDe(tester, VistaApp.feed);
    const delCover = Color(0xFF123456);

    // El campo guarda el id del diseño entero, pero hoy lo único que se
    // consume es la paleta: una forma no puede cambiar el color de las cards.
    expect(paletaDeDiseno('pastilla'), isEmpty);
    expect(TinteVista.activo(ctx), isFalse);
    expect(TinteVista.acentoDeCards(ctx, delCover), delCover);
  });

  testWidgets('un id que ya no existe no pinta nada (ni rompe)', (
    tester,
  ) async {
    conPaleta(VistaApp.feed, 'paleta_que_ya_no_existe');
    final ctx = await contextoDe(tester, VistaApp.feed);

    expect(paletaDeDiseno('paleta_que_ya_no_existe'), isEmpty);
    expect(TinteVista.activo(ctx), isFalse);
    expect(TinteVista.acentoDeCards(ctx, null), isNull);
  });

  testWidgets('el ámbito se anida: gana el más cercano', (tester) async {
    // Una vista adentro de otra (el reproductor sobre Inicio): la de adentro es
    // la que manda, que es lo que el usuario está mirando.
    di.sl<ValueNotifier<PreferenciasVistas>>().value = PreferenciasVistas.deFabrica
        .conVista(VistaApp.feed, const DisenoVista(radioTarjeta: 3))
        .conVista(VistaApp.reproductor, const DisenoVista(radioTarjeta: 24));

    await tester.pumpWidget(
      MaterialApp(
        home: DisenoDeVista(
          vista: VistaApp.feed,
          child: DisenoDeVista(vista: VistaApp.reproductor, child: sonda()),
        ),
      ),
    );

    expect(medido.vista, VistaApp.reproductor);
    expect(medido.radio, 24);
  });
}
