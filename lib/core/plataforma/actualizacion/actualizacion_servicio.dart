// ─────────────────────────────────────────────────────────────
// actualizacion_servicio.dart — Puerta de Flutter a la descarga de
// actualizaciones, que en Android corre en un servicio nativo.
//
// Por qué así: la descarga tiene que seguir con la app en segundo plano (o
// cerrada), mostrar su avance en la barra de notificaciones y dejar el APK
// guardado para instalarlo después. Nada de eso se puede hacer desde Dart —un
// `http.get` muere con la pantalla y escribe en la carpeta temporal—, así que
// el trabajo vive en `UpdateDownloadService.kt` y acá solo queda la puerta:
// pedir, preguntar cómo va, instalar, limpiar.
//
// En Windows/Linux/macOS no hay servicio: [soportado] es false y los métodos
// devuelven el estado "inactivo" (el escritorio sigue con su descarga directa,
// ver update_modal.dart).
//
// Se conecta con: update_modal.dart / update_service.dart y, del otro lado,
// android/app/src/main/kotlin/com/example/bitly/UpdateDownloader.kt.
// Parte del flujo: Ajustes → Versión → actualización.
// ─────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../l10n/app_localizations.dart';

/// En qué momento está la descarga de una versión.
enum EstadoDescargaActualizacion {
  /// Nadie descargó nada (o el servicio no existe en esta plataforma).
  inactivo,

  /// Bajando ahora mismo (mirar [ProgresoActualizacion.progreso]).
  descargando,

  /// Terminada: el APK está en disco y se puede instalar.
  listo,

  /// Se cortó por un error de red o del servidor.
  error,

  /// La cortó el usuario.
  cancelado,
}

/// Cómo va la descarga actual (o qué pasó con la última).
class ProgresoActualizacion {
  final EstadoDescargaActualizacion estado;
  final String version;
  final int leidos;
  final int total;

  /// Porcentaje 0-100. Es 0 cuando el servidor no declara el tamaño.
  final int progreso;
  final String? ruta;
  final String? error;

  const ProgresoActualizacion({
    required this.estado,
    this.version = '',
    this.leidos = 0,
    this.total = 0,
    this.progreso = 0,
    this.ruta,
    this.error,
  });

  static const inactivo = ProgresoActualizacion(
    estado: EstadoDescargaActualizacion.inactivo,
  );

  /// ¿El total se conoce? Sin él no se puede mostrar un porcentaje honesto.
  bool get tieneTotal => total > 0;

  factory ProgresoActualizacion.desdeJson(Map<String, dynamic> json) {
    return ProgresoActualizacion(
      estado: _estadoDesde(json['estado'] as String?),
      version: json['version'] as String? ?? '',
      leidos: (json['leidos'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      progreso: (json['progreso'] as num?)?.toInt() ?? 0,
      ruta: json['ruta'] as String?,
      error: json['error'] as String?,
    );
  }

  static EstadoDescargaActualizacion _estadoDesde(String? crudo) {
    switch (crudo) {
      case 'descargando':
        return EstadoDescargaActualizacion.descargando;
      case 'listo':
        return EstadoDescargaActualizacion.listo;
      case 'error':
        return EstadoDescargaActualizacion.error;
      case 'cancelado':
        return EstadoDescargaActualizacion.cancelado;
      default:
        return EstadoDescargaActualizacion.inactivo;
    }
  }
}

/// Un APK que YA está bajado y esperando instalación.
class VersionDescargada {
  final String version;
  final String nombre;
  final String ruta;
  final int bytes;

  const VersionDescargada({
    required this.version,
    required this.nombre,
    required this.ruta,
    required this.bytes,
  });

  factory VersionDescargada.desdeJson(Map<String, dynamic> json) {
    return VersionDescargada(
      version: json['version'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      ruta: json['ruta'] as String? ?? '',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
    );
  }

  /// Etiqueta legible del peso (MB con un decimal).
  String get pesoLegible =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Puerta a la descarga nativa de actualizaciones.
class ActualizacionServicio {
  ActualizacionServicio._();

  static const MethodChannel _canal = MethodChannel('com.bitly/update');

  /// ¿Esta plataforma descarga en segundo plano? Solo Android tiene el
  /// servicio; el escritorio baja el instalador con la app abierta.
  static bool get soportado => Platform.isAndroid && !kIsWeb;

  /// Arranca (o reanuda) la descarga de [version]. Idempotente: si ya corre,
  /// el servicio no abre una segunda.
  static Future<void> descargar({
    required String url,
    required String version,
    required String nombreAsset,
  }) async {
    if (!soportado) return;
    try {
      await _canal.invokeMethod('descargar', {
        'url': url,
        'version': version,
        'nombre': nombreAsset,
      });
    } catch (e) {
      debugPrint('[Actualizacion] descargar: $e');
    }
  }

  /// Corta la descarga y borra el archivo a medias.
  static Future<void> cancelar() async {
    if (!soportado) return;
    try {
      await _canal.invokeMethod('cancelar');
    } catch (e) {
      debugPrint('[Actualizacion] cancelar: $e');
    }
  }

  /// Cómo va la descarga actual.
  static Future<ProgresoActualizacion> estado() async {
    if (!soportado) return ProgresoActualizacion.inactivo;
    try {
      final crudo = await _canal.invokeMethod<String>('estado');
      final json = jsonDecode(crudo ?? '{}');
      if (json is Map<String, dynamic>) {
        return ProgresoActualizacion.desdeJson(json);
      }
    } catch (e) {
      debugPrint('[Actualizacion] estado: $e');
    }
    return ProgresoActualizacion.inactivo;
  }

  /// Las versiones que YA están en disco. Es lo que permite decir "ya la
  /// tenés descargada" en vez de volver a bajarla.
  static Future<List<VersionDescargada>> descargados() async {
    if (!soportado) return const [];
    try {
      final crudo = await _canal.invokeMethod<String>('descargados');
      final lista = jsonDecode(crudo ?? '[]');
      if (lista is List) {
        return lista
            .whereType<Map<String, dynamic>>()
            .map(VersionDescargada.desdeJson)
            .toList(growable: false);
      }
    } catch (e) {
      debugPrint('[Actualizacion] descargados: $e');
    }
    return const [];
  }

  /// ¿[version] ya está descargada? Devuelve el archivo si sí.
  static Future<VersionDescargada?> yaDescargada(String version) async {
    final todas = await descargados();
    for (final v in todas) {
      if (v.version == version) return v;
    }
    return null;
  }

  /// Borra los APKs de versiones viejas (y los `.parcial` de descargas
  /// cortadas). [conservar] es la versión que NO se toca.
  static Future<int> limpiarAntiguas({required String conservar}) async {
    if (!soportado) return 0;
    try {
      final borrados = await _canal.invokeMethod<int>('limpiar', {
        'conservar': conservar,
      });
      return borrados ?? 0;
    } catch (e) {
      debugPrint('[Actualizacion] limpiar: $e');
      return 0;
    }
  }

  /// Abre el instalador del sistema con el APK ya bajado.
  static Future<bool> instalar(String version) async {
    if (!soportado) return false;
    try {
      return await _canal.invokeMethod<bool>('instalar', {
            'version': version,
          }) ??
          false;
    } catch (e) {
      debugPrint('[Actualizacion] instalar: $e');
      return false;
    }
  }

  /// Aviso en la barra de notificaciones de que hay una versión nueva. Se
  /// manda una sola vez por versión (lo decide quien lo llama).
  static Future<void> notificar({
    required String version,
    required String texto,
  }) async {
    if (!soportado) return;
    try {
      await _canal.invokeMethod('notificar', {
        'version': version,
        'texto': texto,
      });
    } catch (e) {
      debugPrint('[Actualizacion] notificar: $e');
    }
  }

  /// Traduce la notificación: la dibuja Android, así que sus textos tienen que
  /// llegar desde el l10n de Flutter. Best-effort (si falla, el servicio usa
  /// sus textos por defecto).
  static Future<void> enviarTextos(AppLocalizations loc) async {
    if (!soportado) return;
    final t = loc.update;
    try {
      await _canal.invokeMethod('textos', {
        'descargando': t.descargando,
        'lista': t.notificacionLista,
        'fallo': t.notificacionFallo,
        'cancelar': t.cancelar,
        'instalar': t.instalar,
        'tocaInstalar': t.tocaInstalar,
        'tocaReintentar': t.tocaReintentar,
        'canal': t.canal,
        'canalDescripcion': t.canalDescripcion,
        'disponible': t.disponible,
      });
    } catch (e) {
      debugPrint('[Actualizacion] enviarTextos: $e');
    }
  }
}
