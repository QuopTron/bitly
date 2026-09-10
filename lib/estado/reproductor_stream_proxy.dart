// ─────────────────────────────────────────────────────────────
// reproductor_stream_proxy.dart — PART de cubit_reproductor.dart:
// proxy de streaming y headers de YouTube: arranque lazy del proxy
// Go (googlevideo se reproduce por chunks ≤1MB porque mpv pide el
// archivo entero y YouTube 403a IPs bot-gateadas), headers
// User-Agent/Origin/Referer por client y el probe de vida que
// distingue URLs gateadas (403 en el último byte) de sanas (206).
// ─────────────────────────────────────────────────────────────

part of 'cubit_reproductor.dart';

/// Proxy de stream y headers. Mixin aplicado en CubitReproductor.
mixin ReproductorStreamProxy on ReproductorStream {
  /// Arranca lazy el proxy Go (idempotente): URL base o null. RPC cacheado.
  Future<String?> _ensureStreamProxy() {
    if (_baseProxyStream != null) {
      return Future.value(_baseProxyStream);
    }
    return _futuroProxyStream ??= _startStreamProxy();
  }

  Future<String?> _startStreamProxy() async {
    try {
      final res = await di.sl<BackendService>().rpcCall(
        'startStreamingServer',
        {'port': 0},
        const Duration(seconds: 10),
      );
      final data = _decodeRpcResult(res);
      final base = (data?['url'] ?? '').toString();
      if (base.isNotEmpty && base.startsWith('http://')) {
        _baseProxyStream = base;
        return base;
      }
    } catch (_) {}
    return null;
  }

  /// Las googlevideo van por el proxy local de chunks; lo demás directo.
  Future<String> _localProxyUrl(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return url;
    }
    try {
      final host = Uri.parse(url).host.toLowerCase();
      if (!host.endsWith('googlevideo.com')) return url;
    } catch (_) {
      return url;
    }
    final base = await _ensureStreamProxy();
    if (base == null || base.isEmpty) return url;
    return '$base/stream?url=${Uri.encodeComponent(url)}';
  }

  /// Headers HTTP para mpv: las URLs googlevideo llevan un `c` (client);
  /// YouTube 403a User-Agents que no coinciden, y web/TV requieren
  /// Origin/Referer.
  Map<String, String>? _headersParaUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      final esYoutube = host.endsWith('googlevideo.com') ||
          host.endsWith('youtube.com') ||
          host.endsWith('ytimg.com');
      if (!esYoutube) return null;

      final c = (uri.queryParameters['c'] ?? '').toUpperCase();
      String ua;
      String? origin;
      String? referer;
      if (c.startsWith('ANDROID_VR') || c == 'ANDROID') {
        ua = c.startsWith('ANDROID_VR')
            ? 'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; '
                  'Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip'
            : 'com.google.android.youtube/20.02.30 (Linux; U; Android 11) gzip';
      } else if (c.startsWith('IOS')) {
        ua = 'com.google.ios.youtube/21.02.3 (iPhone16,2; U; CPU iOS 18_3_2 '
              'like Mac OS X)';
      } else if (c == 'MWEB') {
        ua = 'Mozilla/5.0 (iPad; CPU OS 16_7_10 like Mac OS X) '
              'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/'
              '15E148 Safari/604.1,gzip(gfe)';
        origin = 'https://www.youtube.com';
        referer = 'https://www.youtube.com/';
      } else if (c == 'WEB_REMIX') {
        ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
        origin = 'https://music.youtube.com';
        referer = 'https://music.youtube.com/';
      } else if (c == 'WEB_EMBEDDED_PLAYER' || c == 'WEB') {
        ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
        origin = 'https://www.youtube.com';
        referer = 'https://www.youtube.com/';
      } else if (c == 'TVHTML5' || c == 'TVHTML5_SIMPLY_EMBEDDED_PLAYER') {
        ua = c == 'TVHTML5'
            ? 'Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.5) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Version/6.5 TV Safari/537.36'
            : 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version';
        origin = 'https://www.youtube.com';
        referer = 'https://www.youtube.com/tv';
      } else {
        ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';
      }
      return {
        'User-Agent': ua,
        if (origin != null) 'Origin': origin,
        if (referer != null) 'Referer': referer,
      };
    } catch (_) {
      return null;
    }
  }

  /// Probe de vida barato para una URL de stream http(s) cacheada (mpv
  /// reporta opens de URLs podridas SIN error visible). YouTube bot-gatea
  /// algunos formatos sirviendo solo el primer ~1MB y respondiendo 403 a
  /// ranges más allá — un probe en bytes=0-0 ve 206 y las reporta vivas;
  /// probar el ÚLTIMO byte (clen-1) las distingue: gateadas 403, sanas 206.
  Future<bool> _urlStreamViva(String url) async {
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return true;
    }
    try {
      final m = RegExp(r'[?&]clen=(\d+)').firstMatch(url);
      final probeFin = (m != null && int.parse(m.group(1)!) > 0)
          ? (int.parse(m.group(1)!) - 1).toString()
          : '3145727'; // ~3MB: pasado todo gate observado cuando falta clen
      final res = await http
          .get(
            Uri.parse(url),
            headers: {
              'Range': 'bytes=$probeFin-$probeFin',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                  'AppleWebKit/537.36 (KHTML, like Gecko) '
                  'Chrome/131.0.0.0 Safari/537.36',
            },
          )
          .timeout(const Duration(seconds: 4));
      final code = res.statusCode;
      // ESTRICTO: solo 200/206/416 = CDN sirve contenido completo; un
      // 403/404/410 o fallo de red cuenta muerto (falso negativo solo
      // cuesta una re-resolución, más barato que un stall silencioso).
      return code == 200 || code == 206 || code == 416;
    } catch (_) {
      return false;
    }
  }
}