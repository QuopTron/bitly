import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/models/track.dart';
import 'package:bitly/screens/album/album_data_provider.dart';

/// Test wrapper that exercises AlbumDataNotifier.loadWithInitial from
/// initState — exactly like AlbumScreen did before the fix.
class AlbumTestWrapper extends ConsumerStatefulWidget {
  final List<Track>? initialTracks;
  const AlbumTestWrapper({super.key, this.initialTracks});

  @override
  ConsumerState<AlbumTestWrapper> createState() => _AlbumTestWrapperState();
}

class _AlbumTestWrapperState extends ConsumerState<AlbumTestWrapper> {
  final AlbumDataParams _params = AlbumDataParams(
    albumId: 'test_album',
    albumName: 'Test Album',
  );

  @override
  void initState() {
    super.initState();
    // This is exactly how AlbumScreen calls it — from initState.
    // The fix wraps everything in Future() to defer state = ...
    ref.read(albumDataProvider(_params).notifier)
        .loadWithInitial(ref, initialTracks: widget.initialTracks);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  final testTrack = Track(
    id: '1',
    name: 'Test Track',
    artistName: 'Test Artist',
    albumName: 'Test Album',
    duration: 200,
  );

  group('AlbumDataNotifier.loadWithInitial', () {
    testWidgets(
      'with initialTracks does not throw from initState',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: AlbumTestWrapper(initialTracks: [testTrack]),
            ),
          ),
        );

        // pump() processes the Future() microtask where state = ... happens.
        // pumpAndSettle() then waits for any remaining pending timers.
        await tester.pump();
        await tester.pumpAndSettle();

        // Critical assertion: the Future() wrapping should prevent
        // "Tried to modify a provider while the widget tree was building"
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'with empty initialTracks does not crash from initState',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: AlbumTestWrapper(initialTracks: []),
            ),
          ),
        );

        // pump() processes the Future() microtask which sets loading
        // state and starts _fetchWithFallback (fire-and-forget).
        // The fetch will use PlatformBridge which fails in the test
        // environment — but it's wrapped in try/catch, so no crash.
        await tester.pump();

        // Advancing time 10s lets any timeout timers from
        // _fetchWithFallback fire and settle.
        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });

  group('AlbumDataState', () {
    test('default values are correct', () {
      const state = AlbumDataState();
      expect(state.isLoading, isTrue);
      expect(state.tracks, isNull);
      expect(state.error, isNull);
      expect(state.hasTracks, isFalse);
    });

    test('hasTracks reflects tracks presence', () {
      final withTracks = AlbumDataState(tracks: [testTrack], isLoading: false);
      expect(withTracks.hasTracks, isTrue);
    });
  });

  group('AlbumDataParams', () {
    test('equality and hashCode work correctly', () {
      final a = AlbumDataParams(albumId: '123', albumName: 'Test');
      final b = AlbumDataParams(albumId: '123', albumName: 'Test');
      final c = AlbumDataParams(albumId: '456', albumName: 'Other');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });
}
