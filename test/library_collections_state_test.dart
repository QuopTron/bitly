import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/providers/library/library_collections_state.dart';

void main() {
  group('LibraryCollectionsState.mergedAlbumCount', () {
    test('returns 0 when both lists are empty', () {
      final state = LibraryCollectionsState(isLoaded: true);
      expect(state.mergedAlbumCount, equals(0));
    });

    test('counts only favoriteAlbums when v2Albums is empty', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        favoriteAlbums: [
          CollectionAlbumEntry(
            key: 'a1',
            albumId: '1',
            providerId: 'tidal',
            name: 'Album 1',
            addedAt: _jan1,
          ),
          CollectionAlbumEntry(
            key: 'a2',
            albumId: '2',
            providerId: 'tidal',
            name: 'Album 2',
            addedAt: _jan2,
          ),
        ],
      );
      expect(state.mergedAlbumCount, equals(2));
    });

    test('counts only v2Albums when favoriteAlbums is empty', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        v2Albums: [
          CollectionAlbumEntry(
            key: 'v1',
            albumId: '10',
            providerId: null,
            name: 'V2 Album 1',
            addedAt: _jan1,
          ),
        ],
      );
      expect(state.mergedAlbumCount, equals(1));
    });

    test('deduplicates albums with same albumId across favorites and V2', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        favoriteAlbums: [
          CollectionAlbumEntry(
            key: 'a1',
            albumId: '1',
            providerId: 'tidal',
            name: 'Same Album',
            addedAt: _jan1,
          ),
        ],
        v2Albums: [
          CollectionAlbumEntry(
            key: 'v1',
            albumId: '1', // same as favorite — deduped
            providerId: null,
            name: 'Same Album',
            addedAt: _jan1,
          ),
          CollectionAlbumEntry(
            key: 'v2',
            albumId: '2', // unique V2 — included
            providerId: null,
            name: 'Only in V2',
            addedAt: _jan2,
          ),
        ],
      );
      expect(state.mergedAlbumCount, equals(2)); // 1 fav + 1 unique V2
    });

    test('counts all when there is no overlap between favorites and V2', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        favoriteAlbums: [
          CollectionAlbumEntry(
            key: 'a1',
            albumId: '1',
            providerId: 'tidal',
            name: 'Fav 1',
            addedAt: _jan1,
          ),
        ],
        v2Albums: [
          CollectionAlbumEntry(
            key: 'v1',
            albumId: '3',
            providerId: null,
            name: 'V2 1',
            addedAt: _jan1,
          ),
          CollectionAlbumEntry(
            key: 'v2',
            albumId: '4',
            providerId: null,
            name: 'V2 2',
            addedAt: _jan2,
          ),
        ],
      );
      expect(state.mergedAlbumCount, equals(3)); // 1 fav + 2 V2
    });

    test('handles all V2 albums overlapping with favorites', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        favoriteAlbums: [
          CollectionAlbumEntry(
            key: 'a1',
            albumId: '1',
            providerId: 'tidal',
            name: 'Album 1',
            addedAt: _jan1,
          ),
          CollectionAlbumEntry(
            key: 'a2',
            albumId: '2',
            providerId: 'tidal',
            name: 'Album 2',
            addedAt: _jan2,
          ),
        ],
        v2Albums: [
          CollectionAlbumEntry(
            key: 'v1',
            albumId: '1',
            providerId: null,
            name: 'Album 1',
            addedAt: _jan1,
          ),
          CollectionAlbumEntry(
            key: 'v2',
            albumId: '2',
            providerId: null,
            name: 'Album 2',
            addedAt: _jan2,
          ),
        ],
      );
      // V2 albums are all duplicates → only favorites count
      expect(state.mergedAlbumCount, equals(2));
    });
  });

  group('LibraryCollectionsState.mergedArtistCount', () {
    test('returns 0 when all sources are empty', () {
      final state = LibraryCollectionsState(isLoaded: true);
      expect(state.mergedArtistCount, equals(0));
    });

    test('counts artists from loved tracks using primaryArtistName', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        loved: [
          CollectionTrackEntry(
            key: 't1',
            track: Track(
              id: '1',
              name: 'Song 1',
              artistName: 'Artist A',
              albumName: 'Album',
              duration: 200,
            ),
            addedAt: _jan1,
          ),
          CollectionTrackEntry(
            key: 't2',
            track: Track(
              id: '2',
              name: 'Song 2',
              artistName: 'Artist B feaT. Guest',
              albumName: 'Album',
              duration: 180,
            ),
            addedAt: _jan1,
          ),
        ],
      );
      // 'Artist B feaT. Guest' → primaryArtistName extracts 'Artist B'
      expect(state.mergedArtistCount, equals(2));
    });

    test('counts artists from favoriteArtists', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        favoriteArtists: [
          CollectionArtistEntry(
            key: 'artist1',
            artistId: '1',
            providerId: 'tidal',
            name: 'Artist X',
            addedAt: _jan1,
          ),
          CollectionArtistEntry(
            key: 'artist2',
            artistId: '2',
            providerId: 'tidal',
            name: 'Artist Y',
            addedAt: _jan1,
          ),
        ],
      );
      expect(state.mergedArtistCount, equals(2));
    });

    test('counts artists from v2ArtistNames', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        v2ArtistNames: {'Artist P', 'Artist Q'},
      );
      expect(state.mergedArtistCount, equals(2));
    });

    test('deduplicates same artist name appearing in all three sources', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        loved: [
          CollectionTrackEntry(
            key: 't1',
            track: Track(
              id: '1',
              name: 'Song 1',
              artistName: 'Artist A',
              albumName: 'Album',
              duration: 200,
            ),
            addedAt: _jan1,
          ),
        ],
        favoriteArtists: [
          CollectionArtistEntry(
            key: 'artistA',
            artistId: 'a1',
            providerId: 'tidal',
            name: 'Artist A',
            addedAt: _jan1,
          ),
        ],
        v2ArtistNames: {'Artist A'},
      );
      // 'Artist A' in all 3 sources → count as 1
      expect(state.mergedArtistCount, equals(1));
    });

    test('merges unique artists from all three sources', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        loved: [
          CollectionTrackEntry(
            key: 't1',
            track: Track(
              id: '1',
              name: 'Song 1',
              artistName: 'Artist A',
              albumName: 'Album',
              duration: 200,
            ),
            addedAt: _jan1,
          ),
        ],
        favoriteArtists: [
          CollectionArtistEntry(
            key: 'artistB',
            artistId: 'b1',
            providerId: 'tidal',
            name: 'Artist B',
            addedAt: _jan1,
          ),
        ],
        v2ArtistNames: {'Artist C'},
      );
      expect(state.mergedArtistCount, equals(3));
    });

    test('deduplicates artists with feat. prefix from different loved tracks', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        loved: [
          CollectionTrackEntry(
            key: 't1',
            track: Track(
              id: '1',
              name: 'Song 1',
              artistName: 'Artist A feat. Guest',
              albumName: 'Album',
              duration: 200,
            ),
            addedAt: _jan1,
          ),
          CollectionTrackEntry(
            key: 't2',
            track: Track(
              id: '2',
              name: 'Song 2',
              artistName: 'Artist A',
              albumName: 'Album',
              duration: 180,
            ),
            addedAt: _jan2,
          ),
        ],
      );
      // Both extract to 'Artist A' via primaryArtistName → deduped to 1
      expect(state.mergedArtistCount, equals(1));
    });
  });

  group('LibraryCollectionsState.mergedArtistNames', () {
    test('returns empty set when all sources are empty', () {
      final state = LibraryCollectionsState(isLoaded: true);
      expect(state.mergedArtistNames, isEmpty);
    });

    test('mergedArtistCount matches mergedArtistNames.length and contains expected names', () {
      final state = LibraryCollectionsState(
        isLoaded: true,
        loved: [
          CollectionTrackEntry(
            key: 't1',
            track: Track(
              id: '1',
              name: 'Song 1',
              artistName: 'Artist A',
              albumName: 'Album',
              duration: 200,
            ),
            addedAt: _jan1,
          ),
        ],
        favoriteArtists: [
          CollectionArtistEntry(
            key: 'artistB',
            artistId: 'b1',
            providerId: 'tidal',
            name: 'Artist B',
            addedAt: _jan1,
          ),
        ],
        v2ArtistNames: {'Artist C'},
      );
      expect(state.mergedArtistCount, equals(state.mergedArtistNames.length));
      expect(state.mergedArtistNames, containsAll(['Artist A', 'Artist B', 'Artist C']));
    });
  });
}

// Top-level shared DateTimes for test entries
final _jan1 = DateTime(2024, 1, 1);
final _jan2 = DateTime(2024, 1, 2);
