import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/features/setup/widgets/feed_preview_source_selector.dart';
import 'package:bitly/frontend/shared/constants/source_constants.dart';

IconData _mockSourceIcon(String src) {
  switch (src) {
    case 'deezer': return Icons.library_music;
    case 'spotify-web': return Icons.music_note;
    default: return Icons.music_video;
  }
}

void main() {
  group('FeedPreviewSourceSelector', () {
    testWidgets('renders icon-only accordion trigger when sources exist',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedPreviewSourceSelector(
              selectedSource: 'deezer',
              availableSources: {'deezer': 'Deezer'},
              sourceIcon: _mockSourceIcon,
              onChanged: (_) {},
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      // The trigger is a circular icon button — the source name is only
      // revealed inside the popup once opened.
      expect(find.byIcon(sourceIcons['deezer']!), findsOneWidget);
      expect(find.text('Deezer'), findsNothing);
    });

    testWidgets('renders nothing when sources map is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedPreviewSourceSelector(
              selectedSource: '',
              availableSources: {},
              sourceIcon: _mockSourceIcon,
              onChanged: (_) {},
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(sourceIcons['deezer']!), findsNothing);
      expect(find.text('Deezer'), findsNothing);
    });

    testWidgets('calls onChanged when a source is selected from the popup',
        (tester) async {
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedPreviewSourceSelector(
              selectedSource: 'deezer',
              availableSources: {'deezer': 'Deezer', 'spotify-web': 'Spotify'},
              sourceIcon: _mockSourceIcon,
              onChanged: (v) => selected = v,
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      // Open the accordion via the icon-only trigger.
      await tester.tap(find.byIcon(sourceIcons['deezer']!));
      await tester.pumpAndSettle();

      // Tap the 'Spotify' row in the popup.
      await tester.tap(find.text('Spotify').last);
      await tester.pumpAndSettle();

      expect(selected, 'spotify-web');
    });

    testWidgets('shows source icons in popup rows', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedPreviewSourceSelector(
              selectedSource: 'deezer',
              availableSources: {'deezer': 'Deezer', 'spotify-web': 'Spotify'},
              sourceIcon: _mockSourceIcon,
              onChanged: (_) {},
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(sourceIcons['deezer']!));
      await tester.pumpAndSettle();

      // Popup rows show each source's own icon (from sourceIcons, not the mock).
      expect(find.byIcon(Icons.library_music), findsWidgets);
      expect(find.byIcon(Icons.music_note), findsWidgets);
    });

    testWidgets('adapts to dark theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: FeedPreviewSourceSelector(
              selectedSource: 'deezer',
              availableSources: {'deezer': 'Deezer'},
              sourceIcon: _mockSourceIcon,
              onChanged: (_) {},
              onBg: Colors.white,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(sourceIcons['deezer']!), findsOneWidget);
    });
  });
}