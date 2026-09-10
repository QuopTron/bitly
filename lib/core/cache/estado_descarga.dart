// ─────────────────────────────────────────────────────────────
// estado_descarga.dart — Estado de una descarga individual y del
// cubit de descargas (mapa de progreso, huellas descargadas,
// flags de error/backend reiniciado/carpeta perdida/gate).
// Se conecta con: DownloadCubit (estado del cubit).
// Parte del flujo: descargas (Mi Espacio y botón de descarga).
// ─────────────────────────────────────────────────────────────

import 'package:equatable/equatable.dart';

enum EstadoDescarga { ninguno, enCola, enProgreso, completado, interrumpido }

class DatosEstadoDescarga {
  final EstadoDescarga estado;
  final double progreso;
  final String? mensajeError;

  const DatosEstadoDescarga({
    this.estado = EstadoDescarga.ninguno,
    this.progreso = 0.0,
    this.mensajeError,
  });
}

class EstadoCubitDescargas extends Equatable {
  final Map<String, DatosEstadoDescarga> descargas;
  final Set<String> huellasDescargadas;
  final bool cargando;

  /// true cuando el backend Go se reinició con descargas en curso.
  /// La UI puede mostrar un banner/snackbar único al pasar a true.
  final bool backendReiniciado;

  /// No-null cuando una descarga completada estaba encriptada/DRM y el
  /// cliente no pudo desencriptarla (p.ej. sin ffmpeg-kit). La UI muestra
  /// un aviso único mientras esté seteado, luego lo limpia vía
  /// DownloadCubit.confirmarErrorDesencriptado.
  final String? errorDesencriptado;

  /// true cuando la carpeta de descargas ya no es accesible (grant SAF
  /// revocado, directorio borrado, permiso denegado). La UI muestra un
  /// diálogo de recuperación pidiendo re-seleccionar la carpeta.
  final bool carpetaPerdida;

  /// No-null cuando una descarga fue rechazada por el gate del plan free
  /// (ventana de 8h expirada). La UI muestra un snackbar único con el
  /// mensaje del trial, luego lo limpia vía confirmarGateBloqueado.
  final String? gateDescargaBloqueado;

  const EstadoCubitDescargas({
    this.descargas = const {},
    this.huellasDescargadas = const {},
    this.cargando = false,
    this.backendReiniciado = false,
    this.errorDesencriptado,
    this.carpetaPerdida = false,
    this.gateDescargaBloqueado,
  });

  EstadoCubitDescargas copiarCon({
    Map<String, DatosEstadoDescarga>? descargas,
    Set<String>? huellasDescargadas,
    bool? cargando,
    bool? backendReiniciado,
    String? errorDesencriptado,
    bool limpiarErrorDesencriptado = false,
    bool? carpetaPerdida,
    bool limpiarCarpetaPerdida = false,
    String? gateDescargaBloqueado,
    bool limpiarGateBloqueado = false,
  }) =>
      EstadoCubitDescargas(
        descargas: descargas ?? this.descargas,
        huellasDescargadas: huellasDescargadas ?? this.huellasDescargadas,
        cargando: cargando ?? this.cargando,
        backendReiniciado: backendReiniciado ?? this.backendReiniciado,
        errorDesencriptado: limpiarErrorDesencriptado ? null : (errorDesencriptado ?? this.errorDesencriptado),
        carpetaPerdida: limpiarCarpetaPerdida ? false : (carpetaPerdida ?? this.carpetaPerdida),
        gateDescargaBloqueado: limpiarGateBloqueado
            ? null
            : (gateDescargaBloqueado ?? this.gateDescargaBloqueado),
      );

  @override
  List<Object?> get props => [
    descargas,
    huellasDescargadas,
    cargando,
    backendReiniciado,
    errorDesencriptado,
    carpetaPerdida,
    gateDescargaBloqueado,
  ];
}