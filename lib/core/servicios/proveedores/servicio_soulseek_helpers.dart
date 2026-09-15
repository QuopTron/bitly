// ─────────────────────────────────────────────────────────────
// servicio_soulseek_helpers.dart — PART de servicio_soulseek.dart:
// traducción de la respuesta de Go a algo que el usuario entiende —
// sacar el prefijo técnico del mensaje, mapear el motivo
// (nombre_tomado / nombre_invalido) y aceptar la respuesta como Map
// o como string JSON.
// Se conecta con: servicio_soulseek.dart (misma library) + modelo_soulseek.
// Parte del flujo: Ajustes → Soulseek.
// ─────────────────────────────────────────────────────────────

part of 'servicio_soulseek.dart';

/// Saca el prefijo técnico del backend ("soulseek: ") para mostrar el texto
/// tal como lo lee el usuario.
String _limpiarMensaje(String? crudo) {
  final texto = (crudo ?? '').trim();
  if (texto.isEmpty) return 'No se pudo conectar con Soulseek.';
  return texto.startsWith('soulseek: ')
      ? texto.substring('soulseek: '.length).trim()
      : texto;
}

/// Traduce el motivo que manda Go. Un valor desconocido cae a [ninguno] a
/// propósito: la UI nunca debe bloquear al usuario por un motivo que no
/// entiende.
MotivoSoulseek _motivoDesde(String? motivo) {
  switch (motivo) {
    case 'nombre_tomado':
      return MotivoSoulseek.nombreTomado;
    case 'nombre_invalido':
      return MotivoSoulseek.nombreInvalido;
    default:
      return MotivoSoulseek.ninguno;
  }
}

/// El RPC de Go devuelve un string JSON; algunas plataformas ya lo
/// entregan decodificado. Se aceptan las dos formas.
Map<String, dynamic>? _comoMapa(Object? respuesta) {
  try {
    if (respuesta is Map) return Map<String, dynamic>.from(respuesta);
    if (respuesta is String && respuesta.trim().isNotEmpty) {
      final decodificado = jsonDecode(respuesta);
      if (decodificado is Map) return Map<String, dynamic>.from(decodificado);
    }
  } catch (e) {
    debugPrint('[Soulseek] respuesta ilegible: $e');
  }
  return null;
}
