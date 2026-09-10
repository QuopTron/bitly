import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/core/servicios/resultado_oauth.dart';

void main() {
  group('resultadoOauthDesdeUrl', () {
    test('parses code + state from spotiflac://callback', () {
      final r = resultadoOauthDesdeUrl(
          'spotiflac://callback?code=AQB123XYZ&state=pkce_state_1');
      expect(r, isNotNull);
      expect(r!.code, 'AQB123XYZ');
      expect(r.state, 'pkce_state_1');
      expect(r.error, isEmpty);
      expect(r.ok, isTrue);
      expect(r.esError, isFalse);
    });

    test('parses error + state (user denied)', () {
      final r = resultadoOauthDesdeUrl(
          'spotiflac://callback?error=access_denied&state=pkce_state_1');
      expect(r, isNotNull);
      expect(r!.error, 'access_denied');
      expect(r.state, 'pkce_state_1');
      expect(r.code, isEmpty);
      expect(r.ok, isFalse);
      expect(r.esError, isTrue);
    });

    test('accepts any scheme as long as host is callback', () {
      final r = resultadoOauthDesdeUrl(
          'bitly://callback?code=XYZ&state=s');
      expect(r, isNotNull);
      expect(r!.code, 'XYZ');
    });

    test('null for session-grant URLs (host mismatch)', () {
      expect(
        resultadoOauthDesdeUrl('spotiflac://session-grant?grant=gr_abc'),
        isNull,
      );
    });

    test('null for non-callback hosts', () {
      expect(
        resultadoOauthDesdeUrl(
            'https://accounts.spotify.com/authorize?client_id=x'),
        isNull,
      );
    });

    test('null when neither code nor error present', () {
      expect(resultadoOauthDesdeUrl('spotiflac://callback?state=abc'), isNull);
    });

    test('null on invalid URL', () {
      expect(resultadoOauthDesdeUrl('not a url'), isNull);
    });
  });

  group('ResultadoOAuth', () {
    test('matchesState validates the PKCE state', () {
      const r = ResultadoOAuth(code: 'code', state: 's1');
      expect(r.coincideConState('s1'), isTrue);
      expect(r.coincideConState('other'), isFalse);
      expect(r.coincideConState(null), isTrue);
    });
  });
}