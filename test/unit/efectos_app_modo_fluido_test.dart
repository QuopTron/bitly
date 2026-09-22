// ─────────────────────────────────────────────────────────────
// efectos_app_modo_fluido_test.dart — Fija la promesa del "modo fluido":
// que apague el trabajo de GPU por frame (desenfoques, sombras, pulsos y las
// fotos a pantalla completa) SIN llevarse el color por tarjeta, que es parte
// del diseño que la persona eligió.
//
// Por qué importa: el modo fluido se agregó después de haber "optimizado"
// borrando capas del diseño, así que acá queda escrito qué apaga y qué no.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/shared/utilidades/plataforma/pantalla/efectos_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(EfectosApp.reiniciar);
  tearDown(EfectosApp.reiniciar);

  test('de fábrica no hay nada limitado', () {
    expect(EfectosApp.desenfoqueActivo, isTrue);
    expect(EfectosApp.fotoPantallaCompletaActiva, isTrue);
    expect(EfectosApp.colorPorTarjetaActivo, isTrue);
  });

  test('el modo fluido apaga blur, pulsos y fotos a pantalla completa', () {
    EfectosApp.aplicarModoFluido(true);

    expect(EfectosApp.desenfoqueActivo, isFalse);
    expect(EfectosApp.fotoPantallaCompletaActiva, isFalse);
  });

  test('el modo fluido NO se lleva el color por tarjeta (es diseño)', () {
    EfectosApp.aplicarModoFluido(true);

    expect(
      EfectosApp.colorPorTarjetaActivo,
      isTrue,
      reason: 'el tinte por tarjeta es parte del diseño y su coste está '
          'amortizado: se extrae una vez por cover, no en cada frame',
    );
  });

  test('se revierte por completo al apagarlo', () {
    EfectosApp.aplicarModoFluido(true);
    EfectosApp.aplicarModoFluido(false);

    expect(EfectosApp.desenfoqueActivo, isTrue);
    expect(EfectosApp.fotoPantallaCompletaActiva, isTrue);
  });

  test('no depende del perfil: gana sobre "hay margen"', () {
    // El perfil detectado dice que sí hay efectos pesados…
    EfectosApp.aplicar(efectosPesados: true, sigmaMax: 26);
    expect(EfectosApp.desenfoqueActivo, isTrue);

    // …pero la elección explícita del usuario manda.
    EfectosApp.aplicarModoFluido(true);
    expect(EfectosApp.desenfoqueActivo, isFalse);
    expect(EfectosApp.sigmaMaximo.value, 26, reason: 'el perfil no se toca');
  });

  test('cambiosEfectos avisa para que las animaciones se detengan', () {
    var avisos = 0;
    void escucha() => avisos++;
    EfectosApp.cambiosEfectos.addListener(escucha);
    addTearDown(() => EfectosApp.cambiosEfectos.removeListener(escucha));

    EfectosApp.aplicarModoFluido(true);
    expect(avisos, 1, reason: 'un aviso basta para detener las animaciones');

    // Repetir el mismo valor no genera trabajo extra.
    EfectosApp.aplicarModoFluido(true);
    expect(avisos, 1);
  });
}
