// ─────────────────────────────────────────────────────────────
// servicio_conexion_vinculos.dart — PART de servicio_conexion.dart: lo que
// pasa cuando alguien se vincula DE VERDAD (por la red local).
//
// Hasta acá la lista de Conexión era la declaración del usuario: un aparato
// quedaba "sin vincular" para siempre. Cuando dos aparatos se aceptan en la
// red, esto lo marca vinculado en la lista, con el nombre que dijo el otro, y
// respeta el cupo del plan: un aparato nuevo ocupa lugar.
//
// Se conecta con: servicio_conexion.dart (misma library) + servicio_lan (lo
// llama al aceptar un vínculo).
// Parte del flujo: Ajustes → Conexión (vínculo).
// ─────────────────────────────────────────────────────────────

part of '../base/servicio_conexion.dart';

/// Alta y marcado de aparatos que se vincularon por la red local.
extension VinculosConexion on ServicioConexion {
  /// Marca a [id] como vinculado (lo avisa el vínculo de la red). Si no
  /// estaba en la lista se agrega, siempre que haya lugar: devuelve false
  /// cuando el plan ya está lleno (ahí el vínculo no se guarda).
  Future<bool> vincular(String id, String nombre) async {
    final ahora = DateTime.now().millisecondsSinceEpoch;
    final existe = _dispositivos.any((d) => d.id == id);
    if (!existe && lugaresLibres <= 0) return false;
    if (existe) {
      _dispositivos = [
        for (final d in _dispositivos)
          d.id == id
              ? d.copiarCon(
                vinculado: true,
                ultimaVezMs: ahora,
                nombre: nombre.isEmpty ? d.nombre : nombre,
              )
              : d,
      ];
    } else {
      _dispositivos = [
        ..._dispositivos,
        DispositivoConectado(
          id: id,
          nombre: nombre,
          tipo: TipoDispositivo.extra,
          vinculado: true,
          ultimaVezMs: ahora,
        ),
      ];
    }
    await _almacen.guardarDispositivos(_dispositivos);
    return true;
  }
}
