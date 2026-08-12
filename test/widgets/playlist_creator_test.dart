import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/features/setup/widgets/profile_tutorial_playlist_creator.dart';

void main() {
  group('PlaylistCreator', () {
    testWidgets('renders section title and song count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: PlaylistCreator(
                selectedForPlaylist: {},
                onToggle: (_) {},
                onBg: Colors.black,
                glowColor: Colors.green,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Selecciona canciones'), findsOneWidget);
      expect(find.textContaining('0 seleccionadas'), findsOneWidget);
    });

    testWidgets('renders demo song items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: PlaylistCreator(
                selectedForPlaylist: {},
                onToggle: (_) {},
                onBg: Colors.black,
                glowColor: Colors.green,
              ),
            ),
          ),
        ),
      );

      // Should find numbered items (1, 2, 3, ...)
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('toggles selection on tap', (tester) async {
      Set<int> selected = {};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: PlaylistCreator(
                selectedForPlaylist: selected,
                onToggle: (i) => selected = {i},
                onBg: Colors.black,
                glowColor: Colors.green,
              ),
            ),
          ),
        ),
      );

      // Tap first item
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      expect(selected, {0});
    });

    testWidgets('shows selected count when items are selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: PlaylistCreator(
                selectedForPlaylist: {0, 1},
                onToggle: (_) {},
                onBg: Colors.black,
                glowColor: Colors.green,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('2 seleccionadas'), findsOneWidget);
    });
  });

  group('CreatePlaylistButton', () {
    testWidgets('shows create state by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatePlaylistButton(
              showCreator: false,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Crear playlist'), findsOneWidget);
    });

    testWidgets('shows confirm state when creator is open', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatePlaylistButton(
              showCreator: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Confirmar playlist'), findsOneWidget);
    });

    testWidgets('calls onToggle on tap', (tester) async {
      bool toggled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatePlaylistButton(
              showCreator: false,
              onToggle: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Crear playlist'));
      expect(toggled, isTrue);
    });

    testWidgets('shows playlist_add icon when closed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatePlaylistButton(
              showCreator: false,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.playlist_add), findsOneWidget);
    });

    testWidgets('shows check_circle_outline icon when open', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CreatePlaylistButton(
              showCreator: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });
}

