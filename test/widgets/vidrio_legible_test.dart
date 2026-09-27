// vidrio_legible_test.dart — Mide el contraste del TEXTO DEL TEMA sobre las
// superficies que no son la del tema liso: el vidrio del navbar flotante (que
// sí lleva BackdropFilter), el miniplayer (fondo opaco teñido con la paleta del
// cofre) y el panel de la hoja de fiesta.
//
// La pregunta que responde: ¿el fondo (difuminado o teñido) debilita el texto?
// La respuesta queda fijada acá: el vidrio y el tinte se acercan a la
// superficie del tema, que es del mismo lado que el texto, así que el contraste
// no baja del mínimo. El peor caso medido es el del navbar en tema oscuro con
// un fondo blanco detrás: 9.2:1.

import 'package:bitly/core/modelos/usuario/disenos/base/catalogo_disenos_barra_lista.dart';
import 'package:bitly/features/reproductor/fiesta/hoja_fiesta.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/tema/colores_app.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/visual/apariencia_paleta_helper.dart';
import 'package:bitly/shared/utilidades/portada/paleta/paleta_portada.dart'
    show relacionContraste;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // El miniplayer escribe su fondo con estos dos colores base.
  const baseMiniOscuro = Color(0xFF0B0B14);
  const baseMiniClaro = Color(0xFFFFFFFF);
  // Opacidad del vidrio del navbar (superficie del tema sobre el blur).
  const alphaVidrio = 0.80;

  /// Fondos que pueden quedar DETRÁS de una superficie flotante: desde negro
  /// puro hasta blanco puro, más los tintes claros y saturados que puede
  /// pintar la Home con una portada luminosa.
  List<Color> fondosDePrueba() => [
    for (var v = 0; v <= 255; v += 15) Color.fromARGB(255, v, v, v),
    const Color(0xFF7CFF7C),
    const Color(0xFF80FFFF),
    const Color(0xFFFFF080),
    const Color(0xFFFF7A59),
  ];

  group('navbar flotante: el vidrio con blur no debilita el texto', () {
    test('con cualquier fondo detrás, el texto del tema llega a AA', () {
      for (final esOscuro in const [true, false]) {
        final texto = ColoresApp.enSuperficie(esOscuro);
        final vidrio = ColoresApp.superficie(
          esOscuro,
        ).withValues(alpha: alphaVidrio);
        var peor = 100.0;
        for (final fondo in fondosDePrueba()) {
          // Lo que se ve: el vidrio (80% de superficie) sobre el fondo
          // difuminado. El blur no cambia un fondo parejo, así que el peor caso
          // es el color extremo.
          final compuesto = Color.alphaBlend(vidrio, fondo);
          final ratio = relacionContraste(texto, compuesto);
          if (ratio < peor) peor = ratio;
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                'oscuro=$esOscuro con el fondo $fondo el texto queda en '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
        expect(
          peor,
          greaterThanOrEqualTo(4.5),
          reason: 'el peor caso del vidrio tiene que quedar en AA',
        );
      }
    });

    test('incluso el peor caso queda con margen de sobra', () {
      // El vidrio mezcla la superficie del tema (del mismo lado que su texto)
      // con lo de atrás, así que nunca llega a valer el fondo puro: se deja
      // fijado cuánto margen queda en el extremo.
      for (final esOscuro in const [true, false]) {
        final texto = ColoresApp.enSuperficie(esOscuro);
        final vidrio = ColoresApp.superficie(
          esOscuro,
        ).withValues(alpha: alphaVidrio);
        // El fondo más opuesto posible al texto del tema.
        final peorFondo = esOscuro ? Colors.white : Colors.black;
        final peorCompuesto = Color.alphaBlend(vidrio, peorFondo);
        expect(
          relacionContraste(texto, peorCompuesto),
          greaterThanOrEqualTo(8.0),
          reason:
              'oscuro=$esOscuro: con el fondo $peorFondo el compuesto queda en '
              '${relacionContraste(texto, peorCompuesto).toStringAsFixed(2)}:1',
        );
      }
    });
  });

  group('miniplayer: fondo opaco teñido con la paleta del cofre', () {
    test(
      'con cualquier paleta del cofre y en los dos temas, el texto se lee',
      () {
        // Las paletas REALES del catálogo (incluidas las de cada aparato).
        expect(coloresCofreBarra, isNotEmpty);
        for (final diseno in coloresCofreBarra) {
          final paleta = [for (final c in diseno.paleta) Color(c)];
          for (final esOscuro in const [true, false]) {
            final texto = ColoresApp.enSuperficie(esOscuro);
            final gradiente = AparienciaPaleta.gradiente(
              paleta,
              esOscuro: esOscuro,
              base: esOscuro ? baseMiniOscuro : baseMiniClaro,
            );
            expect(
              gradiente,
              isNotNull,
              reason: 'la paleta ${diseno.id} tiene que pintar su gradiente',
            );
            for (final color in gradiente!.colors) {
              expect(
                relacionContraste(texto, color),
                greaterThanOrEqualTo(4.5),
                reason:
                    'la paleta ${diseno.id} (oscuro=$esOscuro) deja el texto en '
                    '${relacionContraste(texto, color).toStringAsFixed(2)}:1 '
                    'sobre $color',
              );
            }
          }
        }
      },
    );

    test('el fondo del miniplayer es OPACO (no depende de lo de atrás)', () {
      // Es la razón por la que el miniplayer no lleva BackdropFilter: su fondo
      // tapa lo de abajo, así que el texto no compite con la Home.
      for (final esOscuro in const [true, false]) {
        final base = esOscuro ? baseMiniOscuro : baseMiniClaro;
        expect(base.a, 1.0);
        expect(
          relacionContraste(ColoresApp.enSuperficie(esOscuro), base),
          greaterThanOrEqualTo(4.5),
        );
      }
    });
  });

  group('panel de la hoja de fiesta', () {
    testWidgets('su fondo es una superficie opaca y sin blur', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          locale: const Locale('es'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es'), Locale('en')],
          home: Scaffold(
            body: panelFiesta(
              fiesta: null,
              lan: null,
              habilitado: true,
              ocupado: false,
              onArmar: () async {},
              onUnirse: (_) async {},
              onCortar: () async {},
              onSalir: () async {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Ningún desenfoque de fondo: lo que se ve detrás del texto es la
      // superficie del tema, no la Home difuminada.
      expect(find.byType(BackdropFilter), findsNothing);

      // El panel (el primer Container con decoración de la hoja) pinta la
      // superficie del tema, opaca.
      final decorados =
          tester
              .widgetList<Container>(find.byType(Container))
              .map((c) => c.decoration)
              .whereType<BoxDecoration>()
              .toList();
      final panel = decorados.firstWhere(
        (d) => d.borderRadius != null && d.color != null,
      );
      expect(panel.color!.a, 1.0, reason: 'el panel no puede ser translúcido');
      expect(panel.color, ColoresApp.superficie(true));
      expect(
        relacionContraste(ColoresApp.enSuperficie(true), panel.color!),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        relacionContraste(ColoresApp.enSuperficieApagado(true), panel.color!),
        greaterThanOrEqualTo(3.0),
        reason: 'el texto secundario del panel llega al piso de texto grande',
      );
    });
  });
}
