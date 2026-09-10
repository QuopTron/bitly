// ─────────────────────────────────────────────────────────────
// desencriptado_claves.dart — PART de desencriptado_stream.dart:
// genera los candidatos de clave de desencriptado (hex plano,
// base64, con/sin prefijo 0x) y resuelve la extensión de salida
// preferida. FFmpeg exige claves hex de exactamente 32 chars para
// AES-128 y rechaza el prefijo 0x.
// Se conecta con: desencriptado_stream.dart (misma library).
// Parte del flujo: desencriptado de streams (candidatos de clave).
// ─────────────────────────────────────────────────────────────

part of 'desencriptado_stream.dart';

/// Candidatos de clave para un proveedor. Las fuentes (p.ej. Amazon
/// zarz.moe) pueden devolver la clave con prefijo `0x`, hex compacto o
/// base64; el demuxer MOV/MP4 de FFmpeg espera hex plano (la decodifica
/// como hex) de exactamente 16 bytes para AES-128 y RECHAZA el prefijo `0x`
/// o cualquier otra longitud. Solo se emiten claves hex de 32 chars sin
/// prefijo, probadas hasta que una produzca un archivo reproducible.
List<String> _candidatosClaveDesencriptado(String claveCruda) {
  final candidatos = <String>{};
  // El demuxer mov de FFmpeg decodifica la opción `decryption_key` como hex;
  // una clave de longitud distinta a 16 bytes falla con "Invalid decryption key len".
  void agregarHex(String hex) {
    final normalizado = hex.trim().toLowerCase();
    if (normalizado.isEmpty || normalizado.length != 32) return;
    if (RegExp(r'^[0-9a-f]+$').hasMatch(normalizado)) candidatos.add(normalizado);
  }

  final recortada = claveCruda.trim();
  if (recortada.isEmpty) return candidatos.toList();

  final sinPrefijo = recortada.startsWith(RegExp(r'0x', caseSensitive: false))
      ? recortada.substring(2)
      : recortada;

  // Hex plano: quita basura no-hex y toma la forma de 16 bytes (32 hex).
  final hexCompacto = sinPrefijo.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  agregarHex(hexCompacto);

  // La fuente puede devolver la clave en base64. Decodifica y emite la forma
  // hex de 16 bytes (solo claves que decodifican a exactamente 16 bytes).
  try {
    final decodificado = base64Decode(sinPrefijo.replaceAll(RegExp(r'\s+'), ''));
    final hex = decodificado.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    agregarHex(hex);
  } catch (_) {}

  // Algunos builds de FFmpeg aceptan la clave cruda de 16 bytes directa.
  agregarHex(sinPrefijo);
  if (recortada.length == 32 || recortada.length == 16) agregarHex(recortada);

  return candidatos.toList();
}

/// Resuelve la extensión preferida de salida del archivo desencriptado
/// (prefiere `.flac` salvo que el formato de entrada exija MP4).
String _resolverExtensionPreferida(String? solicitada) {
  final recortada = (solicitada ?? '').trim();
  if (recortada.isNotEmpty) {
    return recortada.startsWith('.') ? recortada : '.$recortada';
  }
  return '.flac';
}

/// Tamaño + primeros 16 bytes (hex) de [ruta] para diagnósticos de fallo.
Future<String> _huellaArchivo(String ruta) async {
  try {
    final f = File(ruta);
    if (!await f.exists()) return 'archivo no existe';
    final tam = await f.length();
    final raf = await f.open();
    try {
      final head = await raf.read(16);
      return 'size=$tam head=${head.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    } finally {
      await raf.close();
    }
  } catch (e) {
    return 'error de huella: $e';
  }
}