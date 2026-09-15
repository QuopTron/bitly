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
import 'modelo_soulseek.dart';
import 'servicio_credenciales_proveedor.dart';

export 'modelo_soulseek.dart';

part 'servicio_soulseek_helpers.dart';

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


}
