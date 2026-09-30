// Test del modelo de ajustes del rescate: la traducción entre el switch de la
// UI y el texto que espera el backend de Go, y la validación de la instancia
// propia de cobalt (una URL mal pegada no puede encender el respaldo).

import 'package:bitly/core/modelos/ajustes_rescate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sitios raspables', () {
    test('sin valor guardado están encendidos (de fábrica)', () {
      expect(AjustesRescate.sitiosActivos(null), isTrue);
      expect(AjustesRescate.sitiosActivos(''), isTrue);
      expect(AjustesRescate.sitiosActivos('  '), isTrue);
    });

    test('reconoce todos los valores de apagado que entiende Go', () {
      for (final valor in AjustesRescate.apagados) {
        expect(
          AjustesRescate.sitiosActivos(valor),
          isFalse,
          reason: '$valor debe leerse como apagado',
        );
      }
      // Mayúsculas y espacios no cambian el significado.
      expect(AjustesRescate.sitiosActivos(' OFF '), isFalse);
    });

    test('el switch guarda el texto correcto', () {
      expect(AjustesRescate.valorSitios(false), 'off');
      // Encendido no guarda nada: el backend ya viene con los sitios de
      // fábrica, y un valor que no entiende los dejaría como estaban.
      expect(AjustesRescate.valorSitios(true), '');
    });
  });

  group('instancia de cobalt', () {
    test('recorta las barras finales', () {
      expect(
        AjustesRescate.normalizarInstancia(' https://mi.cobalt// '),
        'https://mi.cobalt',
      );
    });

    test('solo acepta http(s) con host', () {
      expect(AjustesRescate.instanciaValida('https://mi.cobalt'), isTrue);
      expect(AjustesRescate.instanciaValida('http://127.0.0.1:9000'), isTrue);
      expect(AjustesRescate.instanciaValida('https://mi.cobalt/'), isTrue);
      // Basura pegada a medias: no enciende el respaldo.
      expect(AjustesRescate.instanciaValida(''), isFalse);
      expect(AjustesRescate.instanciaValida('mi.cobalt'), isFalse);
      expect(AjustesRescate.instanciaValida('ftp://mi.cobalt'), isFalse);
      expect(AjustesRescate.instanciaValida('https://'), isFalse);
      expect(AjustesRescate.instanciaValida('   '), isFalse);
    });

    test('cobalt está activo solo con una instancia válida', () {
      expect(AjustesRescate.cobaltActivo(null), isFalse);
      expect(AjustesRescate.cobaltActivo(''), isFalse);
      expect(AjustesRescate.cobaltActivo('https://mi.cobalt'), isTrue);
    });

    test('el proxy acepta solo los esquemas que Go entiende', () {
      expect(AjustesRescate.proxyValido('http://127.0.0.1:8080'), isTrue);
      expect(AjustesRescate.proxyValido('https://proxy.mio:3128'), isTrue);
      expect(AjustesRescate.proxyValido('socks5://127.0.0.1:1080'), isTrue);
      expect(AjustesRescate.proxyValido('socks5h://u:p@proxy.mio:1080'), isTrue);

      expect(AjustesRescate.proxyValido(''), isFalse);
      expect(AjustesRescate.proxyValido('   '), isFalse);
      expect(AjustesRescate.proxyValido('127.0.0.1:8080'), isFalse);
      expect(AjustesRescate.proxyValido('ftp://proxy.mio:21'), isFalse);
      expect(AjustesRescate.proxyValido('http://'), isFalse);
    });

    test('el proxy se guarda sin espacios de sobra', () {
      expect(
        AjustesRescate.normalizarProxy('  socks5://127.0.0.1:1080  '),
        'socks5://127.0.0.1:1080',
      );
    });
  });

  group('espejos y arcod (canales muertos)', () {
    test('sin valor guardado están encendidos (de fábrica)', () {
      expect(AjustesRescate.espejosActivos(null), isTrue);
      expect(AjustesRescate.espejosActivos(''), isTrue);
      expect(AjustesRescate.arcodActivo(null), isTrue);
      expect(AjustesRescate.arcodActivo(''), isTrue);
    });

    test('reconocen los valores de apagado que entiende Go', () {
      for (final valor in AjustesRescate.apagados) {
        expect(AjustesRescate.espejosActivos(valor), isFalse);
        expect(AjustesRescate.arcodActivo(valor), isFalse);
      }
      expect(AjustesRescate.espejosActivos(' OFF '), isFalse);
      expect(AjustesRescate.arcodActivo(' OFF '), isFalse);
    });

    test('el switch guarda off al apagar y vacío al encender', () {
      expect(AjustesRescate.valorEspejos(false), 'off');
      expect(AjustesRescate.valorEspejos(true), '');
      expect(AjustesRescate.valorArcod(false), 'off');
      expect(AjustesRescate.valorArcod(true), '');
    });
  });

  group('informe de canales (probarCanales)', () {
    Map<String, dynamic> respuestaOk() => {
      'ok': true,
      'result': {
        'canales': [
          {'nombre': 'stash-relay', 'estado': 'ok', 'detalle': 'encendido'},
          {'nombre': 'espejos', 'estado': 'sin_cuentas', 'detalle': 'ARLs muertos'},
          {'nombre': 'sitios', 'estado': 123}, // inválido: se ignora
        ],
        'agotado': true,
        'detalle': 'ninguno sano',
      },
    };

    test('lee el informe y descarta las entradas inválidas', () {
      final canales = DiagnosticoCanalesRescate.canalesDeRespuesta(respuestaOk());
      expect(canales.length, 2);
      expect(canales[0].nombre, 'stash-relay');
      expect(canales[0].estado, DiagnosticoCanalesRescate.estadoOk);
      expect(canales[1].estado, DiagnosticoCanalesRescate.estadoSinCuentas);
      expect(DiagnosticoCanalesRescate.detalleDeRespuesta(respuestaOk()), 'ninguno sano');
      expect(DiagnosticoCanalesRescate.agotadoDeRespuesta(respuestaOk()), isTrue);
    });

    test('una respuesta rota no miente con un ok', () {
      expect(DiagnosticoCanalesRescate.canalesDeRespuesta(null), isEmpty);
      expect(DiagnosticoCanalesRescate.canalesDeRespuesta({'ok': false}), isEmpty);
      expect(DiagnosticoCanalesRescate.detalleDeRespuesta(null), '');
      expect(DiagnosticoCanalesRescate.agotadoDeRespuesta(null), isFalse);
    });
  });
}
