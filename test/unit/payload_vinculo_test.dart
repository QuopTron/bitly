// Test del QR del vínculo entre aparatos: lo que viaja adentro tiene que
// volver igual, y todo lo que no sirve (otro formato, otra versión, vencido,
// a medias o basura) tiene que rechazarse en vez de armar un vínculo raro.
//
// El código de 6 dígitos también se prueba: es lo que el dueño escribe cuando
// el aparato que lee no tiene cámara, así que tiene que ser siempre de 6.

import 'dart:convert';

import 'package:bitly/core/modelos/usuario/dispositivos/dispositivo_conectado.dart';
import 'package:bitly/core/servicios/conexion/qr/payload_vinculo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ahora = 1700000000000;

  PayloadVinculo invitar({int expira = ahora + 60000}) => PayloadVinculo(
    id: 'dev_celu',
    nombre: 'Celu de Pablo',
    tipo: TipoDispositivo.celu,
    direcciones: const ['192.168.0.5', '10.0.0.7'],
    puerto: 41234,
    codigo: '482913',
    expiraMs: expira,
  );

  /// Arma el texto del QR a mano, para probar formatos que la app no genera.
  String textoDe(Map<String, dynamic> json) =>
      esquemaVinculo + base64Url.encode(utf8.encode(jsonEncode(json)));

  group('ida y vuelta', () {
    test('lo que se dibuja en el QR vuelve igual', () {
      final leido = PayloadVinculo.leer(invitar().textoQr, ahoraMs: ahora);
      expect(leido, isNotNull);
      expect(leido!.id, 'dev_celu');
      expect(leido.nombre, 'Celu de Pablo');
      expect(leido.tipo, TipoDispositivo.celu);
      expect(leido.direcciones, ['192.168.0.5', '10.0.0.7']);
      expect(leido.puerto, 41234);
      expect(leido.codigo, '482913');
      expect(leido.expiraMs, ahora + 60000);
      expect(leido.utilizable, isTrue);
    });

    test('el texto del QR se reconoce por su prefijo', () {
      expect(invitar().textoQr.startsWith(esquemaVinculo), isTrue);
    });

    test('también se lee el contenido sin el prefijo', () {
      final crudo = invitar().textoQr.substring(esquemaVinculo.length);
      expect(PayloadVinculo.leer(crudo, ahoraMs: ahora)?.id, 'dev_celu');
    });
  });

  group('rechazos', () {
    test('un QR de otra cosa no arma un vínculo', () {
      expect(
        PayloadVinculo.leer('https://ejemplo.com/algo', ahoraMs: ahora),
        isNull,
      );
      expect(PayloadVinculo.leer('', ahoraMs: ahora), isNull);
      expect(PayloadVinculo.leer('no es base64!!', ahoraMs: ahora), isNull);
    });

    test('vencido no vale', () {
      final texto = invitar(expira: ahora - 1).textoQr;
      expect(PayloadVinculo.leer(texto, ahoraMs: ahora), isNull);
      expect(invitar().vigenteEn(ahora), isTrue);
    });

    test('otra versión del formato se ignora', () {
      final json = invitar().aJson()..['v'] = versionVinculo + 1;
      expect(PayloadVinculo.leer(textoDe(json), ahoraMs: ahora), isNull);
    });

    test('de otra app (mismo formato, otra firma) se ignora', () {
      final json = invitar().aJson()..['app'] = 'otra-cosa';
      expect(PayloadVinculo.leer(textoDe(json), ahoraMs: ahora), isNull);
    });

    test('sin IP no hay a dónde ir: se rechaza', () {
      final p = PayloadVinculo(
        id: 'dev',
        nombre: 'X',
        tipo: TipoDispositivo.pc,
        direcciones: const [],
        puerto: 4000,
        codigo: '111111',
        expiraMs: ahora + 1000,
      );
      expect(PayloadVinculo.leer(p.textoQr, ahoraMs: ahora), isNull);
      expect(p.utilizable, isFalse);
    });

    test('código que no tiene 6 dígitos: se rechaza', () {
      final json = invitar().aJson()..['codigo'] = '123';
      expect(PayloadVinculo.leer(textoDe(json), ahoraMs: ahora), isNull);
    });

    test('puerto imposible: se rechaza', () {
      final json = invitar().aJson()..['puerto'] = 70000;
      expect(PayloadVinculo.leer(textoDe(json), ahoraMs: ahora), isNull);
    });
  });

  group('código', () {
    test('siempre tiene 6 dígitos, con ceros adelante', () {
      for (var i = 0; i < 200; i++) {
        final codigo = codigoVinculoNuevo();
        expect(codigo.length, 6);
        expect(int.tryParse(codigo), isNotNull);
      }
    });

    test('cincuenta códigos seguidos no se repiten casi nunca', () {
      final codigos = {for (var i = 0; i < 50; i++) codigoVinculoNuevo()};
      expect(codigos.length, greaterThan(40));
    });
  });
}
