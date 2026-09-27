// cover_dominante_test.dart — Fija el tinte de las cards por el color que de
// VERDAD domina en la carátula y, sobre todo, los dos casos que antes salían
// mal: covers SIN tono (blanco puro, negro puro, gris) y las letras que van
// encima.
//
// Lo que se protege:
//  1. Detección: si el arte tiene una mancha de color, el tinte es ESA; si no
//     tiene tono (blanco/negro puro) no se le inventa uno —ni sale rojo, que era
//     el bug del "hue" de un gris— y se usa el dominante neutro.
//  2. Cards: un cover blanco aclara la card y uno negro la deja oscura
//     (`respetarClaridad`), en vez de terminar los dos en el mismo gris medio.
//  3. Fondos: el mismo cover blanco NO puede blanquear la Home (ahí las letras
//     son las del tema), así que los fondos no piden esa fidelidad.
//  4. Letras: se deciden contra la base REAL de la card (el velo oscuro, que
//     existe en los dos temas). Con la superficie del tema, en tema claro el
//     cálculo daba un fondo claro que no existe y el texto pasaba a negro sobre
//     ese velo.
//  5. El neutro más legible se elige comparando los DOS contrastes reales: el
//     cruce blanco/negro está en una luminancia de ~0.18, no en 0.5.

import 'package:bitly/shared/tema/colores_app.dart';
import 'package:bitly/shared/utilidades/formato/comun/formato/estilo_helper.dart';
import 'package:bitly/shared/utilidades/portada/paleta/paleta_portada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Una paleta con la mancha de color y el dominante que se quieran probar.
PaletaPortada paleta({Color? mancha, required Color dominante}) =>
    PaletaPortada(
      vibrante: dominante,
      dominante: dominante,
      dominanteConTono: mancha,
      luminanciaDominante: luminanciaRelativa(dominante),
      esPortadaClara: luminanciaRelativa(dominante) > 0.5,
    );

void main() {
  const blanco = Color(0xFFFFFFFF);
  const negro = Color(0xFF000000);
  const gris = Color(0xFF5A5A5A);
  const azul = Color(0xFF1E2F52);
  const fondoOscuro = Color(0xFF121212);
  const fondoLuz = Color(0xFFF5F5F5);
  const portadas = [blanco, negro, gris, azul, Color(0xFFB04652)];

  group('detección del color dominante', () {
    test('si hay mancha de color, el tinte es ESA mancha', () {
      // El arte puede ser 80% blanco y aun así mandar el azul del logo: el
      // promedio sucio (gris) no es lo que se ve en la portada.
      final p = paleta(mancha: azul, dominante: gris);
      expect(p.acentoTinte, azul);
    });

    test('sin tono (blanco o negro puro) NO se inventa un color', () {
      for (final neutro in [blanco, negro, gris]) {
        final p = paleta(mancha: null, dominante: neutro);
        expect(
          p.acentoTinte,
          neutro,
          reason: 'un cover sin color se tiñe con su propio neutro',
        );
        final r = p.acentoTinte.r, g = p.acentoTinte.g, b = p.acentoTinte.b;
        expect(
          [r, g, b],
          everyElement(closeTo(r, 0.0001)),
          reason: 'no puede aparecer un tono que el arte no tiene',
        );
      }
    });
  });

  group('cards: el cover sin tono conserva su claridad', () {
    /// El tinte que pinta la card para un gris de claridad [luz] (0..1).
    Color tinte(double luz, Color fondo, {bool fiel = true}) {
      final v = (luz * 255).round();
      return EstiloHelper.colorDeCover(
        Color.fromARGB(255, v, v, v),
        fondo,
        respetarClaridad: fiel,
      );
    }

    test('un cover blanco aclara la card y uno negro la oscurece', () {
      for (final fondo in const [fondoOscuro, fondoLuz]) {
        final conBlanco = luminanciaRelativa(tinte(1.0, fondo));
        final conNegro = luminanciaRelativa(tinte(0.0, fondo));
        expect(
          conBlanco,
          greaterThan(conNegro),
          reason: 'blanco y negro no pueden quedar en el mismo gris',
        );
        expect(
          conNegro,
          lessThan(luminanciaRelativa(fondo) + 0.01),
          reason: 'el cover negro no puede ACLARAR la card',
        );
      }
      // Sobre el fondo oscuro del tema, el blanco además aclara de verdad.
      expect(
        luminanciaRelativa(tinte(1.0, fondoOscuro)),
        greaterThan(luminanciaRelativa(fondoOscuro)),
      );
    });

    test('la fidelidad separa los extremos (antes caían en el mismo gris)', () {
      final claro = tinte(1.0, fondoOscuro);
      final oscuro = tinte(0.0, fondoOscuro);
      expect(claro.r, greaterThan(0.5), reason: 'el blanco deja card clara');
      expect(oscuro.r, lessThan(0.2), reason: 'el negro deja card oscura');
      expect((claro.r - oscuro.r) * 255, greaterThan(80));
      // Y el gris intermedio casi ni se mueve (el tirón al medio es leve), así
      // que este cambio no toca los covers "normales".
      final medio = tinte(0.45, fondoOscuro);
      final medioConservador = tinte(0.45, fondoOscuro, fiel: false);
      expect((medio.r - medioConservador.r).abs() * 255, lessThan(3));
    });

    test('el tinte neutro queda sin tono (r = g = b)', () {
      for (final fondo in const [fondoOscuro, fondoLuz]) {
        final c = EstiloHelper.colorDeCover(
          blanco,
          fondo,
          respetarClaridad: true,
        );
        expect(c.r, closeTo(c.g, 0.0001));
        expect(c.g, closeTo(c.b, 0.0001));
      }
    });
  });

  group('fondos: el cover blanco no puede blanquear la pantalla', () {
    test('con la franja conservadora las letras del tema se leen', () {
      // Así pinta la Home (fondo_ambiente_velo y compañía): sin
      // `respetarClaridad`, porque sobre ese color van las letras del TEMA y un
      // cover blanco dejaría la pantalla clara con el tema oscuro.
      for (final acento in portadas) {
        final pintado = EstiloHelper.colorDeCover(
          acento,
          fondoOscuro,
          mezcla: 0.58,
        );
        expect(
          relacionContraste(Colors.white, pintado),
          greaterThanOrEqualTo(4.5),
          reason: 'con el cover $acento la Home quedaría ilegible',
        );
      }
    });

    test('la fidelidad de las cards SÍ movería la luminancia del fondo', () {
      // Deja claro por qué el flag es de las cards y no de los fondos: con el
      // cover blanco, la versión fiel deja el fondo por debajo de AA.
      final conservador = EstiloHelper.colorDeCover(
        blanco,
        fondoOscuro,
        mezcla: 0.58,
      );
      final fiel = EstiloHelper.colorDeCover(
        blanco,
        fondoOscuro,
        mezcla: 0.58,
        respetarClaridad: true,
      );
      expect(
        luminanciaRelativa(fiel),
        greaterThan(luminanciaRelativa(conservador)),
      );
      expect(relacionContraste(Colors.white, fiel), lessThan(4.5));
    });
  });

  group('letras de las cards', () {
    test('en los dos temas la base del velo deja el texto de fábrica', () {
      // La regresión que esto evita: en tema claro la superficie del tema es
      // blanca, el cálculo daba un fondo claro inexistente y el texto pasaba a
      // negro sobre el velo oscuro de la card.
      for (final esOscuro in const [true, false]) {
        final fg = EstiloHelper.textoDeTinte(
          null,
          ColoresApp.baseBajoCover(esOscuro),
          0,
          fgTema: Colors.white,
        );
        expect(fg, Colors.white, reason: 'oscuro=$esOscuro');
      }
    });

    test('la base del velo es oscura en los dos temas', () {
      for (final esOscuro in const [true, false]) {
        final base = ColoresApp.baseBajoCover(esOscuro);
        expect(
          relacionContraste(Colors.white, base),
          greaterThanOrEqualTo(4.5),
          reason: 'oscuro=$esOscuro',
        );
      }
    });

    test('cover blanco al 100% en tema CLARO → letras oscuras', () {
      // Es el caso donde la card queda clara de verdad: el velo de la card es
      // suave en tema claro, así que el tinte blanco se impone y el texto
      // blanco de fábrica desaparecía.
      final fg = EstiloHelper.textoDeTinte(
        blanco,
        ColoresApp.baseBajoCover(false),
        1,
        fgTema: Colors.white,
      );
      expect(luminanciaRelativa(fg), lessThan(0.5));
    });

    test('cover blanco en tema OSCURO → las letras siguen blancas', () {
      // El velo y el degradado de la card son más fuertes que el tinte: la
      // zona del título termina oscura igual, así que forzar negro acá sería
      // cambiar un problema por el opuesto.
      final fg = EstiloHelper.textoDeTinte(
        blanco,
        ColoresApp.baseBajoCover(true),
        1,
        fgTema: Colors.white,
      );
      expect(fg, Colors.white);
    });

    test('cover negro → letras blancas en los dos temas', () {
      for (final esOscuro in const [true, false]) {
        final fg = EstiloHelper.textoDeTinte(
          negro,
          ColoresApp.baseBajoCover(esOscuro),
          1,
          fgTema: Colors.white,
        );
        expect(fg, Colors.white, reason: 'oscuro=$esOscuro');
      }
    });

    test('a cualquier nivel y con cualquier portada, las letras se leen', () {
      for (final acento in portadas) {
        for (final esOscuro in const [true, false]) {
          final base = ColoresApp.baseBajoCover(esOscuro);
          for (var i = 0; i <= 10; i++) {
            final nivel = i / 10;
            final fg = EstiloHelper.textoDeTinte(
              acento,
              base,
              nivel,
              fgTema: Colors.white,
            );
            final fondo = EstiloHelper.fondoPintado(acento, base, nivel);
            expect(
              relacionContraste(fg, fondo),
              greaterThanOrEqualTo(4.5),
              reason:
                  'cover $acento al ${i * 10}% sobre $base (oscuro=$esOscuro)',
            );
          }
        }
      }
    });
  });

  group('fondos a pantalla completa: el fondo se acomoda a las letras', () {
    // Los que rompían: portadas CLARAS y saturadas al 100% en tema oscuro. Ahí
    // las letras son las del tema (blancas) y no se pueden recolorear una por
    // una, así que el que tiene que ceder es el fondo.
    const brillantes = [
      Color(0xFF7CFF7C),
      Color(0xFF80FFFF),
      Color(0xFFFFF080),
    ];

    test('con cualquier portada y cualquier letra, se lee', () {
      for (final acento in [...portadas, ...brillantes]) {
        for (final texto in const [Colors.white, Colors.black]) {
          for (final fondo in const [fondoOscuro, fondoLuz]) {
            final pintado = EstiloHelper.fondoDeCover(acento, fondo, texto);
            expect(
              relacionContraste(texto, pintado),
              greaterThanOrEqualTo(4.5),
              reason: 'portada $acento, letra $texto sobre $fondo',
            );
          }
        }
      }
    });

    test('la portada clara y saturada (el caso roto) se oscurece lo justo', () {
      const verdeClaro = Color(0xFF7CFF7C);
      final crudo = EstiloHelper.colorDeCover(
        verdeClaro,
        fondoOscuro,
        mezcla: 0.60,
      );
      expect(
        relacionContraste(Colors.white, crudo),
        lessThan(4.5),
        reason: 'este es el fondo que dejaba el texto blanco al borde',
      );

      final pintado = EstiloHelper.fondoDeCover(
        verdeClaro,
        fondoOscuro,
        Colors.white,
        mezcla: 0.60,
      );
      expect(
        relacionContraste(Colors.white, pintado),
        greaterThanOrEqualTo(4.5),
      );
      expect(pintado, isNot(Colors.black), reason: 'no se va a negro');
      expect(
        luminanciaRelativa(pintado),
        lessThan(luminanciaRelativa(crudo)),
        reason: 'se oscurece, que es la dirección de la letra blanca',
      );
    });

    test('si ya se leía, el color del cover no se toca', () {
      for (final acento in const [azul, Color(0xFF3C2228)]) {
        expect(
          EstiloHelper.fondoDeCover(acento, fondoOscuro, Colors.white),
          EstiloHelper.colorDeCover(acento, fondoOscuro),
          reason: 'no se pierde el color del cover cuando no hace falta',
        );
      }
    });
  });

  group('el neutro más legible', () {
    test('se elige comparando los dos contrastes reales', () {
      for (var v = 0; v <= 255; v += 5) {
        final fondo = Color.fromARGB(255, v, v, v);
        final elegido = mejorNeutro(fondo);
        final otro = elegido == Colors.white ? Colors.black : Colors.white;
        expect(
          relacionContraste(elegido, fondo),
          greaterThanOrEqualTo(relacionContraste(otro, fondo)),
          reason: 'con el gris $v se eligió el neutro que contrasta menos',
        );
      }
    });

    test('un gris medio claro pide NEGRO (antes devolvía blanco)', () {
      // Luminancia ~0.30: el blanco daba 3:1 y el negro 6.9:1, pero el umbral
      // viejo (0.5) miraba la escala perceptual y elegía blanco.
      const grisMedioClaro = Color(0xFF949494);
      expect(luminanciaRelativa(grisMedioClaro), lessThan(0.5));
      expect(mejorNeutro(grisMedioClaro), Colors.black);
    });
  });
}
