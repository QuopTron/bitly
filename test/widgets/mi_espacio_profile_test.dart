import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/features/miespacio/mi_espacio_profile.dart';
import 'package:bitly/frontend/l10n/app_localizations.dart';

void main() {
  group('MiEspacioProfile', () {
    Widget buildTest({required String username, int loved = 0, int playlists = 0}) {
      return MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate],
        home: Scaffold(
          body: MiEspacioProfile(
            username: username,
            lovedSongsCount: loved,
            playlistsCount: playlists,
            onBg: Colors.black,
            glowColor: Colors.green,
          ),
        ),
      );
    }

    testWidgets('shows avatar circle', (tester) async {
      await tester.pumpWidget(buildTest(username: 'TestUser'));
      await tester.pump();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('shows username when provided', (tester) async {
      await tester.pumpWidget(buildTest(username: 'Alice'));
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('shows guest fallback when username is empty', (tester) async {
      await tester.pumpWidget(buildTest(username: ''));
      await tester.pump();

      expect(find.text('Guest'), findsOneWidget);
    });

    testWidgets('shows song and playlist counts', (tester) async {
      await tester.pumpWidget(buildTest(username: 'User', loved: 5, playlists: 3));
      await tester.pump();

      expect(find.textContaining('5 songs'), findsOneWidget);
    });

    testWidgets('shows loved songs badge when count > 0', (tester) async {
      await tester.pumpWidget(buildTest(username: 'User', loved: 10));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('hides loved badge when count is 0', (tester) async {
      await tester.pumpWidget(buildTest(username: 'User', loved: 0));
      await tester.pump();

      expect(find.byIcon(Icons.favorite), findsNothing);
    });
  });
}

