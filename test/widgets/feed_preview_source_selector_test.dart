import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/features/setup/widgets/feed_preview_source_selector.dart';

IconData _mockSourceIcon(String src) {
  switch (src) {
    case 'deezer': return Icons.library_music;
    case 'spotify-web': return Icons.music_note;
    default: return Icons.music_video;
  }
}

void main() {
  group('FeedPreviewSourceSelector', () {
    testWidgets('renders accordion header when sources exist', (tester) async {
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

      expect(find.text('Deezer'), findsOneWidget);
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

      expect(find.text('Deezer'), findsNothing);
    });

    testWidgets('calls onChanged when a source chip is selected',
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

      // Open the accordion.
      await tester.tap(find.text('Deezer'));
      await tester.pumpAndSettle();

      // Tap the 'Spotify' chip.
      await tester.tap(find.text('Spotify').last);
      await tester.pumpAndSettle();

      expect(selected, 'spotify-web');
    });

    testWidgets('shows source icons in chips', (tester) async {
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

      await tester.tap(find.text('Deezer'));
      await tester.pumpAndSettle();

      // Chip icons come from SourceAccordion's own sourceIcons map.
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

      expect(find.text('Deezer'), findsOneWidget);
    });
  });
}
