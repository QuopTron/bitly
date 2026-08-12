import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

final _log = Logger();

/// Pure Dart implementation of premium code validation.
///
/// Replaces the Go `internal/auth/premium/` package entirely.
/// Uses HMAC-SHA256, GitHub API integration, and in-memory token storage.
class PremiumService {
  static final PremiumService _instance = PremiumService._();
  factory PremiumService() => _instance;
  PremiumService._();

  static const String _secretKey = 'bitly_secret_key_v1';

  static const String _codesApiUrl =
      'https://api.github.com/repos/QuopTron/bitly_codes_premium/contents/codes.json';

  static const Duration _httpTimeout = Duration(seconds: 10);

  static const Set<String> _validWords = {'pablo', 'pabol', 'flox'};

  String? _githubToken;

  /// ── GitHub Token ──────────────────────────────────────────────────

  void setGithubToken(String token) {
    _githubToken = token;
  }

  bool get hasGithubToken => _githubToken != null;

  /// ── Public API ────────────────────────────────────────────────────

  /// Validates a premium code string.
  /// Returns `null` if valid, or an error message string if invalid.
  Future<String?> validatePremiumCode(String code) async {
    final masked = code.length > 8 ? '${code.substring(0, 8)}...' : code;
    _log.i('[PremiumService] validatePremiumCode: "$masked"');

    final validationResult = _validateCodeInternal(code);
    if (validationResult != null) {
      _log.w('[PremiumService] Structure validation failed: $validationResult');
      return validationResult;
    }

    _log.i('[PremiumService] Structure valid, checking registry...');
    if (_githubToken != null) {
      final registryError = await _checkCodeInRegistry(code);
      if (registryError != null) {
        _log.w('[PremiumService] Registry check failed: $registryError');
        return registryError;
      }

      _log.i('[PremiumService] Code validated, marking as used...');
      try {
        await _markCodeAsUsed(code);
      } catch (e) {
        _log.w('[PremiumService] Mark-as-used failed (non-fatal): $e');
      }
    } else {
      _log.w('[PremiumService] No GitHub token, skipping registry check');
    }

    _log.i('[PremiumService] Code "$masked" validated successfully');
    return null;
  }

  /// ── Internal validation (matches Go validator.go) ──────────────────

  /// Validates the code structure and HMAC signature.
  /// Returns null if valid, error message if invalid.
  String? _validateCodeInternal(String code) {
    code = code.trim();
    if (code.isEmpty) {
      return 'Código vacío';
    }

    final parts = code.split('.');
    if (parts.length != 2) {
      return 'Formato inválido';
    }

    final dataB64 = parts[0];
    final sigB64 = parts[1];

    // Decode data (URL-safe base64 → standard)
    String dataB64Norm = dataB64.replaceAll('-', '+').replaceAll('_', '/');
    switch (dataB64Norm.length % 4) {
      case 2:
        dataB64Norm += '==';
      case 3:
        dataB64Norm += '=';
    }

    List<int> dataJson;
    try {
      dataJson = base64.decode(dataB64Norm);
    } catch (_) {
      return 'Error decodificando datos';
    }

    Map<String, dynamic> codeData;
    try {
      codeData = json.decode(utf8.decode(dataJson)) as Map<String, dynamic>;
    } catch (_) {
      return 'Error parseando JSON';
    }

    final word = (codeData['p'] as String?)?.toLowerCase() ?? '';
    final expiresAt = (codeData['e'] as num?)?.toInt() ?? 0;

    // Validate word
    if (!_validWords.contains(word)) {
      return 'Palabra no autorizada';
    }

    // Validate expiration
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now > expiresAt) {
      return 'Código expirado';
    }

    // Validate signature
    final message = '$dataB64.$word';
    final expectedSig = _generateSignature(message);
    if (sigB64 != expectedSig) {
      return 'Firma inválida';
    }

    return null; // Valid
  }

  /// ── HMAC-SHA256 signature (matches Go generateSignature) ──────────

  String _generateSignature(String message) {
    final key = utf8.encode(_secretKey);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(utf8.encode(message));

    // URL-safe base64 without padding (matches Go's base64.RawURLEncoding)
    String result = base64Url.encode(digest.bytes);
    result = result.replaceAll('=', '');
    return result;
  }

  /// ── GitHub Registry integration (matches Go codes_json.go) ────────

  Future<String?> _checkCodeInRegistry(String code) async {
    if (_githubToken == null) {
      return 'No se pudo verificar el código en el registro';
    }

    try {
      final codes = await _fetchCodesJson();
      if (codes == null) {
        _log.w('[PremiumService] Failed to fetch codes.json');
        return 'No se pudo verificar el código en el registro';
      }

      final status = codes[code];
      _log.i('[PremiumService] Registry status for this code: "${status ?? "not found"}"');

      if (status == null) {
        return 'Código no encontrado en el registro';
      }

      switch (status) {
        case 'activo':
          return null;
        case 'usado':
          return 'Código ya usado';
        case 'cancelado':
          return 'Código cancelado';
        case 'libre':
          return 'Código liberado';
        default:
          return 'Estado desconocido: $status';
      }
    } catch (e) {
      _log.e('[PremiumService] Registry check error: $e');
      return 'Error verificando código: $e';
    }
  }

  Future<Map<String, String>?> _fetchCodesJson() async {
    final request = http.Request('GET', Uri.parse(_codesApiUrl));
    request.headers['Authorization'] = 'token $_githubToken';
    request.headers['Accept'] = 'application/vnd.github.v3.raw';

    final response = await request.send().timeout(_httpTimeout);
    if (response.statusCode != 200) return null;

    final body = await response.stream.bytesToString();
    final decoded = json.decode(body) as Map<String, dynamic>;
    decoded.remove('_NOTA');
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<void> _markCodeAsUsed(String code) async {
    if (_githubToken == null) return;

    // Step 1: GET the file metadata (SHA + base64 content)
    final getReq = http.Request('GET', Uri.parse(_codesApiUrl));
    getReq.headers['Authorization'] = 'token $_githubToken';
    getReq.headers['Accept'] = 'application/vnd.github.v3+json';

    final getResp = await getReq.send().timeout(_httpTimeout);
    if (getResp.statusCode != 200) return;

    final getBody = await getResp.stream.bytesToString();
    final content = json.decode(getBody) as Map<String, dynamic>;

    final fileSha = content['sha'] as String;
    final encodedContent = content['content'] as String;

    // Step 2: Decode, update, re-encode
    final decodedBytes = base64.decode(encodedContent.replaceAll('\n', ''));
    final codes = json.decode(utf8.decode(decodedBytes)) as Map<String, dynamic>;
    codes[code] = 'usado';

    final updatedJson =
        const JsonEncoder.withIndent('  ').convert(codes);
    final newEncoded = base64.encode(utf8.encode(updatedJson));

    // Step 3: PUT the updated file
    final updateBody = json.encode({
      'message': 'premium: mark code as usado (${code.substring(0, min(code.length, 30))}...)',
      'content': newEncoded,
      'sha': fileSha,
    });

    final putReq = http.Request('PUT', Uri.parse(_codesApiUrl));
    putReq.headers['Authorization'] = 'token $_githubToken';
    putReq.headers['Content-Type'] = 'application/json';
    putReq.body = updateBody;

    final putResp = await putReq.send().timeout(_httpTimeout);
    if (putResp.statusCode != 200 && putResp.statusCode != 201) {
      throw Exception('Failed to update codes.json: ${putResp.statusCode}');
    }
  }
}

