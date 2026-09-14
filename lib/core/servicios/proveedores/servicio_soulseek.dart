// ─────────────────────────────────────────────────────────────
// servicio_soulseek.dart — Alta y conexión de la cuenta de Soulseek.
//
// Qué automatiza: el usuario escribe UNA sola cosa (el nombre que quiere
// tener en la red) y al tocar "Siguiente" la app genera la contraseña,
// conecta, y la cuenta queda creada — porque en Soulseek conectar ES
// registrarse, lo da de alta el propio servidor en ese paso. Sin mail, sin
// captcha, sin pago y sin que el usuario entregue ningún dato personal.
//
// Por qué el nombre NO se inventa ni se oculta: el spec oficial del
// protocolo lo prohíbe por escrito ("It is unacceptable to use randomly
// generated usernames, as such automated scripting is disallowed by the
// official server rules") y el baneo lo come el usuario, en su IP. El nombre
// lo elige él; la contraseña sí la genera la app.
//
// La contraseña no se muestra por defecto, pero SIEMPRE se puede ver y
// exportar: Soulseek no tiene recuperación de contraseña, así que esconderla
// del todo sería regalar la cuenta al primer olvido.
//
// Se conecta con: backend_go (soulseekConectar) +
// ServicioCredencialesProveedor (persistencia y push a Go).
// Parte del flujo: Ajustes → Soulseek.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../backend_go/nucleo/contrato_backend.dart';
import '../../cache/almacenes/cache_ajustes.dart';
import '../../../app/inyeccion.dart' as di;
import 'servicio_credenciales_proveedor.dart';

/// Motivo accionable del rechazo del backend (vacío = no hay motivo que el
/// usuario pueda resolver).
///
/// Existe porque no todos los fallos son iguales: un nombre tomado o inválido
/// lo arregla el usuario eligiendo otro, y el setup tiene que pedirle eso en
/// vez de dejarlo pasar. Una caída de red o el servidor lleno, en cambio, no
/// se arreglan desde acá y no deben frenar la bienvenida.
enum MotivoSoulseek {
  /// El nombre ya existe en la red con otra contraseña.
  nombreTomado,

  /// El nombre no cumple las reglas del protocolo (largo, caracteres...).
  nombreInvalido,

  /// Sin motivo accionable (red, servidor, backend sin inicializar).
  ninguno,
}

/// Resultado del botón "Siguiente".
class ResultadoSoulseek {
  final bool ok;
  final String mensaje;
  final String usuario;
  final String password;
  final bool passwordGenerada;
  final MotivoSoulseek motivo;

  const ResultadoSoulseek({
    required this.ok,
    required this.mensaje,
    this.usuario = '',
    this.password = '',
    this.passwordGenerada = false,
    this.motivo = MotivoSoulseek.ninguno,
  });

  /// El usuario puede resolverlo cambiando el nombre.
  bool get problemaDeNombre =>
      motivo == MotivoSoulseek.nombreTomado ||
      motivo == MotivoSoulseek.nombreInvalido;

  /// El motivo como clave estable, para que quien lo consuma (el setup) no
  /// dependa del enum de este servicio para decidir qué mostrar.
  String get motivoClave {
    switch (motivo) {
      case MotivoSoulseek.nombreTomado:
        return 'nombre_tomado';
      case MotivoSoulseek.nombreInvalido:
        return 'nombre_invalido';
      case MotivoSoulseek.ninguno:
        return '';
    }
  }
}

/// Alta/conexión de la cuenta de Soulseek y lectura de sus credenciales.
class ServicioSoulseek {
  /// Id con el que el backend registra el provider nativo y con el que se
  /// guardan las credenciales en los ajustes (`soulseek_usuario`,
  /// `soulseek_password`).
  static const idExt = 'soulseek';

  CacheAjustes get _cache => di.sl<CacheAjustes>();
  BackendService get _backend => di.sl<BackendService>();

  Future<String> get usuarioGuardado async =>
      ((await _cache.getAjuste('${idExt}_usuario')) ?? '').trim();

  /// Nombre que el usuario eligió al configurar la app (paso de nombre del
  /// setup). Es la propuesta natural para la cuenta de Soulseek: es SU nombre,
  /// ya visible en la app, y no hay que pedirlo dos veces.
  Future<String> get usuarioDeLaApp async {
    final datos = await _cache.cargarDatosSetup();
    return (datos?.username ?? '').trim();
  }

  Future<String> get passwordGuardada async =>
      ((await _cache.getAjuste('${idExt}_password')) ?? '').trim();

  /// Hay credenciales guardadas (no implica que la cuenta siga viva: eso lo
  /// confirma el servidor al conectar).
  Future<bool> get hayCuentaGuardada async {
    return (await usuarioGuardado).isNotEmpty &&
        (await passwordGuardada).isNotEmpty;
  }

  /// "Siguiente": crea la cuenta si no existe y la conecta.
  ///
  /// Si ya hay una contraseña guardada para ese mismo nombre se reutiliza (no
  /// se rota: rotarla dejaría cuentas huérfanas), y si el usuario cambia el
  /// nombre se genera una contraseña nueva para la cuenta nueva.
  Future<ResultadoSoulseek> crearOConectar(String usuarioEscrito) async {
    final nombre = usuarioEscrito.trim();
    if (nombre.isEmpty) {
      return const ResultadoSoulseek(
        ok: false,
        mensaje: 'Escribí el nombre que querés usar en Soulseek.',
      );
    }

    try {
      final guardado = await usuarioGuardado;
      final passwordPrevia = guardado == nombre ? await passwordGuardada : '';

      final respuesta = await _backend.rpcCall('soulseekConectar', {
        'usuario': nombre,
        if (passwordPrevia.isNotEmpty) 'password': passwordPrevia,
      });
      final datos = _comoMapa(respuesta);
      if (datos == null) {
        return const ResultadoSoulseek(
          ok: false,
          mensaje: 'Respuesta inesperada del backend.',
        );
      }      if (datos['ok'] != true) {
        return ResultadoSoulseek(
          ok: false,
          mensaje: _limpiarMensaje(datos['error'] as String?),
          motivo: _motivoDesde(datos['motivo'] as String?),
        );
      }

      final usuarioReal = (datos['usuario'] as String?)?.trim() ?? nombre;
      final password = (datos['password'] as String?) ?? passwordPrevia;

      // Persistir + empujar a Go: guardarYReinicializar deja los ajustes en
      // CacheAjustes y llama setExtensionSettings, que en el backend llega a
      // soulseek.Client.SetSettings.
      await ServicioCredencialesProveedor(
        _backend,
        _cache,
      ).guardarYReinicializar(idExt, {
        'usuario': usuarioReal,
        'password': password,
      });

      return ResultadoSoulseek(
        ok: true,
        mensaje:
            (datos['mensaje'] as String?) ??
            'Cuenta conectada y lista para buscar.',
        usuario: usuarioReal,
        password: password,
        passwordGenerada: datos['password_generada'] == true,
      );
    } catch (e) {
      return ResultadoSoulseek(ok: false, mensaje: 'Error: $e');
    }
  }

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
}
