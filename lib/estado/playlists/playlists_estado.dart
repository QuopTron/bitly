// ─────────────────────────────────────────────────────────────
// playlists_estado.dart — Estado del cubit de playlists: lista de
// playlists del usuario (ItemPlaylist, versión ligera con conteo de
// tracks y carátula), el detalle actual (DetallePlaylist con tracks),
// las stats del usuario y flags de carga/error. Incluye la conversión
// PlaylistDominio → ItemPlaylist.
// Se conecta con: cubit_playlists.dart (estado del cubit).
// Parte del flujo: playlists (Mi Espacio y detalle).
// ─────────────────────────────────────────────────────────────

part of 'cubit_playlists.dart';

/// Estado del cubit de playlists.
class EstadoPlaylists extends Equatable {
  final bool cargando;
  final List<ItemPlaylist> playlists;
  final DetallePlaylist? detalleActual;
  final EstadisticasUsuario? stats;
  final String? error;

  const EstadoPlaylists({
    this.cargando = false,
    this.playlists = const [],
    this.detalleActual,
    this.stats,
    this.error,
  });

  EstadoPlaylists copiarCon({
    bool? cargando,
    List<ItemPlaylist>? playlists,
    DetallePlaylist? detalleActual,
    EstadisticasUsuario? stats,
    String? error,
  }) =>
      EstadoPlaylists(
        cargando: cargando ?? this.cargando,
        playlists: playlists ?? this.playlists,
        detalleActual: detalleActual ?? this.detalleActual,
        stats: stats ?? this.stats,
        error: error,
      );

  @override
  List<Object?> get props => [cargando, playlists, detalleActual, stats, error];
}

/// Item ligero de playlist usado en [EstadoPlaylists.playlists].
class ItemPlaylist {
  final String id, name;
  final String? coverPath, createdAt, updatedAt;
  final int itemCount;

  const ItemPlaylist({
    required this.id,
    required this.name,
    this.coverPath,
    this.createdAt,
    this.updatedAt,
    this.itemCount = 0,
  });

  factory ItemPlaylist.desdeJson(Map<String, dynamic> json) => ItemPlaylist(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        coverPath: json['coverPath'] as String?,
        createdAt: json['createdAt'] as String?,
        updatedAt: json['updatedAt'] as String?,
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      );
}

/// Convierte un [PlaylistDominio] a un [ItemPlaylist] para el estado.
ItemPlaylist _dominioAItem(PlaylistDominio d) => ItemPlaylist(
      id: d.id,
      name: d.name,
      coverPath: d.coverUrl,
      createdAt: d.createdAt?.toIso8601String(),
      updatedAt: d.updatedAt?.toIso8601String(),
      itemCount: d.trackCount,
    );