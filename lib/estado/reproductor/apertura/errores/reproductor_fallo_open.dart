// ─────────────────────────────────────────────────────────────
// reproductor_fallo_open.dart — PART de cubit_reproductor.dart:
// reporte legible del fallo al abrir un track — traduce el error del
// backend a un mensaje que el usuario entiende (sesión sin verificar,
// 429, sin conexión o genérico) y, si hace falta verificación, abre el
// modal del proveedor correspondiente.
// Cadena de mixins: … → reporte → fallo_open → apertura_helpers.
// Se conecta con: cubit_reproductor.dart (misma library) +
// servicio_verificacion.
// Parte del flujo: reproducción (error al abrir un track).
// ─────────────────────────────────────────────────────────────

part of '../../cubit_reproductor.dart';

/// Reporte del fallo de apertura. Mixin aplicado en CubitReproductor.
mixin ReproductorFalloOpen on ReproductorReporte {
  /// Reporta el fallo de resolución del open con un mensaje legible según el
  /// tipo de error (verificación requerida / 429 / offline / genérico) y
  /// abre el modal de verificación del proveedor que la necesita.
  Future<void> _manejarFalloOpen(ItemFeed track) async {
    final r = L10n.actual.reproductor;
    final raw = _ultimoErrorStream.trim();
    final rawLower = raw.toLowerCase();
    final necesitaVerificacion =
        _ultimoTipoErrorStream.toLowerCase() == 'verification_required' ||
        rawLower.contains('verify_required') ||
        rawLower.contains('verification required') ||
        rawLower.contains('verify required');
    // Primero se decide el CÓDIGO del fallo; el texto para el aviso se arma
    // desde ese código, así el estado no guarda frases armadas.
    CodigoErrorReproductor? codigo;
    String? msg;
    if (necesitaVerificacion) {
      final servicio =
          _ultimoServicioStream.isNotEmpty
              ? _ultimoServicioStream
              : (track.source ?? '');
      final nombre = ServicioVerificacion().nombreFuente(servicio);
      codigo = CodigoErrorReproductor.sesionNoVerificada;
      msg = nombre.isNotEmpty ? r.sesionDe(nombre) : r.sesionNoVerificada;
      // Refrescar ya la sesión del proveedor que la necesita (p.ej. amazon
      // alcanzado durante fallback).
      unawaited(_verificarServicioParaPlayback(servicio, nombre));
    } else if (raw.contains('429') ||
        rawLower.contains('rate limit') ||
        rawLower.contains('too many')) {
      codigo = CodigoErrorReproductor.proveedorSaturado;
      msg = r.proveedorSaturado;
    } else if (_ultimoTipoErrorStream.toLowerCase() == 'offline' ||
        rawLower.contains('sin conexión')) {
      codigo = CodigoErrorReproductor.sinConexion;
      msg = r.sinConexion;
    } else if (raw.isNotEmpty) {
      codigo = CodigoErrorReproductor.sinStream;
      msg = r.sinStream;
    }
    if (codigo != null && msg != null) {
      emit(
        state.copiarCon(
          estadoReproduccion: EstadoReproduccion.error,
          codigoError: codigo,
        ),
      );
      if (!necesitaVerificacion) ServicioVerificacion().mostrarAviso(msg);
    }
  }
}
