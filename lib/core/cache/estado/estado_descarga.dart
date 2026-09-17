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

  /// Motivo del fallo cuando el estado es [EstadoDescarga.interrumpido]. Lo
  /// escribe quien corta la descarga (poll, gate, carpeta) y lo muestra la UI:
  /// antes existía el campo pero ninguna vista lo leía, así que una descarga
  /// fallida quedaba en rojo sin decir por qué.
  final String? mensajeError;

  /// Reintento en sitio ya consumido (0 = el intento original) y cuántos hay
  /// en total. Permite que la UI diga "Reintentando 2/3" en vez de mostrar el
  /// mismo estado de cola para un reintento que para el primer intento.
  final int intento;
  final int totalIntentos;

  const DatosEstadoDescarga({
    this.estado = EstadoDescarga.ninguno,
    this.progreso = 0.0,
    this.mensajeError,
    this.intento = 0,
    this.totalIntentos = 0,
  });

  /// ¿Es un reintento en curso (no el intento original)?
  bool get esReintento => intento > 0;
}

/// Datos del fallo definitivo de una descarga (ya sin reintentos). Guarda
/// DATOS, no una frase armada: el texto lo compone la UI con l10n, igual que
/// el resto de los avisos del proyecto (p.ej. el código 'decrypt').
class FalloDescarga {
  /// Clave interna de la descarga que falló (p.ej. "track_x_ytmusic"). Permite
  /// que la UI vuelva a encolarla sin adivinar de qué canción se trata.
  final String baseId;

  /// Qué falló, tal como el usuario lo reconoce (título de la canción).
  final String titulo;

  /// Motivo técnico que devolvió el backend/proveedor (no traducible).
  final String motivo;

  /// true si el corte pide una acción del usuario (carpeta sin permiso, sesión
  /// vencida): reintentar solo repetiría el mismo aviso.
  final bool necesitaUsuario;

  const FalloDescarga({
    required this.titulo,
    required this.motivo,
    this.baseId = '',
    this.necesitaUsuario = false,
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

  /// Aviso único de una descarga que quedó fallida SIN reintentos pendientes.
  /// La UI lo muestra una vez y lo limpia con confirmarFalloDescarga. Es la
  /// única forma en que el usuario se entera de por qué falló: antes el motivo
  /// moría en el mapa de estados y la descarga quedaba en rojo sin explicación.
  final FalloDescarga? falloDescarga;

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
    this.falloDescarga,
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
    FalloDescarga? falloDescarga,
    bool limpiarFalloDescarga = false,
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
        falloDescarga: limpiarFalloDescarga
            ? null
            : (falloDescarga ?? this.falloDescarga),
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
    falloDescarga,
  ];
}