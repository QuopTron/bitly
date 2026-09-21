// Test del contrato de estado que alimenta los avisos de descarga: el aviso
// de fallo definitivo, su limpieza y el contador de reintento en sitio. La UI
// (avisos_descarga / tarjeta de track) depende de estos campos, así que un
// cambio silencioso acá dejaría al usuario sin explicación otra vez.

import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/core/cache/estado/estado_descarga.dart';
import 'package:bitly/core/servicios/descargas/plan/motivos_descarga.dart';

void main() {
  group('DatosEstadoDescarga', () {
    test('por defecto no es un reintento', () {
      const d = DatosEstadoDescarga();
      expect(d.intento, 0);
      expect(d.totalIntentos, 0);
      expect(d.esReintento, isFalse);
    });

    test('guarda el CÓDIGO del motivo y el intento en curso', () {
      // El estado nunca guarda el texto crudo del backend: guarda el código
      // que la UI traduce, así el aviso sigue el idioma activo.
      const d = DatosEstadoDescarga(
        estado: EstadoDescarga.interrumpido,
        mensajeError: MotivosDescarga.espacio,
        intento: 2,
        totalIntentos: 3,
      );
      expect(d.esReintento, isTrue);
      expect(d.mensajeError, MotivosDescarga.espacio);
      expect(d.mensajeError, isNot(contains(' ')));
    });
  });

  group('EstadoCubitDescargas.falloDescarga', () {
    const fallo = FalloDescarga(
      baseId: 'track_abc_ytmusic-spotiflac',
      titulo: 'Blinding Lights',
      motivo: MotivosDescarga.sinArchivo,
    );

    test('copiarCon publica el aviso de fallo', () {
      const base = EstadoCubitDescargas();
      final conFallo = base.copiarCon(falloDescarga: fallo);

      expect(conFallo.falloDescarga?.titulo, 'Blinding Lights');
      expect(conFallo.falloDescarga?.baseId, 'track_abc_ytmusic-spotiflac');
      // Distinto estado (props) = la UI se reconstruye con el aviso.
      expect(conFallo, isNot(equals(base)));
    });

    test('limpiarFalloDescarga lo quita y no pisa otros campos', () {
      final conFallo = const EstadoCubitDescargas(
        carpetaPerdida: true,
      ).copiarCon(falloDescarga: fallo);
      final limpio = conFallo.copiarCon(limpiarFalloDescarga: true);

      expect(limpio.falloDescarga, isNull);
      expect(limpio.carpetaPerdida, isTrue);
    });

    test('un aviso no se publica dos veces igual (props estables)', () {
      const base = EstadoCubitDescargas();
      expect(base.copiarCon(), equals(base));
    });
  });
}
