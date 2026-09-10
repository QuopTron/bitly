import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/core/servicios/servicio_verificacion.dart';

void main() {
  group('grantVerificacionDeUrl', () {
    test('extrae el grant de spotiflac://session-grant (esquema actual)', () {
      const url =
          'spotiflac://session-grant?cb_version=v2grant&grant=gr_gSNuUCDYjigdc4NdHRbF';
      expect(grantVerificacionDeUrl(url), 'gr_gSNuUCDYjigdc4NdHRbF');
    });

    test('extrae el grant de bitly://session-grant (esquema legacy)', () {
      const url = 'bitly://session-grant?grant=gr_abc123XYZ';
      expect(grantVerificacionDeUrl(url), 'gr_abc123XYZ');
    });

    test('funciona sin parametros extra', () {
      const url = 'spotiflac://session-grant?grant=gr_simple';
      expect(grantVerificacionDeUrl(url), 'gr_simple');
    });

    test('retorna null para URLs que no son session-grant', () {
      expect(
        grantVerificacionDeUrl(
          'https://challenges.cloudflare.com/cdn-cgi/challenge-platform/auto',
        ),
        isNull,
      );
      expect(grantVerificacionDeUrl('https://api.zarz.moe/v2/bootstrap'),
          isNull);
      expect(grantVerificacionDeUrl('spotiflac://other-route?grant=x'),
          isNull);
    });

    test('retorna null si falta el parametro grant', () {
      expect(grantVerificacionDeUrl('spotiflac://session-grant?cb_version=v2'),
          isNull);
      expect(grantVerificacionDeUrl('spotiflac://session-grant'), isNull);
    });

    test('retorna null para input invalido', () {
      expect(grantVerificacionDeUrl(''), isNull);
      expect(grantVerificacionDeUrl('not a url at all'), isNull);
      expect(grantVerificacionDeUrl('http://'), isNull);
    });
  });

  group('grantDeCadena (puente JS de la página del challenge)', () {
    test('URL completa de callback desktop (loopback)', () {
      expect(
        grantDeCadena(
          'http://127.0.0.1:62721/session-grant?cb_version=v2grant&grant=gr_loop',
        ),
        'gr_loop',
      );
    });

    test('URL con query malformada (? en vez de & cuando el cb ya traía query)',
        () {
      // La página concatena `?grant=` a un callback que ya tiene `?cb_version`:
      // el parseo estricto por Uri no ve el parámetro grant, el regex sí.
      expect(
        grantDeCadena(
          'http://127.0.0.1:62721/session-grant?cb_version=v2grant?grant=gr_mal',
        ),
        'gr_mal',
      );
      expect(
        grantDeCadena(
          'spotiflac://session-grant?cb_version=v2grant?grant=gr_mal2',
        ),
        'gr_mal2',
      );
    });

    test('token pelado (la página postea solo el código)', () {
      expect(grantDeCadena('gr_peladoABC'), 'gr_peladoABC');
      expect(grantDeCadena('gr_abc123XYZ'), 'gr_abc123XYZ');
    });

    test('parámetro code/token también se acepta', () {
      expect(grantDeCadena('http://127.0.0.1:1/session-grant?code=gr_code'),
          'gr_code');
      expect(grantDeCadena('https://x/session-grant?token=gr_tok'), 'gr_tok');
    });

    test('cadena con URL completa bien formada', () {
      expect(
        grantDeCadena('spotiflac://session-grant?cb_version=v2grant&grant=gr_x'),
        'gr_x',
      );
    });

    test('no confunde URLs ajenas ni cadenas vacías', () {
      expect(grantDeCadena(''), isNull);
      expect(grantDeCadena('https://api.zarz.moe/v2/challenge?id=chl_1'),
          isNull);
      expect(grantDeCadena('hola mundo con espacios'), isNull);
    });
  });
}