// ─────────────────────────────────────────────────────────────
// perfil_rendimiento.dart — Perfil de rendimiento adaptativo según
// el dispositivo (bajo/medio/alto): concurrencia de descargas,
// buffer de streaming, calidad de audio, precarga, carátulas, caché.
// Se conecta con: backend_go (syncBackendConfig envía estos valores)
// y la UI (efectos pesados, blur de fondo).
// Parte del flujo: arranque (loadRuntimeProfile) + Ajustes → Rendimiento.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';

/// Niveles de perfil de rendimiento del dispositivo.
enum NivelRendimiento { bajo, medio, alto }

extension NivelRendimientoExt on NivelRendimiento {
  String get clave => switch (this) {
    NivelRendimiento.bajo => 'low',
    NivelRendimiento.medio => 'medium',
    NivelRendimiento.alto => 'high',
  };

  static NivelRendimiento desdeClave(String? clave) => switch (clave) {
    'low' => NivelRendimiento.bajo,
    'high' => NivelRendimiento.alto,
    _ => NivelRendimiento.medio,
  };
}

/// Perfil de rendimiento adaptativo entre gama baja (Helio G90) y desktop
/// potente (RTX 5090). Cada perfil ajusta la carga de trabajo: concurrencia
/// de descargas, buffer de streaming, calidad de audio, precarga, resolución
/// de carátulas y uso de caché.
@immutable
class PerfilRendimiento {
  final NivelRendimiento nivel;

  /// Descargas simultáneas (concurrencia backend Go).
  final int concurrenciaDescargas;

  /// Tamaño de chunk de streaming (bytes).
  final int tamanoChunkStreaming;

  /// Calidad de audio por defecto para descarga/streaming.
  final String calidadAudio;

  /// Nº de tracks que se precargan tras el actual.
  final int precargaTracks;

  /// Resolución de carátulas (px). Bajo usa thumbnails pequeños.
  final int resolucionCaratulas;

  /// Límite de caché de streaming en MB.
  final int cacheStreamingMaxMb;

  /// TTL del cache de chunks de streaming.
  final Duration cacheStreamingTtl;

  /// Si habilitar precarga de la siguiente pista.
  final bool precargaHabilitada;

  /// Si habilitar efectos visuales pesados (blur/glass/sombras).
  final bool efectosPesados;

  /// Si las listas usan construcción perezosa (builder) y paginación.
  final bool listasPerezosas;

  /// Sigma del desenfoque de fondos: bajo en perfiles sin efectos pesados
  /// y según plataforma (móvil más liviano que escritorio).
  double get sigmaDesenfoque {
    if (!efectosPesados) return 10;
    final movil = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    return movil ? 26 : 48;
  }

  const PerfilRendimiento({
    required this.nivel,
    required this.concurrenciaDescargas,
    required this.tamanoChunkStreaming,
    required this.calidadAudio,
    required this.precargaTracks,
    required this.resolucionCaratulas,
    required this.cacheStreamingMaxMb,
    required this.cacheStreamingTtl,
    required this.precargaHabilitada,
    required this.efectosPesados,
    required this.listasPerezosas,
  });

  static const bajo = PerfilRendimiento(
    nivel: NivelRendimiento.bajo,
    concurrenciaDescargas: 1,
    tamanoChunkStreaming: 128 * 1024,
    calidadAudio: 'medium',
    precargaTracks: 0,
    resolucionCaratulas: 250,
    cacheStreamingMaxMb: 128,
    cacheStreamingTtl: Duration(minutes: 2),
    precargaHabilitada: false,
    efectosPesados: false,
    listasPerezosas: true,
  );

  static const medio = PerfilRendimiento(
    nivel: NivelRendimiento.medio,
    concurrenciaDescargas: 3,
    tamanoChunkStreaming: 256 * 1024,
    calidadAudio: 'hifi',
    precargaTracks: 2,
    resolucionCaratulas: 500,
    cacheStreamingMaxMb: 400,
    cacheStreamingTtl: Duration(minutes: 5),
    precargaHabilitada: true,
    efectosPesados: true,
    listasPerezosas: true,
  );

  static const alto = PerfilRendimiento(
    nivel: NivelRendimiento.alto,
    concurrenciaDescargas: 6,
    tamanoChunkStreaming: 512 * 1024,
    calidadAudio: 'flac',
    precargaTracks: 4,
    resolucionCaratulas: 900,
    cacheStreamingMaxMb: 1000,
    cacheStreamingTtl: Duration(minutes: 10),
    precargaHabilitada: true,
    efectosPesados: true,
    listasPerezosas: false,
  );

  static const valores = [bajo, medio, alto];

  static PerfilRendimiento paraNivel(NivelRendimiento nivel) => switch (nivel) {
    NivelRendimiento.bajo => bajo,
    NivelRendimiento.medio => medio,
    NivelRendimiento.alto => alto,
  };
}