// Test del protocolo del vínculo entre aparatos: el token que ya existía y el
// código de la invitación por QR que se sumó ahora.
//
// Lo que importa acá es la decisión: un código solo vale mientras la invitación
// está viva y solo si es exactamente el que se ve en pantalla. Cualquier otra
// cosa (vacío, otro código, el mismo pero vencido) se rechaza, que es lo que
// evita que alguien se vincule sin haber estado frente al aparato.

import 'package:bitly/core/servicios/lan/modelos/lan_protocolo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('token del vínculo', () {
    test('el mismo token entra', () {
      expect(tokenValido('abc123', 'abc123'), isTrue);
    });

    test('sin token esperado no entra nadie (aparato sin vincular)', () {
      expect(tokenValido('abc123', ''), isFalse);
      expect(tokenValido(null, ''), isFalse);
    });

    test('otro token, más corto o más largo, no entra', () {
      expect(tokenValido('abc124', 'abc123'), isFalse);
      expect(tokenValido('abc12', 'abc123'), isFalse);
      expect(tokenValido('abc1234', 'abc123'), isFalse);
      expect(tokenValido(null, 'abc123'), isFalse);
    });
  });

  group('código de la invitación por QR', () {
    test('el código que se ve en pantalla vincula sin preguntar', () {
      expect(
        codigoDeInvitacionValido('482913', '482913', vigente: true),
        isTrue,
      );
    });

    test('vencido no vale, aunque sea el mismo código', () {
      expect(
        codigoDeInvitacionValido('482913', '482913', vigente: false),
        isFalse,
      );
    });

    test('otro código no vale', () {
      expect(
        codigoDeInvitacionValido('482914', '482913', vigente: true),
        isFalse,
      );
      expect(codigoDeInvitacionValido('', '482913', vigente: true), isFalse);
      expect(codigoDeInvitacionValido(null, '482913', vigente: true), isFalse);
    });

    test('sin invitación abierta (código vacío) no entra nadie', () {
      expect(codigoDeInvitacionValido('482913', '', vigente: true), isFalse);
      expect(
        codigoDeInvitacionValido('', '', vigente: true),
        isFalse,
      );
    });
  });
}
