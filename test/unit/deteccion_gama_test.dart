// deteccion_gama_test.dart — La gama del equipo (que decide si la app usa
// desenfoques y cuántas descargas simultáneas permite) tiene que caer en
// "baja" en un celular tipo Helio G, que es donde la app se congelaba.
//
// Se conecta con: lib/core/plataforma/sistema/deteccion_gama.dart.
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/core/modelos/usuario/perfil_rendimiento.dart';
import 'package:bitly/core/plataforma/sistema/deteccion_gama.dart';

void main() {
  group('gamaSegunCapacidad (móvil)', () {
    test('4 núcleos es gama baja aunque tenga RAM de sobra', () {
      expect(
        gamaSegunCapacidad(nucleos: 4, ramMb: 6144, esMovil: true),
        NivelRendimiento.bajo,
      );
    });

    test('8 núcleos con 2 GB es gama baja (Helio G de entrada)', () {
      expect(
        gamaSegunCapacidad(nucleos: 8, ramMb: 2048, esMovil: true),
        NivelRendimiento.bajo,
      );
    });

    test('8 núcleos con 3 GB sigue siendo gama baja', () {
      expect(
        gamaSegunCapacidad(nucleos: 8, ramMb: 3072, esMovil: true),
        NivelRendimiento.bajo,
      );
    });

    test('8 núcleos con 4 GB es gama media', () {
      expect(
        gamaSegunCapacidad(nucleos: 8, ramMb: 4096, esMovil: true),
        NivelRendimiento.medio,
      );
    });

    test('6 núcleos es gama media', () {
      expect(
        gamaSegunCapacidad(nucleos: 6, ramMb: 8192, esMovil: true),
        NivelRendimiento.medio,
      );
    });

    test('8 núcleos con 8+ GB es gama alta', () {
      expect(
        gamaSegunCapacidad(nucleos: 8, ramMb: 8192, esMovil: true),
        NivelRendimiento.alto,
      );
    });

    test('sin dato de RAM decide por núcleos', () {
      expect(
        gamaSegunCapacidad(nucleos: 8, ramMb: 0, esMovil: true),
        NivelRendimiento.alto,
      );
    });
  });

  group('gamaSegunCapacidad (escritorio)', () {
    test('se mantiene en media para no cambiar lo que ya funcionaba', () {
      expect(
        gamaSegunCapacidad(nucleos: 4, ramMb: 8192, esMovil: false),
        NivelRendimiento.medio,
      );
      expect(
        gamaSegunCapacidad(nucleos: 32, ramMb: 65536, esMovil: false),
        NivelRendimiento.medio,
      );
    });
  });

  group('perfil resultante', () {
    test('la gama baja apaga los efectos pesados y precarga', () {
      final perfil = PerfilRendimiento.bajo;
      expect(perfil.efectosPesados, isFalse);
      expect(perfil.sigmaDesenfoque, 0,
          reason: 'sin desenfoque: es lo que congela la GPU de gama baja');
      expect(perfil.precargaHabilitada, isFalse);
      expect(perfil.concurrenciaDescargas, 1);
    });

    test('la gama media usa un desenfoque barato en móvil', () {
      expect(PerfilRendimiento.medio.sigmaDesenfoque, lessThanOrEqualTo(12));
    });

    test('la gama alta conserva los efectos completos', () {
      expect(PerfilRendimiento.alto.efectosPesados, isTrue);
      expect(PerfilRendimiento.alto.sigmaDesenfoque, greaterThan(12));
    });
  });
}
