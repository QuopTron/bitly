// ─────────────────────────────────────────────────────────────
// servicio_lan_vinculo.dart — PART de servicio_lan.dart: el vínculo que
// arranca con un QR (el aparato que se quiere vincular lo MUESTRA y el dueño
// lo escanea, o escribe el código de 6 dígitos si no tiene cámara).
//
// Por qué el código: el QR lleva el id, las direcciones y el puerto del
// aparato invitado, y además un código de 6 dígitos que solo se ve en esa
// pantalla. Cuando el pedido de vínculo llega con ese código, el aparato
// invitado lo acepta SOLO: el que escaneó tuvo la pantalla delante, así que
// no hace falta otro toque. El código se consume al usarse y vence a los
// pocos minutos.
//
// Se conecta con: servicio_lan.dart (misma library) + payload_vinculo +
// servicio_conexion (el tipo y el nombre del aparato).
// Parte del flujo: Ajustes → Conexión → vincular con QR.
// ─────────────────────────────────────────────────────────────

part of '../base/servicio_lan.dart';

/// Invitación por QR y vínculo con el código de esa invitación.
extension VinculoLan on ServicioLan {
  /// Código de la invitación abierta (vacío = no hay ninguna).
  String get codigoInvitacion => _codigoInvitacion;

  /// ¿La invitación abierta todavía vale?
  bool get invitacionVigente =>
      _codigoInvitacion.isNotEmpty &&
      _codigoExpiraMs > DateTime.now().millisecondsSinceEpoch;

  /// Las IPv4 de ESTE aparato en la red, sin loopback: son las direcciones
  /// que el otro aparato va a probar para alcanzarlo.
  Future<List<String>> direccionesLocales() async {
    try {
      final interfaces = await io.NetworkInterface.list(
        type: io.InternetAddressType.IPv4,
      );
      return [
        for (final i in interfaces)
          for (final d in i.addresses)
            if (!d.isLoopback && !d.address.startsWith('169.254.'))
              d.address,
      ];
    } catch (e) {
      debugPrint('[Lan] no se pudieron leer las direcciones: $e');
      return const [];
    }
  }

  /// Abre una invitación nueva y devuelve lo que hay que dibujar en el QR.
  ///
  /// El código anterior se descarta: en pantalla se muestra uno por vez, así
  /// que el que se ve es siempre el que vale.
  Future<PayloadVinculo> abrirInvitacion() async {
    _codigoInvitacion = codigoVinculoNuevo();
    _codigoExpiraMs =
        DateTime.now().millisecondsSinceEpoch +
        validezVinculo.inMilliseconds;
    return PayloadVinculo(
      id: _idPropio,
      nombre: _nombre,
      tipo: tipoDeEsteAparato(),
      direcciones: await direccionesLocales(),
      puerto: _puerto,
      codigo: _codigoInvitacion,
      expiraMs: _codigoExpiraMs,
    );
  }

  /// Cierra la invitación (el usuario salió de la pantalla del QR).
  void cerrarInvitacion() {
    _codigoInvitacion = '';
    _codigoExpiraMs = 0;
  }

  /// El aparato DUEÑO escanea el QR: prueba cada dirección del invitado hasta
  /// que una contesta y devuelve el par ya vinculado (o null si no pudo).
  Future<ParLan?> vincularConInvitacion(PayloadVinculo invitacion) async {
    for (final ip in invitacion.direcciones) {
      final par = await pedirVinculo(
        ParLan(
          id: invitacion.id,
          nombre: invitacion.nombre,
          host: ip,
          puerto: invitacion.puerto,
        ),
        codigo: invitacion.codigo,
      );
      if (par != null) return par;
    }
    return null;
  }
}
