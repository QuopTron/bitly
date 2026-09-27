// pool_qobuz_estado_test.dart — Fija la traducción del informe del pool de
// Qobuz (la acción `estadoPool` del backend) a un estado que la UI pueda
// pintar, y la validación de la URL del pool.
//
// Por qué existe: la tarjeta de Ajustes muestra "fuente caída" y "sin tokens"
// como cosas distintas (son arreglos distintos). Si la traducción se rompe, el
// usuario vuelve a ver un error genérico —o peor, un "todo bien"— cuando el
// pool quedó vacío. Los estados tienen que espejar los de Go
// (sessionpool/qobuz_diagnostico.go).
//
// Se conecta con: core/modelos/ajustes_pool_qobuz.dart.
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/core/modelos/ajustes_pool_qobuz.dart';

void main() {
  group('estadoDeRespuesta', () {
    test('lee el estado que manda el backend', () {
      expect(
        AjustesPoolQobuz.estadoDeRespuesta({
          'ok': true,
          'result': {'estado': 'ok'},
        }),
        AjustesPoolQobuz.estadoOk,
      );
      expect(
        AjustesPoolQobuz.estadoDeRespuesta({
          'ok': true,
          'result': {'estado': 'fuente_caida'},
        }),
        AjustesPoolQobuz.estadoFuenteCaida,
      );
      expect(
        AjustesPoolQobuz.estadoDeRespuesta({
          'ok': true,
          'result': {'estado': 'sin_tokens'},
        }),
        AjustesPoolQobuz.estadoSinTokens,
      );
      expect(
        AjustesPoolQobuz.estadoDeRespuesta({
          'ok': true,
          'result': {'estado': 'sin_fuentes'},
        }),
        AjustesPoolQobuz.estadoSinFuentes,
      );
    });

    test('una respuesta fallida o rota NUNCA se pinta como ok', () {
      expect(
        AjustesPoolQobuz.estadoDeRespuesta({'ok': false, 'error': 'x'}),
        AjustesPoolQobuz.estadoError,
      );
      expect(AjustesPoolQobuz.estadoDeRespuesta(null), AjustesPoolQobuz.estadoError);
      expect(
        AjustesPoolQobuz.estadoDeRespuesta({'ok': true, 'result': 'texto'}),
        AjustesPoolQobuz.estadoError,
      );
      // Un estado que el backend no define (una versión futura) tampoco
      // enciende verde a ciegas.
      expect(
        AjustesPoolQobuz.estadoDeRespuesta({
          'ok': true,
          'result': {'estado': 'inventado'},
        }),
        AjustesPoolQobuz.estadoError,
      );
    });

    test('los estados válidos son exactamente los de Go', () {
      expect(AjustesPoolQobuz.estadosValidos, {
        'ok',
        'fuente_caida',
        'sin_tokens',
        'sin_fuentes',
      });
    });
  });

  group('detalleDeRespuesta', () {
    test('devuelve el detalle del backend cuando vino', () {
      expect(
        AjustesPoolQobuz.detalleDeRespuesta({
          'ok': true,
          'result': {'estado': 'ok', 'detalle': 'hay credenciales vivas'},
        }),
        'hay credenciales vivas',
      );
    });

    test('devuelve vacío si no hay detalle usable', () {
      expect(AjustesPoolQobuz.detalleDeRespuesta(null), '');
      expect(
        AjustesPoolQobuz.detalleDeRespuesta({'ok': true, 'result': {'estado': 'ok'}}),
        '',
      );
    });
  });

  group('urlValida', () {
    test('acepta http(s) con host', () {
      expect(
        AjustesPoolQobuz.urlValida('https://mi-worker.workers.dev/pool/abc'),
        isTrue,
      );
      expect(AjustesPoolQobuz.urlValida('http://127.0.0.1:8080/pool'), isTrue);
    });

    test('rechaza una URL a medio pegar', () {
      expect(AjustesPoolQobuz.urlValida(''), isFalse);
      expect(AjustesPoolQobuz.urlValida('mi-worker.workers.dev'), isFalse);
      expect(AjustesPoolQobuz.urlValida('ftp://x.com/pool'), isFalse);
    });

    test('normaliza los espacios', () {
      expect(
        AjustesPoolQobuz.normalizarUrl('  https://x.com/pool  '),
        'https://x.com/pool',
      );
    });
  });
}
