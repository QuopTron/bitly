import 'package:flutter/material.dart';

// ── Real Deezer CDN album cover URLs ─────────────────────────────
const uvstCover = 'https://cdn-images.dzcdn.net/images/cover/b29d1070377b784384c2456093f96a66/250x250-000000-80-0-0.jpg';
const yhlqmdlgCover = 'https://cdn-images.dzcdn.net/images/cover/0a6f32569d4785c5ef82f581086f4302/250x250-000000-80-0-0.jpg';
const eltourCover = 'https://cdn-images.dzcdn.net/images/cover/6ea80078f0df08737a7471f3c4cf2afa/250x250-000000-80-0-0.jpg';
const badBunnyArtist = 'https://cdn-images.dzcdn.net/images/artist/044a3f315b041864887a8dd8709e6926/250x250-000000-80-0-0.jpg';
const rauwArtist = 'https://cdn-images.dzcdn.net/images/artist/0e7b2b93b91789a054bc3f08bb3df3a8/250x250-000000-80-0-0.jpg';
const jbalvinArtist = 'https://cdn-images.dzcdn.net/images/artist/325eaa46bc25052d0e3d549d60cc8225/250x250-000000-80-0-0.jpg';
const playlistVerano = 'https://cdn-images.dzcdn.net/images/playlist/19968a720110493a0496dfe8a1b7013d/250x250-000000-80-0-0.jpg';
const playlistFavs = 'https://cdn-images.dzcdn.net/images/cover/6c9a6046dc369375ee5181480bcc4962-e0dd8263dfed37c50a868abbf65fd7da-d74bc3362822f21125e1bc5778e3cd13-891aea0a33f3ff28912187a50cb94738/250x250-000000-80-0-0.jpg';
const playlistGym = 'https://cdn-images.dzcdn.net/images/playlist/5f55d4c9033ff8e3b4bf5aa9f40c99d1/250x250-000000-80-0-0.jpg';

// ── Types ────────────────────────────────────────────────────────

enum DemoItemType { song, playlist, album, artist }

class DemoItem {
  final String title;
  final String artist;
  final DemoItemType type;
  final String tag;
  final String? coverUrl;
  const DemoItem(this.title, this.artist, this.type, this.tag, {this.coverUrl});
}

class TabDef {
  final String label;
  final IconData icon;
  final DemoItemType type;
  const TabDef(this.label, this.icon, this.type);
}

const demoFilterOptions = <DemoItemType, List<String>>{
  DemoItemType.song: ['Todas', 'Recién', 'Favoritas', 'Descargadas', 'Escuchadas'],
  DemoItemType.playlist: ['Todas', 'Creadas', 'Guardadas'],
  DemoItemType.album: ['Todos', 'Completos', 'Pendientes'],
  DemoItemType.artist: ['Todos', 'Seguidos', 'Populares'],
};

const demoTabs = [
  TabDef('Canciones', Icons.music_note, DemoItemType.song),
  TabDef('Playlists', Icons.queue_music, DemoItemType.playlist),
  TabDef('Álbumes', Icons.album, DemoItemType.album),
  TabDef('Artistas', Icons.person, DemoItemType.artist),
];

const demoSongs = [
  DemoItem('Dákiti', 'Bad Bunny', DemoItemType.song, 'Recién', coverUrl: eltourCover),
  DemoItem('Monaco', 'Bad Bunny', DemoItemType.song, 'Favoritas', coverUrl: uvstCover),
  DemoItem('Tití Me Preguntó', 'Bad Bunny', DemoItemType.song, 'Recién', coverUrl: uvstCover),
  DemoItem('Neverita', 'Bad Bunny', DemoItemType.song, 'Descargadas', coverUrl: uvstCover),
  DemoItem('Efecto', 'Bad Bunny', DemoItemType.song, 'Descargadas', coverUrl: uvstCover),
  DemoItem('Ojitos Lindos', 'Bad Bunny', DemoItemType.song, 'Favoritas', coverUrl: uvstCover),
  DemoItem('Me Porto Bonito', 'Bad Bunny', DemoItemType.song, 'Recién', coverUrl: uvstCover),
  DemoItem('Un Verano Sin Ti', 'Bad Bunny', DemoItemType.song, 'Escuchadas', coverUrl: uvstCover),
];

const demoPlaylists = [
  DemoItem('Verano Hits', '8 canciones', DemoItemType.playlist, 'Creadas', coverUrl: playlistVerano),
  DemoItem('Favoritas 2026', '12 canciones', DemoItemType.playlist, 'Creadas', coverUrl: playlistFavs),
  DemoItem('Para Gym', '20 canciones', DemoItemType.playlist, 'Guardadas', coverUrl: playlistGym),
];

const demoAlbums = [
  DemoItem('Un Verano Sin Ti', 'Bad Bunny · 2022', DemoItemType.album, 'Completos', coverUrl: uvstCover),
  DemoItem('YHLQMDLG', 'Bad Bunny · 2020', DemoItemType.album, 'Completos', coverUrl: yhlqmdlgCover),
  DemoItem('El Último Tour', 'Bad Bunny · 2020', DemoItemType.album, 'Pendientes', coverUrl: eltourCover),
];

const demoArtists = [
  DemoItem('Bad Bunny', '8 canciones', DemoItemType.artist, 'Seguidos', coverUrl: badBunnyArtist),
  DemoItem('Rauw Alejandro', '3 canciones', DemoItemType.artist, 'Seguidos', coverUrl: rauwArtist),
  DemoItem('J Balvin', '5 canciones', DemoItemType.artist, 'Populares', coverUrl: jbalvinArtist),
];

const demoSongCovers = [
  eltourCover, uvstCover, uvstCover, uvstCover,
  uvstCover, uvstCover, uvstCover, uvstCover,
];

