import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/backend/services/verification_service.dart';

void main() {
  group('verificationGrantFromUrl', () {
    test('extrae el grant de spotiflac://session-grant (esquema actual)', () {
      const url =
          'spotiflac://session-grant?cb_version=v2grant&grant=gr_gSNuUCDYjigdc4NdHRbF';
      expect(verificationGrantFromUrl(url), 'gr_gSNuUCDYjigdc4NdHRbF');
    });

    test('extrae el grant de bitly://session-grant (esquema legacy)', () {
      const url = 'bitly://session-grant?grant=gr_abc123XYZ';
      expect(verificationGrantFromUrl(url), 'gr_abc123XYZ');
    });

    test('funciona sin parametros extra', () {
      const url = 'spotiflac://session-grant?grant=gr_simple';
      expect(verificationGrantFromUrl(url), 'gr_simple');
    });

    test('retorna null para URLs que no son session-grant', () {
      expect(
        verificationGrantFromUrl(
          'https://challenges.cloudflare.com/cdn-cgi/challenge-platform/auto',
        ),
        isNull,
      );
      expect(verificationGrantFromUrl('https://api.zarz.moe/v2/bootstrap'),
          isNull);
      expect(verificationGrantFromUrl('spotiflac://other-route?grant=x'),
          isNull);
    });

    test('retorna null si falta el parametro grant', () {
      expect(verificationGrantFromUrl('spotiflac://session-grant?cb_version=v2'),
          isNull);
      expect(verificationGrantFromUrl('spotiflac://session-grant'), isNull);
    });

    test('retorna null para input invalido', () {
      expect(verificationGrantFromUrl(''), isNull);
      expect(verificationGrantFromUrl('not a url at all'), isNull);
      expect(verificationGrantFromUrl('http://'), isNull);
    });
  });
}
