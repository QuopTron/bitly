// ─────────────────────────────────────────────────────────────
// apariencia_vistas_cascada_test.dart — La CASCADA del diseño por vista:
// lo que una vista no declara tiene que caer al estilo GLOBAL del usuario, y lo
// que declara tiene que ganarle. Es el mecanismo del que depende todo lo demás
// (color, forma, radio, densidad, columnas y ahora también la tipografía).
// Parte del flujo: Ajustes → Apariencia → Vistas.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/disenos/vistas/diseno_vista.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/preferencias_vistas.dart';
import 'package:bitly/core/modelos/usuario/disenos/vistas/vista_app.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/vistas/apariencia_vistas_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BuildContext ctx;

  // El reset de GetIt es ASÍNCRONO: si no se espera, borra lo que se registre
  // justo después (ver servicio_fuentes_test.dart).
  setUp(() async {
    await di.sl.reset();
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(
      ValueNotifier(PreferenciasApariencia.deFabrica),
    );
    di.sl.registerSingleton<ValueNotifier<PreferenciasVistas>>(
      ValueNotifier(PreferenciasVistas.deFabrica),
    );
  });

  tearDown(() => di.sl.reset());

  /// Monta un context real y lo deja disponible para resolver la cascada.
  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  testWidgets('sin tocar nada, la vista hereda el diseño de fábrica', (
    tester,
  ) async {
    await montar(tester);

    final d = AparienciaVistas.de(ctx, VistaApp.feed);
    expect(d.tipografiaId, '', reason: 'sin elección global');
    expect(d.radioTarjeta, PreferenciasApariencia.deFabrica.radioCards);
    expect(d.densidad, 1);
    expect(d.columnasMax, 0);
    expect(d.tieneConjunto, isFalse);
  });

  testWidgets('la tipografía GLOBAL llega a todas las vistas que no la pisan', (
    tester,
  ) async {
    await montar(tester);
    di.sl<ValueNotifier<PreferenciasApariencia>>().value =
        PreferenciasApariencia.deFabrica.copiarCon(fuenteId: 'rubik');

    for (final vista in VistaApp.values) {
      expect(
        AparienciaVistas.de(ctx, vista).tipografiaId,
        'rubik',
        reason: '${vista.clave} debería heredar la tipografía global',
      );
    }
  });

  testWidgets('una vista puede salirse de la tipografía global', (tester) async {
    await montar(tester);
    di.sl<ValueNotifier<PreferenciasApariencia>>().value =
        PreferenciasApariencia.deFabrica.copiarCon(fuenteId: 'rubik');
    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica.conVista(
          VistaApp.feed,
          const DisenoVista(tipografiaId: 'jetbrains_mono'),
        );

    expect(
      AparienciaVistas.de(ctx, VistaApp.feed).tipografiaId,
      'jetbrains_mono',
    );
    // Las demás siguen heredando: tocar una vista no toca el resto.
    expect(AparienciaVistas.de(ctx, VistaApp.ajustes).tipografiaId, 'rubik');
  });

  testWidgets('lo que declara la vista gana sobre el global', (tester) async {
    await montar(tester);
    di.sl<ValueNotifier<PreferenciasApariencia>>().value =
        PreferenciasApariencia.deFabrica.copiarCon(radioCards: 4);
    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica.conVista(
          VistaApp.detalle,
          const DisenoVista(radioTarjeta: 24, densidad: 1.5, columnasMax: 5),
        );

    final d = AparienciaVistas.de(ctx, VistaApp.detalle);
    expect(d.radioTarjeta, 24, reason: 'el de la vista, no el global');
    expect(d.densidad, 1.5);
    expect(d.columnasMax, 5);
    // La densidad se aplica sobre las separaciones que ya calcula la vista.
    expect(d.espacio(10), closeTo(15, 0.001));
    // Y otra vista sigue con el global.
    expect(AparienciaVistas.de(ctx, VistaApp.feed).radioTarjeta, 4);
  });

  testWidgets('la paleta del cofre se resuelve para la vista que la eligió', (
    tester,
  ) async {
    await montar(tester);
    // Sin paleta elegida no hay tinte que resolver…
    expect(AparienciaVistas.de(ctx, VistaApp.feed).paleta, isEmpty);
    // …y el estilo GLOBAL no la define: el cofre es de cada vista, así que
    // tocar la apariencia general no puede encender una paleta en toda la app.
    di.sl<ValueNotifier<PreferenciasApariencia>>().value =
        PreferenciasApariencia.deFabrica.copiarCon(radioCards: 4);
    expect(AparienciaVistas.de(ctx, VistaApp.feed).paleta, isEmpty);

    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica.conVista(
          VistaApp.feed,
          const DisenoVista(disenoId: 'paleta_aurora'),
        );

    final deFeed = AparienciaVistas.de(ctx, VistaApp.feed);
    expect(deFeed.paleta, isNotEmpty);
    expect(deFeed.paleta, paletaDeDiseno('paleta_aurora'));
    // Y las demás vistas no se tiñen por eso.
    expect(AparienciaVistas.de(ctx, VistaApp.busqueda).paleta, isEmpty);
  });

  testWidgets('cambiar el global se refleja sin tocar las vistas', (
    tester,
  ) async {
    await montar(tester);
    di.sl<ValueNotifier<PreferenciasVistas>>().value =
        PreferenciasVistas.deFabrica.conVista(
          VistaApp.feed,
          const DisenoVista(disenoId: 'aurora'),
        );

    expect(AparienciaVistas.de(ctx, VistaApp.feed).tieneConjunto, isTrue);
    // La densidad sigue heredada aunque la vista haya elegido su conjunto.
    expect(AparienciaVistas.de(ctx, VistaApp.feed).densidad, 1);
    // Y una vista sin personalizar no tiene conjunto propio.
    expect(AparienciaVistas.de(ctx, VistaApp.tutorial).tieneConjunto, isFalse);
  });
}
