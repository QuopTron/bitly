import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/providers/explore/explore_state.dart';
import 'package:bitly/screens/album/album_screen.dart';

/// Simula la lógica de _navigateToItem de explore_section_widget.dart.
/// Navega a AlbumScreen con albumId = item.albumId ?? item.id.
void navigateToAlbum(BuildContext context, ExploreItem item) {
  Navigator.push(context, MaterialPageRoute<void>(
    builder: (_) => AlbumScreen(
      albumId: item.albumId ?? item.id,
      albumName: item.name,
      coverUrl: item.coverUrl,
      extensionId: item.providerId,
      artistName: item.artists.isNotEmpty ? item.artists : null,
    ),
  ));
}

/// Helper que construye un ExploreItem desde un Map.
ExploreItem itemFromMap(Map<String, dynamic> json) =>
    ExploreItem.fromJson(json);

void main() {
  group('ExploreItem.fromJson — album_id parsing', () {
    test('parses album_id from JSON payload with spotify:album URI', () {
      // Simula un item de browse categories que pasó por la normalización Go.
      // El Go backend extrajo album_id de la URI spotify:album:XXXXX.
      const albumId = '4iHNK0tOyZPYnBU7nGAgpQ';
      final item = itemFromMap({
        'id': 'some-track-id',
        'uri': 'spotify:album:$albumId',
        'type': 'album',
        'name': 'Test Album',
        'artists': 'Test Artist',
        'album_id': albumId,
        'cover_url': 'https://example.com/cover.jpg',
        'provider_id': 'spotify-web',
      });

      expect(item.albumId, equals(albumId));
      expect(item.type, equals('album'));
      expect(item.uri, equals('spotify:album:$albumId'));
    });

    test('parses album_id from JSON with Tidal URL format', () {
      // La normalización también maneja URLs de Tidal.
      const albumId = '123456789';
      final item = itemFromMap({
        'id': 'tidal:album:$albumId',
        'uri': 'https://tidal.com/browse/album/$albumId',
        'type': 'album',
        'name': 'Tidal Album',
        'artists': 'Tidal Artist',
        'album_id': albumId,
        'provider_id': 'tidal-monochrome',
      });

      expect(item.albumId, equals(albumId));
    });

    test('album_id is null when not present in JSON', () {
      // Item del browse feed devuelto por una extensión que NO incluye album_id.
      // Este es el escenario que la normalización Go busca solucionar.
      final item = itemFromMap({
        'id': 'album-123',
        'uri': 'spotify:album:album-123',
        'type': 'album',
        'name': 'Untitled Album',
        'artists': 'Some Artist',
        'cover_url': null,
        'provider_id': 'spotify-web',
        // Sin album_id — la extensión no lo proveyó.
      });

      expect(item.albumId, isNull);
      expect(item.id, equals('album-123'));
    });

    test('album_id is null for non-album item types', () {
      final item = itemFromMap({
        'id': 'playlist-1',
        'uri': 'spotify:playlist:abc123',
        'type': 'playlist',
        'name': 'Cool Playlist',
        'artists': 'Curator',
        'provider_id': 'spotify-web',
      });

      expect(item.type, equals('playlist'));
      expect(item.albumId, isNull); // Las playlists no tienen album_id
    });

    test('toJson / fromJson roundtrip preserves album_id', () {
      const albumId = 'deezer:album:98765';
      final original = ExploreItem(
        id: 'track-1',
        uri: 'deezer:album:98765',
        type: 'album',
        name: 'Roundtrip Album',
        artists: 'Roundtrip Artist',
        albumId: albumId,
      );

      final json = original.toJson();
      final restored = ExploreItem.fromJson(json);

      expect(restored.albumId, equals(albumId));
      expect(restored.id, equals(original.id));
      expect(restored.type, equals(original.type));
      expect(restored.name, equals(original.name));
      expect(restored.uri, equals(original.uri));
    });
  });

  group('Navigation — browse category item to AlbumScreen', () {
    testWidgets('navigates with album_id when present', (tester) async {
      const albumId = '4iHNK0tOyZPYnBU7nGAgpQ';
      const albumName = 'Test Album';
      final item = ExploreItem(
        id: 'some-id',
        uri: 'spotify:album:$albumId',
        type: 'album',
        name: albumName,
        artists: 'Test Artist',
        albumId: albumId,
        coverUrl: 'https://example.com/cover.jpg',
        providerId: 'spotify-web',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () => navigateToAlbum(context, item),
                child: const Text('Go'),
              );
            }),
          ),
        ),
      );

      // Tap para navegar
      await tester.tap(find.text('Go'));
      await tester.pump();
      // Flush the Future microtask from loadWithInitial
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verificar que AlbumScreen se abrió con el albumId correcto
      final albumScreen = tester.widget<AlbumScreen>(find.byType(AlbumScreen));
      expect(albumScreen.albumId, equals(albumId));
      expect(albumScreen.albumName, equals(albumName));
    });

    testWidgets('falls back to item.id when album_id is null', (tester) async {
      // Simula un item sin album_id — debe caer en item.id
      const fallbackId = 'album-fallback-id';
      final item = ExploreItem(
        id: fallbackId,
        uri: 'spotify:album:$fallbackId',
        type: 'album',
        name: 'Fallback Album',
        artists: 'Fallback Artist',
        albumId: null, // Sin album_id
        coverUrl: null,
        providerId: 'spotify-web',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () => navigateToAlbum(context, item),
                child: const Text('Go'),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verificar que AlbumScreen recibe item.id como albumId
      final albumScreen = tester.widget<AlbumScreen>(find.byType(AlbumScreen));
      expect(albumScreen.albumId, equals(fallbackId));
    });

    testWidgets('album_id takes priority over item.id', (tester) async {
      // Cuando ambos existen, album_id debe usarse (no item.id)
      const albumId = 'preferred-album-id';
      const itemId = 'inferior-item-id';
      final item = ExploreItem(
        id: itemId,
        uri: 'deezer:album:$albumId',
        type: 'album',
        name: 'Priority Album',
        artists: 'Priority Artist',
        albumId: albumId,
        providerId: 'deezer',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(builder: (context) {
              return ElevatedButton(
                onPressed: () => navigateToAlbum(context, item),
                child: const Text('Go'),
              );
            }),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final albumScreen = tester.widget<AlbumScreen>(find.byType(AlbumScreen));
      expect(albumScreen.albumId, equals(albumId));
      expect(albumScreen.albumId, isNot(equals(itemId)));
    });
  });
}
