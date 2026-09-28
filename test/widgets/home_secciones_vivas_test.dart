// ─────────────────────────────────────────────────────────────
// home_secciones_vivas_test.dart — Cambiar de sección en la Home del celular y
// volver NO puede reiniciar lo que el usuario tenía ahí.
//
// Por qué existe: el shell móvil usa un PageView, y un PageView DESCARTA la
// sección que sale de pantalla (a diferencia del IndexedStack de la PC y la TV,
// que las deja montadas). El síntoma real: buscabas algo en Mi Espacio, ibas a
// Buscar y al volver la búsqueda estaba en blanco. Acá se mide con un contador
// de NACIMIENTOS de estado: si una sección se reconstruye, nace otra vez.
//
// La prueba monta el shell de verdad (navbar incluida) con tres secciones
// falsas, así que también corre el camino real de los toques: tocar la burbuja
// de Mi Espacio, volver, etc.
//
// Parte del flujo: Home (variante móvil) → navegación entre secciones.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/disenos/vistas/preferencias_vistas.dart';
import 'package:bitly/core/modelos/usuario/perfil/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/estado/cola/cubit_cola.dart';
import 'package:bitly/features/home/movil/base/home_movil.dart';
import 'package:bitly/features/home/shell/ensamblador_home.dart';
import 'package:bitly/features/tutorial_interactivo/motor/base/tutorial_controller.dart';
import 'package:bitly/features/tutorial_interactivo/motor/base/tutorial_provider.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cuántas veces nació el estado de una sección falsa. Si el PageView descarta
/// una sección y la reconstruye al volver, este número sube.
int nacimientos = 0;

/// Sección de mentira: tiene estado propio (un contador de toques) para poder
/// comprobar que lo escrito/lo hecho ahí sigue estando al volver.
class _SeccionFalsa extends StatefulWidget {
  final String etiqueta;

  const _SeccionFalsa(this.etiqueta);

  @override
  State<_SeccionFalsa> createState() => _SeccionFalsaState();
}

class _SeccionFalsaState extends State<_SeccionFalsa> {
  int toques = 0;

  @override
  void initState() {
    super.initState();
    nacimientos++;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('tocar-${widget.etiqueta}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => toques++),
      child: Center(
        child: Text(
          '${widget.etiqueta}: $toques',
          key: ValueKey('texto-${widget.etiqueta}'),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() {
    di.sl.registerSingleton<CubitCola>(CubitCola());
    di.sl.registerSingleton<ValueNotifier<int>>(ValueNotifier<int>(1));
    // Los notificadores que consultan el fondo ambiente y el navbar.
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(
      ValueNotifier(PreferenciasApariencia.deFabrica),
    );
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(
      ValueNotifier(const PreferenciasEstilo()),
    );
    di.sl.registerSingleton<ValueNotifier<PreferenciasVistas>>(
      ValueNotifier(PreferenciasVistas.deFabrica),
    );
    di.sl.registerSingleton<ValueNotifier<PerfilRendimiento>>(
      ValueNotifier(PerfilRendimiento.alto),
    );
  });

  setUp(() {
    nacimientos = 0;
    // Cada prueba arranca en Inicio, como una app recién abierta.
    di.sl<ValueNotifier<int>>().value = 1;
  });

  Widget app() {
    final tutorial = TutorialController();
    addTearDown(tutorial.dispose);
    return MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: TutorialProvider(
        controller: tutorial,
        child: BlocProvider<CubitCola>.value(
          value: di.sl<CubitCola>(),
          child: HomeMovil(
            buscador: const _SeccionFalsa('A'),
            feed: const _SeccionFalsa('B'),
            miEspacio: const _SeccionFalsa('C'),
            miniPlayer: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  /// Toca una pestaña del navbar por su ícono (los rótulos del navbar son
  /// Semantics, no texto, para no duplicar el de la sección).
  Future<void> irASeccion(WidgetTester tester, IconData icono) async {
    await tester.tap(find.byIcon(icono));
    await tester.pumpAndSettle();
  }

  testWidgets('cambiar de sección y volver no reconstruye ninguna', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    // Arranca en Inicio: el PageView sólo construyó esa sección.
    expect(find.text('B: 0'), findsOneWidget);
    expect(nacimientos, 1, reason: 'sólo se arma la sección visible');

    // El usuario hace algo en Inicio (dos toques) y se va a Buscar.
    await tester.tap(find.byKey(const ValueKey('tocar-B')));
    await tester.tap(find.byKey(const ValueKey('tocar-B')));
    await tester.pumpAndSettle();
    expect(find.text('B: 2'), findsOneWidget);

    await irASeccion(tester, Icons.search_rounded);
    expect(nacimientos, 2, reason: 'Buscar se arma la primera vez');

    await irASeccion(tester, Icons.grid_view_rounded);
    expect(nacimientos, 3, reason: 'Mi Espacio se arma la primera vez');

    // Y ahora el viaje de vuelta: ninguna sección vuelve a nacer...
    await irASeccion(tester, Icons.search_rounded);
    await irASeccion(tester, Icons.home_rounded);
    expect(
      nacimientos,
      3,
      reason: 'volver a una sección no puede crear otro estado',
    );

    // ...y lo que el usuario había hecho en Inicio sigue ahí.
    expect(
      find.text('B: 2'),
      findsOneWidget,
      reason: 'los toques de Inicio sobreviven la vuelta',
    );
  });

  testWidgets('la pestaña activa se recuerda entre montajes del shell', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await irASeccion(tester, Icons.grid_view_rounded);

    // El shell se desmonta y se vuelve a montar (volver a la Home por un enlace
    // compartido, cambiar de tamaño la ventana, etc.): tiene que abrir donde el
    // usuario estaba, no en Inicio.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('C: 0'), findsOneWidget, reason: 'abre en Mi Espacio');
  });
}
