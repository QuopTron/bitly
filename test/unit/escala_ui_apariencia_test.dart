// ─────────────────────────────────────────────────────────────
// escala_ui_apariencia_test.dart — Fija el tamaño de letras e iconos que se
// elige en Ajustes → Apariencia → Diseño.
//
// Por qué importa: son dos preferencias que se aplican en TODA la app (el texto
// por el `textScaler` del árbol y los iconos por las piezas compartidas), así
// que un error acá no se ve en una vista: se ve en todas. Los tests cubren que
// se guarden y se lean (con sus rangos), que la escala global se aplique, y que
// el texto SUME al tamaño de fuente del sistema en vez de pisarlo.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/shared/utilidades/plataforma/pantalla/escala_texto.dart';
import 'package:bitly/shared/utilidades/plataforma/pantalla/escala_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Escala efectiva que ve un hijo al aplicar [acotarEscalaTexto].
Future<double> escalaEfectiva(WidgetTester tester, double delSistema) async {
  late TextScaler visto;
  await tester.pumpWidget(
    MaterialApp(
      // El `MediaQuery` simula el tamaño de fuente del SISTEMA, y el `Builder`
      // de adentro es el contexto que ve ese valor (leer desde un contexto por
      // encima del MediaQuery devolvería el de fábrica).
      home: MediaQuery(
        data: const MediaQueryData().copyWith(
          textScaler: TextScaler.linear(delSistema),
        ),
        child: Builder(
          builder:
              (context) => acotarEscalaTexto(
                context: context,
                child: Builder(
                  builder: (inner) {
                    visto = MediaQuery.textScalerOf(inner);
                    return const SizedBox.shrink();
                  },
                ),
              ),
        ),
      ),
    ),
  );
  return visto.scale(14) / 14;
}

void main() {
  setUp(EscalaUi.reiniciar);
  tearDown(EscalaUi.reiniciar);

  group('se guardan y se leen', () {
    test('de fábrica las dos escalas son 1 (nada cambia)', () {
      const p = PreferenciasApariencia.deFabrica;
      expect(p.escalaTexto, 1);
      expect(p.escalaIconos, 1);
      expect(p.esDeFabrica, isTrue);
    });

    test('sobreviven al viaje a JSON y vuelta', () {
      final guardado =
          PreferenciasApariencia.deFabrica
              .copiarCon(escalaTexto: 1.25, escalaIconos: 0.9)
              .toJsonString();
      final leido = PreferenciasApariencia.desdeJsonString(guardado);
      expect(leido.escalaTexto, 1.25);
      expect(leido.escalaIconos, 0.9);
      expect(leido.esDeFabrica, isFalse);
    });

    test('se acotan al rango soportado por el diseño', () {
      final p = PreferenciasApariencia.deFabrica.copiarCon(
        escalaTexto: 5,
        escalaIconos: 0.1,
      );
      expect(p.escalaTexto, PreferenciasApariencia.maxEscala);
      expect(p.escalaIconos, PreferenciasApariencia.minEscala);
    });

    test('el afinado por componente también viaja a JSON', () {
      final p = PreferenciasApariencia.deFabrica.copiarCon(
        escalaTitulos: 1.2,
        escalaTextos: 0.9,
        escalaIconosCards: 1.1,
        escalaIconosBarras: 0.95,
      );
      final leido = PreferenciasApariencia.desdeJsonString(p.toJsonString());
      expect(leido.escalaTitulos, 1.2);
      expect(leido.escalaTextos, 0.9);
      expect(leido.escalaIconosCards, 1.1);
      expect(leido.escalaIconosBarras, 0.95);
    });

    test('el afinado por componente se acota igual que el general', () {
      final p = PreferenciasApariencia.deFabrica.copiarCon(
        escalaTitulos: 9,
        escalaIconosBarras: 0,
      );
      expect(p.escalaTitulos, PreferenciasApariencia.maxEscala);
      expect(p.escalaIconosBarras, PreferenciasApariencia.minEscala);
    });

    test('una preferencia vieja sin las claves nuevas queda en 1', () {
      // Lo que hay guardado hoy en los equipos (previo a este ajuste).
      final leido = PreferenciasApariencia.desdeJsonString(
        '{"radioCards":14,"cancionX":1,"cancionY":1,"grillaX":1,"grillaY":1}',
      );
      expect(leido.escalaTexto, 1);
      expect(leido.escalaIconos, 1);
    });
  });

  group('la escala global', () {
    test('aplicarDesde lleva las dos al notifier', () {
      EscalaUi.aplicarDesde(
        PreferenciasApariencia.deFabrica.copiarCon(
          escalaTexto: 1.15,
          escalaIconos: 1.3,
        ),
      );
      expect(EscalaUi.texto.value, 1.15);
      expect(EscalaUi.iconos.value, 1.3);
    });

    test('aplicarDesde también lleva el afinado por componente', () {
      EscalaUi.aplicarDesde(
        PreferenciasApariencia.deFabrica.copiarCon(
          escalaTitulos: 1.1,
          escalaTextos: 0.9,
          escalaIconosCards: 1.2,
          escalaIconosBarras: 1.05,
        ),
      );
      expect(EscalaUi.titulos.value, 1.1);
      expect(EscalaUi.textos.value, 0.9);
      expect(EscalaUi.iconosCards.value, 1.2);
      expect(EscalaUi.iconosBarras.value, 1.05);
    });

    test('el general y el componente SE MULTIPLICAN', () {
      // Subir "Letras" agranda lo que el usuario ya había separado, en vez de
      // pisarlo: es lo que espera quien afinó una cosa y después mueve el
      // control general.
      EscalaUi.aplicarDesde(
        PreferenciasApariencia.deFabrica.copiarCon(
          escalaTexto: 1.2,
          escalaTitulos: 1.1,
          escalaTextos: 0.9,
          escalaIconos: 1.1,
          escalaIconosCards: 1.2,
          escalaIconosBarras: 0.9,
        ),
      );
      expect(EscalaUi.factorTitulos, closeTo(1.32, 0.001));
      expect(EscalaUi.factorTextos, closeTo(1.08, 0.001));
      expect(EscalaUi.factorIconosCards, closeTo(1.32, 0.001));
      expect(EscalaUi.factorIconosBarras, closeTo(0.99, 0.001));
    });

    test('de fábrica los cuatro factores son 1', () {
      expect(EscalaUi.factorTitulos, 1);
      expect(EscalaUi.factorTextos, 1);
      expect(EscalaUi.factorIconosCards, 1);
      expect(EscalaUi.factorIconosBarras, 1);
    });

    test('reiniciar la devuelve al tamaño de fábrica', () {
      EscalaUi.texto.value = 1.4;
      EscalaUi.reiniciar();
      expect(EscalaUi.texto.value, 1);
      expect(EscalaUi.iconos.value, 1);
    });
  });

  group('el texto', () {
    testWidgets('sin preferencia deja EXACTAMENTE la escala del sistema', (
      tester,
    ) async {
      expect(await escalaEfectiva(tester, 1.3), closeTo(1.3, 0.001));
    });

    testWidgets('la preferencia agranda las letras de toda la app', (
      tester,
    ) async {
      EscalaUi.texto.value = 1.2;
      expect(await escalaEfectiva(tester, 1), closeTo(1.2, 0.001));
    });

    testWidgets('suma al tamaño que ya pide el teléfono, no lo pisa', (
      tester,
    ) async {
      // El usuario subió la fuente del sistema Y eligió 1.2 en la app:
      // espera un poco más grande que como lo dejó el sistema (1.15 × 1.2).
      EscalaUi.texto.value = 1.2;
      expect(await escalaEfectiva(tester, 1.15), closeTo(1.38, 0.01));
    });

    testWidgets('nunca pasa del techo absoluto', (tester) async {
      EscalaUi.texto.value = PreferenciasApariencia.maxEscala;
      final escala = await escalaEfectiva(tester, escalaTextoMaxima);
      expect(escala, lessThanOrEqualTo(escalaTextoMaximaAbsoluta + 0.001));
    });

    testWidgets('una escala muy chica se acota al mínimo legible', (
      tester,
    ) async {
      expect(await escalaEfectiva(tester, 0.5), escalaTextoMinima);
    });
  });
}
