// fondos_legibles_test.dart — Verifica los FONDOS REALES con una portada de
// verdad, del mismo modo que se miraría a ojo: se fabrica un PNG de un color
// claro y saturado (el caso que rompía), se monta el widget tal cual lo usa la
// app y se mide lo que pinta.
//
// Es el complemento de `cover_dominante_test` (que fija la cuenta del helper):
// acá se comprueba que el reproductor, la Home y los modales —cola, karaoke,
// hoja de playlist— pasan por esa cuenta. Cada caso exige DOS cosas:
//   1. el fondo quedó con el color del cover (no con el del tema), y
//   2. las letras del tema llegan al contraste mínimo encima de él.
// Antes, un cover claro y saturado al 100% en tema oscuro dejaba el texto del
// tema al borde de lo ilegible.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/perfil/perfil_rendimiento.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_estilo.dart';
import 'package:bitly/features/reproductor/pagina/base/reproductor_pagina.dart';
import 'package:bitly/shared/utilidades/portada/paleta/paleta_portada.dart'
    show PaletaPortada, paletaParaPortada, relacionContraste;
import 'package:bitly/shared/widgets/fondos/ambiente/fondo_ambiente.dart';
import 'package:bitly/shared/widgets/fondos/ambiente/atenuado_por_nivel.dart';
import 'package:bitly/shared/widgets/vidrio/base/fondo_reactivo_portada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fondoOscuro = Color(0xFF000000);
  const fondoClaro = Color(0xFFFFFFFF);

  late ValueNotifier<PreferenciasEstilo> prefs;
  late Directory temporal;

  setUpAll(() {
    prefs = ValueNotifier(PreferenciasEstilo.normal);
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(prefs);
    di.sl.registerSingleton<ValueNotifier<PerfilRendimiento>>(
      ValueNotifier(PerfilRendimiento.alto),
    );
  });

  setUp(() async {
    prefs.value = PreferenciasEstilo.normal;
    temporal = await Directory.systemTemp.createTemp('bitly-portadas');
  });

  tearDown(() {
    if (temporal.existsSync()) temporal.deleteSync(recursive: true);
  });

  /// Escribe una portada PNG de [color] y devuelve su ruta: entra por el mismo
  /// camino que cualquier carátula del disco.
  Future<String> portada(Color color) async {
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 64, 64), Paint()..color = color);
    final cuadro = await recorder.endRecording().toImage(64, 64);
    final data = await cuadro.toByteData(format: ui.ImageByteFormat.png);
    cuadro.dispose();
    final archivo = File('${temporal.path}/tapa-${color.toARGB32()}.png');
    archivo.writeAsBytesSync(data!.buffer.asUint8List());
    return archivo.path;
  }

  /// El color con el que el fondo pinta su capa de tinte, o null si todavía no
  /// la pinta (el modal no dibuja nada hasta tener la paleta).
  /// `AnimatedContainer` guarda el `color` como una `BoxDecoration`.
  Color? tintePintado(WidgetTester tester) {
    final cajas = find.byType(AnimatedContainer).evaluate();
    if (cajas.isEmpty) return null;
    final deco =
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .decoration;
    return deco is BoxDecoration ? deco.color : null;
  }

  /// Monta [fondo] y devuelve la paleta y el tinte pintado.
  ///
  /// La paleta se resuelve ANTES (una sola vez, con IO real): así el widget la
  /// recibe al instante y la medición no depende de cuánto tarde el decode.
  Future<({PaletaPortada paleta, Color? pintado})> montar(
    WidgetTester tester,
    Widget Function(String cover) fondo,
    String cover, {
    required Brightness brillo,
  }) async {
    final paleta = await tester.runAsync(() => paletaParaPortada(cover));
    expect(paleta, isNotNull, reason: 'la portada $cover no dio paleta');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brillo),
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 320, height: 320, child: fondo(cover)),
          ),
        ),
      ),
    );
    // 1. La paleta ya está en caché, así que el widget la recibe enseguida.
    await tester.pump();
    await tester.pump();
    // 2. Igual se deja correr un poco de tiempo REAL: el widget arranca su
    //    extracción desde `initState`, y las continuaciones de un Future creado
    //    en la zona de test necesitan que se drene el microtask queue.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
    }
    return (paleta: paleta!, pintado: tintePintado(tester));
  }

  /// Un caso: portada clara y saturada, y de qué color TIENE que quedar el
  /// fondo (su familia de tono). Si el fondo queda gris es que la paleta no
  /// llegó; si queda de otro tono, el tinte no es el del cover.
  void caso({
    required String titulo,
    required ComponenteEstilo componente,
    required Widget Function(String cover, bool esOscuro) fondo,
  }) {
    testWidgets(titulo, (tester) async {
      // Portada, cómo se ve su tono, y de qué familia tiene que quedar el tinte.
      final portadas = <(Color, String, bool Function(Color))>[
        (
          const Color(0xFF7CFF7C),
          'verde claro',
          (c) => c.g > c.r + 0.05 && c.g > c.b + 0.05,
        ),
        (
          const Color(0xFF80FFFF),
          'cian claro',
          (c) => c.g > c.r + 0.05 && c.b > c.r + 0.05,
        ),
        (
          const Color(0xFFFFF080),
          'amarillo claro',
          (c) => c.r > c.b + 0.05 && c.g > c.b + 0.05,
        ),
      ];

      for (final esOscuro in const [true, false]) {
        final texto = esOscuro ? Colors.white : Colors.black;
        final brillo = esOscuro ? Brightness.dark : Brightness.light;
        for (final (color, nombre, mismoTono) in portadas) {
          final cover = await tester.runAsync(() => portada(color));
          prefs.value = const PreferenciasEstilo().conNivel(componente, 1);

          final m = await montar(
            tester,
            (c) => fondo(c, esOscuro),
            cover!,
            brillo: brillo,
          );
          final pintado = m.pintado;
          expect(
            pintado,
            isNotNull,
            reason: '${m.paleta.acentoTinte}: el fondo no pinta su tinte',
          );
          expect(
            mismoTono(pintado!),
            isTrue,
            reason:
                'con la portada $nombre el fondo quedó en $pintado: no tiene '
                'el color del cover (oscuro=$esOscuro)',
          );
          expect(
            relacionContraste(texto, pintado),
            greaterThanOrEqualTo(4.5),
            reason:
                'con la portada $nombre (oscuro=$esOscuro) las letras del '
                'tema quedan por debajo de AA sobre $pintado',
          );
        }
      }
    });
  }

  group('los fondos reales con una portada clara y saturada', () {
    caso(
      titulo: 'reproductor: el tinte es el del cover y las letras se leen',
      componente: ComponenteEstilo.fondoReproductor,
      fondo:
          (cover, esOscuro) => FondoAmbientalReproductor(
            coverUrl: cover,
            esOscuro: esOscuro,
            colorFondo: esOscuro ? fondoOscuro : fondoClaro,
          ),
    );

    caso(
      titulo: 'Home: el tinte es el del cover y las letras se leen',
      componente: ComponenteEstilo.fondoPrincipal,
      fondo:
          (cover, esOscuro) => FondoAmbiente(
            coverUrl: cover,
            isDark: esOscuro,
            bgColor: esOscuro ? fondoOscuro : fondoClaro,
          ),
    );

    caso(
      titulo: 'modales (cola, karaoke, playlist): el tinte y las letras',
      componente: ComponenteEstilo.fondosModals,
      fondo:
          (cover, esOscuro) =>
              FondoReactivoPortada(caratula: cover, esOscuro: esOscuro),
    );

    testWidgets('y con el diseño de fábrica el tinte no se pinta', (
      tester,
    ) async {
      final cover = await tester.runAsync(
        () => portada(const Color(0xFF7CFF7C)),
      );
      prefs.value = PreferenciasEstilo.normal;
      await montar(
        tester,
        (c) => FondoAmbientalReproductor(
          coverUrl: c,
          esOscuro: true,
          colorFondo: fondoOscuro,
        ),
        cover!,
        brillo: Brightness.dark,
      );
      // Sin intensidad, el fondo del reproductor queda como siempre: la
      // carátula entera y el tinte apagado (el mismo color, con opacidad 0).
      final capas =
          tester
              .widgetList<AtenuadoPorNivel>(find.byType(AtenuadoPorNivel))
              .toList();
      expect(capas, hasLength(2), reason: 'carátula + tinte');
      expect(capas.first.opacidad, 1.0, reason: 'la carátula sigue entera');
      expect(capas.last.opacidad, 0.0, reason: 'el tinte no se pinta');
    });
  });
}
