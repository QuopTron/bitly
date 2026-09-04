import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bitly/frontend/features/feed/widgets/feed_header.dart';
import 'package:bitly/frontend/features/feed/bloc/feed_bloc.dart';
import 'package:bitly/frontend/shared/widgets/source_accordion.dart';
import 'package:bitly/frontend/features/feed/bloc/feed_state.dart';
import 'package:bitly/backend/rpc/backend_service.dart';
import 'package:bitly/frontend/l10n/app_localizations.dart';

class _MockBackend extends Mock implements BackendService {}

/// Helper: builds widget tree, emits state after mount, pumps again.
Future<void> pumpWithState(
  WidgetTester tester, {
  required FeedBloc bloc,
  required FeedState state,
  Map<String, String> sources = const {},
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: BlocProvider<FeedBloc>.value(
            value: bloc,
            child: FeedHeader(
              onBg: Colors.black,
              glowColor: Colors.green,
              sources: sources,
            ),
          ),
        ),
      ),
    ),
  );
  // Emit AFTER mounting so BlocProvider propagates the state
  bloc.emit(state);
  await tester.pump();
}

void main() {
  late _MockBackend backend;
  late FeedBloc bloc;

  setUp(() {
    backend = _MockBackend();
    bloc = FeedBloc(backend);
  });

  tearDown(() {
    bloc.close();
  });

  group('FeedHeader', () {
    testWidgets('shows greeting with username when provided', (tester) async {
      await pumpWithState(
        tester,
        bloc: bloc,
        state: const FeedState(username: 'Alice', selectedSource: ''),
        sources: {},
      );

      expect(find.textContaining('Alice'), findsOneWidget);
    });

    testWidgets('shows greeting without username when empty', (tester) async {
      await pumpWithState(
        tester,
        bloc: bloc,
        state: const FeedState(username: ''),
        sources: {},
      );

      // No comma after greeting when username empty
      expect(find.textContaining(','), findsNothing);
    });

    testWidgets('shows source accordion when sources are available',
        (tester) async {
      await pumpWithState(
        tester,
        bloc: bloc,
        state: const FeedState(selectedSource: 'deezer'),
        sources: {'deezer': 'Deezer', 'spotify-web': 'Spotify'},
      );

      // The accordion trigger is an icon-only circular button now (the
      // source NAME only appears inside the floating list when opened).
      expect(find.byType(SourceAccordion), findsOneWidget);
      expect(find.text('Todas las fuentes'), findsNothing);
    });

    testWidgets('hides source accordion when sources are empty',
        (tester) async {
      await pumpWithState(
        tester,
        bloc: bloc,
        state: const FeedState(),
        sources: {},
      );

      expect(find.byType(SourceAccordion), findsNothing);
      expect(find.text('Todas las fuentes'), findsNothing);
    });

    testWidgets('changing source dispatches FeedSourceChanged',
        (tester) async {
      await pumpWithState(
        tester,
        bloc: bloc,
        state: const FeedState(selectedSource: 'deezer'),
        sources: {'deezer': 'Deezer', 'spotify-web': 'Spotify'},
      );

      // Open the accordion: tap the trigger (icon button, no label).
      await tester.tap(find.byType(SourceAccordion));
      await tester.pumpAndSettle();

      // The floating list shows the source names — tap 'Spotify'.
      await tester.tap(find.text('Spotify').last);
      await tester.pumpAndSettle();

      expect(bloc.state.selectedSource, 'spotify-web');
    });
  });
}
