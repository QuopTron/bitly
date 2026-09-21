// ─────────────────────────────────────────────────────────────
// playlists_estado.dart — Estado del cubit de playlists: lista de
// playlists del usuario (ItemPlaylist, versión ligera con conteo de
// tracks y carátula), las stats del usuario y el flag de carga.
// Incluye la conversión PlaylistDominio → ItemPlaylist.
// Se conecta con: cubit_playlists.dart (estado del cubit).
// Parte del flujo: playlists (Mi Espacio).
// ─────────────────────────────────────────────────────────────

part of 'cubit_playlists.dart';

/// Estado del cubit de playlists.
class EstadoPlaylists extends Equatable {
  final bool cargando;
  final List<ItemPlaylist> playlists;
  final EstadisticasUsuario? stats;

  const EstadoPlaylists({
    this.cargando = false,
    this.playlists = const [],
    this.stats,
  });

  EstadoPlaylists copiarCon({
    bool? cargando,
    List<ItemPlaylist>? playlists,
    EstadisticasUsuario? stats,
  }) => EstadoPlaylists(
    cargando: cargando ?? this.cargando,
    playlists: playlists ?? this.playlists,
    stats: stats ?? this.stats,
  );

  @override
  List<Object?> get props => [cargando, playlists, stats];
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
