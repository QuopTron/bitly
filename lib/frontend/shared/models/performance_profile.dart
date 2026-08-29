import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../injection.dart';

/// Current global "heavy effects" flag from the performance profile. Kept in
/// one place so every render widget reads the same value instead of each file
/// re-declaring its own copied getter.
bool get heavyEffects {
  try {
    return sl<ValueNotifier<PerformanceProfile>>().value.heavyEffects;
  } catch (_) {
    return true;
  }
}

/// Niveles de perfil de rendimiento del dispositivo.
enum PerfLevel { low, medium, high }

extension PerfLevelX on PerfLevel {
  String get key => switch (this) {
    PerfLevel.low => 'low',
    PerfLevel.medium => 'medium',
    PerfLevel.high => 'high',
  };

  static PerfLevel fromKey(String? key) => switch (key) {
    'low' => PerfLevel.low,
    'high' => PerfLevel.high,
    _ => PerfLevel.medium,
  };
}

/// Perfil de rendimiento adaptativo entre gama baja (Helio G90) y
/// desktop potente (RTX 5090). Cada perfil ajusta la carga de trabajo:
/// concurrencia de descargas, buffer de streaming, calidad de audio,
/// precarga, resolución de carátulas y uso de caché.
@immutable
class PerformanceProfile {
  final PerfLevel level;

  /// Descargas simultáneas (concurrencia backend Go).
  final int downloadConcurrency;

  /// Tamaño de chunk de streaming (bytes).
  final int streamChunkSize;

  /// Calidad de audio por defecto para descarga/streaming.
  final String audioQuality;

  /// Nº de tracks que se precargan tras el actual.
  final int preloadTracks;

  /// Resolución de carátulas (px). Bajo usa thumbnails pequeños.
  final int coverResolution;

  /// Límite de caché de streaming en MB.
  final int streamCacheMaxMb;

  /// TTL del cache de chunks de streaming.
  final Duration streamCacheTtl;

  /// Si habilitar precarga de la siguiente pista.
  final bool preloadEnabled;

  /// Si habilitar efectos visuales pesados (blur/glass/sombras).
  final bool heavyEffects;

  /// Si las listas usan construcción perezosa (builder) y paginación.
  final bool lazyLists;

  const PerformanceProfile({
    required this.level,
    required this.downloadConcurrency,
    required this.streamChunkSize,
    required this.audioQuality,
    required this.preloadTracks,
    required this.coverResolution,
    required this.streamCacheMaxMb,
    required this.streamCacheTtl,
    required this.preloadEnabled,
    required this.heavyEffects,
    required this.lazyLists,
  });

  static const low = PerformanceProfile(
    level: PerfLevel.low,
    downloadConcurrency: 1,
    streamChunkSize: 128 * 1024,
    audioQuality: 'medium',
    preloadTracks: 0,
    coverResolution: 250,
    streamCacheMaxMb: 128,
    streamCacheTtl: Duration(minutes: 2),
    preloadEnabled: false,
    heavyEffects: false,
    lazyLists: true,
  );

  static const medium = PerformanceProfile(
    level: PerfLevel.medium,
    downloadConcurrency: 3,
    streamChunkSize: 256 * 1024,
    audioQuality: 'hifi',
    preloadTracks: 2,
    coverResolution: 500,
    streamCacheMaxMb: 400,
    streamCacheTtl: Duration(minutes: 5),
    preloadEnabled: true,
    heavyEffects: true,
    lazyLists: true,
  );

  static const high = PerformanceProfile(
    level: PerfLevel.high,
    downloadConcurrency: 6,
    streamChunkSize: 512 * 1024,
    audioQuality: 'flac',
    preloadTracks: 4,
    coverResolution: 900,
    streamCacheMaxMb: 1000,
    streamCacheTtl: Duration(minutes: 10),
    preloadEnabled: true,
    heavyEffects: true,
    lazyLists: false,
  );

  static const values = [low, medium, high];

  static PerformanceProfile forLevel(PerfLevel level) => switch (level) {
    PerfLevel.low => low,
    PerfLevel.medium => medium,
    PerfLevel.high => high,
  };
}
