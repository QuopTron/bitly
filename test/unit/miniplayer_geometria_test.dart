// ─────────────────────────────────────────────────────────────
// miniplayer_geometria_test.dart — Las medidas del miniplayer: que el preset de
// fábrica reproduzca EXACTAMENTE lo de hoy en cada aparato y que las acotadas
// eviten las salidas de diseño (margen que se come el ancho, carátula que se
// come los controles, ventana ridículamente angosta).
//
// Es una función pura a propósito: así se prueba la tele, la PC y el celular
// sin montar la app ni simular pantallas.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/barras/miniplayer_geometria.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las medidas de HOY por aparato, tal como las usaba cada shell.
const _baseCaratulaMovil = 36.0;
const _baseRadioMovil = 6.0;
const _baseMargenPc = 18.0;
const _baseMargenTv = 22.0;

void main() {
  /// Geometría con las medidas de hoy para el aparato pedido.
  MiniplayerGeometria calcular({
    TamanoMiniplayer tamano = TamanoMiniplayer.normal,
    FormaMiniplayer forma = FormaMiniplayer.auto,
    bool esTv = false,
    bool esEscritorio = false,
    double ancho = 390,
    double baseCaratula = _baseCaratulaMovil,
    double baseRadio = _baseRadioMovil,
    double baseMargen = _baseMargenPc,
    double topeAncho = 0,
  }) => MiniplayerGeometria.calcular(
    tamano: tamano,
    forma: forma,
    esTv: esTv,
    esEscritorio: esEscritorio,
    anchoDisponible: ancho,
    baseCaratula: baseCaratula,
    baseRadioCaratula: baseRadio,
    baseMargen: baseMargen,
    topeAncho: topeAncho,
  );

  group('de fábrica reproduce lo de HOY', () {
    test('celular: pegado al borde, sin sombra', () {
      final g = calcular();
      expect(g.margenLateral, 0);
      expect(g.flotante, isFalse);
      expect(g.conSombra, isFalse);
      expect(g.ladoCaratula, _baseCaratulaMovil);
      expect(g.radioCaratula, _baseRadioMovil);
      expect(g.factorIconos, 1.0);
    });

    test('PC: flotante con margen y sombra', () {
      final g = calcular(esEscritorio: true, ancho: 1440);
      expect(g.margenLateral, _baseMargenPc);
      expect(g.flotante, isTrue);
      expect(g.conSombra, isTrue);
    });

    test('TV: flotante pero SIN sombra', () {
      // En una tele la sombra se recompone en cada frame y a metros no se ve.
      final g = calcular(esTv: true, ancho: 1920, baseMargen: _baseMargenTv);
      expect(g.margenLateral, _baseMargenTv);
      expect(g.flotante, isTrue);
      expect(g.conSombra, isFalse);
    });

    test('la carátula de la tele se respeta al agrandarla', () {
      // Base 64 y "grande": sigue muy por debajo del 22% de 1920.
      final g = calcular(
        esTv: true,
        ancho: 1920,
        baseCaratula: 64,
        tamano: TamanoMiniplayer.grande,
      );
      expect(g.ladoCaratula, 64 * 1.25);
    });
  });

  group('los presets mueven lo que dicen mover', () {
    test('grande agranda la carátula y los iconos', () {
      final normal = calcular();
      final grande = calcular(tamano: TamanoMiniplayer.grande);
      expect(grande.ladoCaratula, greaterThan(normal.ladoCaratula));
      expect(grande.factorIconos, greaterThan(normal.factorIconos));
    });

    test('compacto encoge', () {
      final compacto = calcular(tamano: TamanoMiniplayer.compacto);
      expect(compacto.ladoCaratula, lessThan(_baseCaratulaMovil));
      expect(compacto.factorIconos, lessThan(1.0));
    });

    test('los iconos crecen MENOS que la carátula', () {
      // Si crecieran igual, el título de la canción quedaría en tres letras.
      final g = calcular(tamano: TamanoMiniplayer.grande);
      expect(
        g.factorIconos,
        lessThan(TamanoMiniplayer.grande.factorCaratula),
      );
    });
  });

  group('las formas', () {
    test('elegir pegada gana sobre el automático de la PC', () {
      final g = calcular(esEscritorio: true, forma: FormaMiniplayer.pegado);
      expect(g.margenLateral, 0);
      expect(g.flotante, isFalse);
      expect(g.conSombra, isFalse, reason: 'sin margen no hay dónde caer');
    });

    test('elegir flotante en el celular sí despega la barra', () {
      final g = calcular(forma: FormaMiniplayer.flotante);
      expect(g.flotante, isTrue);
      expect(g.margenLateral, greaterThan(0));
    });
  });

  group('las acotadas evitan las salidas de diseño', () {
    test('el margen nunca se come más del 6% del ancho', () {
      // 6% de 200 son 12 px: menos que el margen cómodo de la PC.
      final g = calcular(esEscritorio: true, ancho: 200, baseMargen: 18);
      expect(g.margenLateral, closeTo(12, 0.001));
      expect(g.anchoUtil, greaterThan(g.anchoDisponible / 2));
    });

    test('el margen tiene piso: flotante se tiene que notar flotante', () {
      // Con base 4 (un aparato que pidiera muy poco) igual queda en 10.
      final g = calcular(esEscritorio: true, ancho: 1440, baseMargen: 4);
      expect(g.margenLateral, 10);
    });

    test('la carátula nunca pasa el 22% del ancho', () {
      // "Grande" en una ventana angosta: base 40 × 1.25 = 50, pero el 22% de
      // 200 son 44. Si no se acotara, la carátula se comería el título y los
      // controles.
      final g = calcular(
        ancho: 200,
        baseCaratula: 40,
        tamano: TamanoMiniplayer.grande,
      );
      expect(g.ladoCaratula, closeTo(44, 0.001));
    });

    test('la carátula tiene piso: la portada se tiene que distinguir', () {
      final g = calcular(
        baseCaratula: 20,
        tamano: TamanoMiniplayer.compacto,
      );
      expect(g.ladoCaratula, 24);
    });

    test('una ventana más angosta que 2× el margen mínimo no explota', () {
      // Sin la guarda, el `clamp` de Dart tiraría por min > max.
      final g = calcular(esEscritorio: true, ancho: 12, baseMargen: 18);
      expect(g.margenLateral, closeTo(12 * 0.06, 0.001));
      expect(g.ladoCaratula, lessThanOrEqualTo(12 * 0.22 + 0.001));
    });

    test('el ancho útil siempre es positivo', () {
      for (final ancho in [12.0, 320.0, 390.0, 1024.0, 1920.0, 3840.0]) {
        for (final forma in FormaMiniplayer.values) {
          for (final tamano in TamanoMiniplayer.values) {
            for (final tope in AnchoMiniplayer.values) {
              final g = calcular(
                ancho: ancho,
                forma: forma,
                tamano: tamano,
                esEscritorio: ancho > 900,
                baseMargen: 18,
                topeAncho: tope.tope,
              );
              expect(
                g.anchoUtil,
                greaterThan(0),
                reason: '$ancho/$forma/$tamano/${tope.clave}',
              );
              expect(
                g.anchoBarra,
                greaterThan(0),
                reason: '$ancho/$forma/$tamano/${tope.clave}',
              );
            }
          }
        }
      }
    });
  });

  group('el ancho máximo', () {
    test('de fábrica no cambia nada en un monitor normal', () {
      final g = calcular(
        esEscritorio: true,
        ancho: 1440,
        topeAncho: AnchoMiniplayer.auto.tope,
      );
      expect(g.conTope, isFalse);
      expect(g.anchoBarra, g.anchoUtil);
    });

    test('auto acota recién en una pantalla enorme', () {
      // En 1920 la barra cruzaría la tele entera de lado a lado.
      final g = calcular(
        esTv: true,
        ancho: 1920,
        baseMargen: _baseMargenTv,
        topeAncho: AnchoMiniplayer.auto.tope,
      );
      expect(g.conTope, isTrue, reason: 'va centrada');
      expect(g.anchoBarra, AnchoMiniplayer.auto.tope);
      expect(g.anchoBarra, lessThan(g.anchoUtil));
    });

    test('justo en el tope no acota: es un máximo, no un objetivo', () {
      final g = calcular(
        esEscritorio: true,
        ancho: 1600,
        baseMargen: _baseMargenPc,
        topeAncho: AnchoMiniplayer.auto.tope,
      );
      expect(g.conTope, isFalse);
    });

    test('contenido acota también en una pantalla mediana', () {
      final g = calcular(
        esEscritorio: true,
        ancho: 1366,
        topeAncho: AnchoMiniplayer.contenido.tope,
      );
      expect(g.anchoBarra, AnchoMiniplayer.contenido.tope);
      expect(g.conTope, isTrue);
    });

    test('completo nunca acota', () {
      final g = calcular(
        esTv: true,
        ancho: 3840,
        baseMargen: _baseMargenTv,
        topeAncho: AnchoMiniplayer.completo.tope,
      );
      expect(g.conTope, isFalse);
      expect(g.anchoBarra, 3840 - _baseMargenTv * 2);
    });

    test('el relleno interno se mide contra la BARRA, no la pantalla', () {
      // El 4% de 3840 son 153 px: dentro de una barra de 1600 se comía el
      // contenido. Se acota al 8% de la barra = 128.
      final g = calcular(
        esTv: true,
        ancho: 3840,
        baseMargen: _baseMargenTv,
        topeAncho: AnchoMiniplayer.auto.tope,
      );
      expect(g.anchoBarra, AnchoMiniplayer.auto.tope);
      expect(g.paddingInterno, closeTo(128, 0.001));
      expect(g.paddingInterno, lessThan(3840 * 0.04));
    });

    test('de fábrica el relleno interno es el de siempre', () {
      // 4% de 390 = 15.6, y el 8% de la barra (31.2) no molesta.
      expect(calcular().paddingInterno, closeTo(390 * 0.04, 0.001));
    });
  });

  group('persistencia de los presets', () {
    test('el JSON guarda y devuelve el preset', () {
      const p = PreferenciasApariencia(
        tamanoMiniplayer: TamanoMiniplayer.grande,
        formaMiniplayer: FormaMiniplayer.pegado,
        anchoMiniplayer: AnchoMiniplayer.contenido,
      );
      final ida = PreferenciasApariencia.desdeJsonString(p.toJsonString());
      expect(ida.tamanoMiniplayer, TamanoMiniplayer.grande);
      expect(ida.formaMiniplayer, FormaMiniplayer.pegado);
      expect(ida.anchoMiniplayer, AnchoMiniplayer.contenido);
      expect(ida.esDeFabrica, isFalse);
    });

    test('una clave desconocida no rompe: queda el de fábrica', () {
      // Es lo que va a pasar si algún día se renombra un preset.
      const p = PreferenciasApariencia();
      final json = p.aJson()
        ..['tamanoMiniplayer'] = 'gigante'
        ..['formaMiniplayer'] = 42
        ..['anchoMiniplayer'] = const [];
      final ida = PreferenciasApariencia.desdeJson(json);
      expect(ida.tamanoMiniplayer, TamanoMiniplayer.normal);
      expect(ida.formaMiniplayer, FormaMiniplayer.auto);
      expect(ida.anchoMiniplayer, AnchoMiniplayer.auto);
      expect(ida.esDeFabrica, isTrue);
    });
  });
}
