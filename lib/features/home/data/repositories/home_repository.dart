import 'package:flutter/material.dart';
import '../../domain/entities/home_section.dart';

class HomeRepository {
  Future<List<HomeSection>> getHomeSections() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      HomeSection(
        title: 'Descargas Recientes',
        type: SectionType.recent,
        items: [
          SectionItem(title: 'Canción 1', subtitle: 'Artista 1', icon: Icons.audiotrack),
          SectionItem(title: 'Canción 2', subtitle: 'Artista 2', icon: Icons.audiotrack),
          SectionItem(title: 'Canción 3', subtitle: 'Artista 3', icon: Icons.audiotrack),
        ],
      ),
      HomeSection(
        title: 'Acceso Rápido',
        type: SectionType.quickActions,
        items: [
          SectionItem(title: 'Buscar', subtitle: 'Encuentra música', icon: Icons.search),
          SectionItem(title: 'Descargar', subtitle: 'Desde URL', icon: Icons.download),
          SectionItem(title: 'Playlists', subtitle: 'Tu colección', icon: Icons.playlist_play),
          SectionItem(title: 'Favoritos', subtitle: 'Tus temas', icon: Icons.favorite),
        ],
      ),
      HomeSection(
        title: 'Descubrir',
        type: SectionType.discover,
        items: [
          SectionItem(title: 'Tendencias', subtitle: 'Lo más popular', icon: Icons.trending_up),
          SectionItem(title: 'Nuevos lanzamientos', subtitle: 'Recién salido', icon: Icons.new_releases),
        ],
      ),
    ];
  }

  Future<List<SectionItem>> getRecentDownloads() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      SectionItem(title: 'Canción 1', subtitle: 'Ayer', icon: Icons.audiotrack),
      SectionItem(title: 'Canción 2', subtitle: 'Hace 2 días', icon: Icons.audiotrack),
    ];
  }

  Future<List<SectionItem>> getQuickActions() async {
    return [
      SectionItem(title: 'Buscar', subtitle: 'Encuentra música', icon: Icons.search),
      SectionItem(title: 'Descargar', subtitle: 'Desde URL', icon: Icons.download),
    ];
  }
}
