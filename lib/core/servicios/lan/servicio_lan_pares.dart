// ─────────────────────────────────────────────────────────────
// servicio_lan_pares.dart — PART de servicio_lan.dart: la lista de pares
// (vecinos vistos y vínculos ya hechos).
//
// Separa "con quién estoy hablando" del arranque y de los protocolos: acá
// vive solo el alta, la actualización y el guardado de los pares, con dos
// cuidados que importan:
//   · una DIFUSIÓN nunca borra un vínculo (si no, cualquiera que se anuncie
//     con el mismo id apagaría el token);
//   · la decisión del usuario sobre un pedido de vínculo se contesta una sola
//     vez y se limpia, para que el otro aparato no quede esperando.
//
// Se conecta con: servicio_lan.dart (misma library) + lan_almacen.
// Parte del flujo: Ajustes → Conexión → biblioteca en tu red.
// ─────────────────────────────────────────────────────────────

part of 'servicio_lan.dart';

/// Alta, actualización y guardado de los pares.
extension ParesLan on ServicioLan {
  /// El usuario decidió sobre la solicitud pendiente: se le contesta al
  /// aparato que pidió, y si aceptó queda vinculado de los dos lados.
  Future<void> responderSolicitud(bool aceptar) async {
    final par = solicitudVinculo.value;
    _decision?.complete(aceptar);
    _decision = null;
    solicitudVinculo.value = null;
    if (!aceptar || par == null) return;
    await fusionarPar(
      par.copiarCon(ultimaVezMs: DateTime.now().millisecondsSinceEpoch),
    );
    alVincular?.call(par.id, par.nombre);
  }

  /// Guarda la lista de pares (vinculaciones incluidas) y avisa a la UI.
  Future<void> guardarPares() async {
    pares.value = _lista;
    await guardarParesLan(_cache, _lista);
  }

  /// Anota a un vecino que se acaba de escuchar. No toca los vínculos ya
  /// hechos (una difusión nunca borra un token) y devuelve true si es la
  /// primera vez que se lo ve, que es cuando vale la pena guardarlo.
  bool anotarVecino(ParLan nuevo) {
    var conocido = false;
    _lista = [
      for (final p in _lista)
        if (p.id == nuevo.id)
          (() {
            conocido = true;
            return p.copiarCon(
              nombre: nuevo.nombre.isEmpty ? p.nombre : nuevo.nombre,
              host: nuevo.host.isEmpty ? p.host : nuevo.host,
              puerto: nuevo.puerto <= 0 ? p.puerto : nuevo.puerto,
              ultimaVezMs: nuevo.ultimaVezMs,
            );
          })()
        else
          p,
      if (!conocido) nuevo,
    ];
    pares.value = _lista;
    return !conocido;
  }

  /// Reemplaza (o agrega) un par por id, sin tocar lo que ya se sabía de él.
  Future<void> fusionarPar(ParLan nuevo) async {
    var encontrado = false;
    _lista = [
      for (final p in _lista)
        if (p.id == nuevo.id)
          (() {
            encontrado = true;
            return p.copiarCon(
              nombre: nuevo.nombre.isEmpty ? p.nombre : nuevo.nombre,
              host: nuevo.host.isEmpty ? p.host : nuevo.host,
              puerto: nuevo.puerto <= 0 ? p.puerto : nuevo.puerto,
              // El token solo se reemplaza por uno nuevo con contenido: una
              // difusión común no puede borrar un vínculo ya hecho.
              token: nuevo.token.isEmpty ? p.token : nuevo.token,
              ultimaVezMs:
                  nuevo.ultimaVezMs > 0 ? nuevo.ultimaVezMs : p.ultimaVezMs,
            );
          })()
        else
          p,
      if (!encontrado) nuevo,
    ];
    await guardarPares();
  }
}
