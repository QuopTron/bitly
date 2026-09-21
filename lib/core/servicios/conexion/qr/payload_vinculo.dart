// ─────────────────────────────────────────────────────────────
// payload_vinculo.dart — Lo que viaja DENTRO del QR del vínculo: quién es el
// aparato que quiere vincularse, por dónde se lo alcanza y el código de 6
// dígitos que prueba que el dueño vio esa pantalla.
//
// Es puro (texto entra, texto sale): así el formato del QR y sus rechazos
// —versión distinta, ya vencido, faltantes, basura— se prueban sin cámara y
// sin red. El código va adentro del QR Y se muestra debajo: en un PC o una TV
// (sin cámara) el dueño lo escribe a mano en vez de escanear.
//
// Se conecta con: servicio_lan (arma la invitación y la lee al vincular) + la
// pantalla de QR de Conexión.
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:math' as math;

import '../../../modelos/usuario/dispositivos/dispositivo_conectado.dart';

/// Versión del formato del QR: si cambia, un aparato viejo no lee a medias.
const int versionVinculo = 1;

/// Firma del contenido: un QR de otra cosa se rechaza sin más.
const String appVinculo = 'bitly-vinculo';

/// Cuánto vale una invitación. Corto a propósito: el código está en pantalla
/// y sirve para vincularse una vez.
const Duration validezVinculo = Duration(minutes: 3);

/// Prefijo del texto del QR (así se reconoce a simple vista que es nuestro).
const String esquemaVinculo = 'bitly-vincular:';

/// Un código de 6 dígitos, difícil de adivinar (nada de `Random()` común).
String codigoVinculoNuevo([math.Random? azar]) {
  final r = azar ?? math.Random.secure();
  final n = r.nextInt(1000000);
  return n.toString().padLeft(6, '0');
}

/// La invitación de ESTE aparato: quién es, dónde está y su código.
class PayloadVinculo {
  /// Id del aparato invitado (el mismo que usa Conexión).
  final String id;

  /// Cómo se llama ese aparato ("Celu de Pablo").
  final String nombre;

  final TipoDispositivo tipo;

  /// IPv4 por las que se lo alcanza en la red local (puede haber varias).
  final List<String> direcciones;

  /// Puerto de su mini-servidor (el que recibe el pedido de vínculo).
  final int puerto;

  /// Código de 6 dígitos que se muestra debajo del QR.
  final String codigo;

  /// Cuándo deja de valer la invitación (milisegundos desde la época).
  final int expiraMs;

  const PayloadVinculo({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.direcciones,
    required this.puerto,
    required this.codigo,
    required this.expiraMs,
  });

  /// ¿Sigue valiendo ahora?
  bool vigenteEn(int ahoraMs) => expiraMs > ahoraMs;

  /// ¿Se puede intentar el vínculo con estos datos?
  bool get utilizable =>
      id.isNotEmpty && puerto > 0 && direcciones.isNotEmpty;

  Map<String, dynamic> aJson() => {
    'app': appVinculo,
    'v': versionVinculo,
    'id': id,
    'nombre': nombre,
    'tipo': tipo.clave,
    'ips': direcciones,
    'puerto': puerto,
    'codigo': codigo,
    'expira': expiraMs,
  };

  /// El texto que se dibuja en el QR (base64 de un JSON chico: el QR queda
  /// denso y legible por cualquier lector).
  String get textoQr =>
      esquemaVinculo +
      base64Url.encode(utf8.encode(jsonEncode(aJson()))).replaceAll('=', '');

  /// Lee el texto de un QR. Devuelve null si no es nuestro, si es de otra
  /// versión, si está vencido o si le falta algo: nunca se arma un vínculo
  /// con datos a medias.
  static PayloadVinculo? leer(String crudo, {required int ahoraMs}) {
    try {
      var texto = crudo.trim();
      if (texto.startsWith(esquemaVinculo)) {
        texto = texto.substring(esquemaVinculo.length);
      }
      // El base64 recortado arriba se completa con el relleno que le falta.
      final relleno = (4 - texto.length % 4) % 4;
      final json = jsonDecode(
        utf8.decode(base64Url.decode(texto + ('=' * relleno))),
      );
      if (json is! Map<String, dynamic>) return null;
      if (json['app'] != appVinculo) return null;
      if ((json['v'] as num?)?.toInt() != versionVinculo) return null;
      final puerto = (json['puerto'] as num?)?.toInt() ?? 0;
      final expira = (json['expira'] as num?)?.toInt() ?? 0;
      final id = json['id'] as String? ?? '';
      final codigo = json['codigo'] as String? ?? '';
      final ips = [
        for (final ip in (json['ips'] as List? ?? const []))
          if (ip is String && ip.isNotEmpty) ip,
      ];
      if (id.isEmpty || puerto <= 0 || puerto > 65535) return null;
      final vigente = expira > ahoraMs;
      if (ips.isEmpty || codigo.length != 6 || !vigente) {
        return null;
      }
      return PayloadVinculo(
        id: id,
        nombre: json['nombre'] as String? ?? '',
        tipo: TipoDispositivo.desdeClave(json['tipo'] as String?),
        direcciones: ips,
        puerto: puerto,
        codigo: codigo,
        expiraMs: expira,
      );
    } on FormatException {
      // Un QR ilegible es lo normal (cualquiera puede apuntar a cualquier
      // código): se ignora.
      return null;
    }
  }
}
