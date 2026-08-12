import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/backend/services/oauth_callback_service.dart';

void main() {
  group('oauthCallbackFromUrl', () {
    test('parses code + state from spotiflac://callback', () {
      final r = oauthCallbackFromUrl(
          'spotiflac://callback?code=AQB123XYZ&state=pkce_state_1');
      expect(r, isNotNull);
      expect(r!.code, 'AQB123XYZ');
      expect(r.state, 'pkce_state_1');
      expect(r.error, isEmpty);
      expect(r.ok, isTrue);
      expect(r.isError, isFalse);
    });

    test('parses error + state (user denied)', () {
      final r = oauthCallbackFromUrl(
          'spotiflac://callback?error=access_denied&state=pkce_state_1');
      expect(r, isNotNull);
      expect(r!.error, 'access_denied');
      expect(r.state, 'pkce_state_1');
      expect(r.code, isEmpty);
      expect(r.ok, isFalse);
      expect(r.isError, isTrue);
    });

    test('accepts any scheme as long as host is callback', () {
      final r = oauthCallbackFromUrl(
          'bitly://callback?code=XYZ&state=s');
      expect(r, isNotNull);
      expect(r!.code, 'XYZ');
    });

    test('null for session-grant URLs (host mismatch)', () {
      expect(
        oauthCallbackFromUrl('spotiflac://session-grant?grant=gr_abc'),
        isNull,
      );
    });

    test('null for non-callback hosts', () {
      expect(
        oauthCallbackFromUrl(
            'https://accounts.spotify.com/authorize?client_id=x'),
        isNull,
      );
    });

    test('null when neither code nor error present', () {
      expect(oauthCallbackFromUrl('spotiflac://callback?state=abc'), isNull);
    });

    test('null on invalid URL', () {
      expect(oauthCallbackFromUrl('not a url'), isNull);
    });
  });

  group('OAuthResult', () {
    test('matchesState validates the PKCE state', () {
      const r = OAuthResult(code: 'code', state: 's1');
      expect(r.matchesState('s1'), isTrue);
      expect(r.matchesState('other'), isFalse);
      expect(r.matchesState(null), isTrue);
    });
  });
}
