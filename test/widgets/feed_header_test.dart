import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bitly/features/feed/widgets/cabecera_feed.dart';
import 'package:bitly/features/feed/bloc/feed_bloc.dart';
import 'package:bitly/shared/widgets/acordeon_fuente.dart';
import 'package:bitly/features/feed/bloc/feed_estado.dart';
import 'package:bitly/core/backend_go/contrato_backend.dart';
import 'package:bitly/l10n/app_localizations.dart';

class _MockBackend extends Mock implements BackendService {}

/// Helper: builds widget tree, emits state after mount, pumps again.
Future<void> pumpWithState(
  WidgetTester tester, {
  required BlocFeed bloc,
  required EstadoFeed state,
  Map<String, String> sources = const {},
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate],
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: BlocProvider<BlocFeed>.value(
            value: bloc,
            child: CabeceraFeed(
              onBg: Colors.black,
              colorBrillo: Colors.green,
              fuentes: sources,
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
  late BlocFeed bloc;

  setUp(() {
    backend = _MockBackend();
    bloc = BlocFeed(backend);
  });

  tearDown(() {
    bloc.close();
  });

  group('CabeceraFeed', () {
    testWidgets('shows greeting with username when provided', (tester) async {
      await pumpWithState(
        tester,
        bloc: bloc,
        state: const EstadoFeed(usuario: 'Alice'),
        sources: {},
      );

      expect(find.textContaining('Alice'), findsOneWidget);
    });

    testWidgets('shows greeting without username when empty', (tester) async {
      await pumpWithState(
        tester,
        bloc: bloc,
        state: const EstadoFeed(),
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
        state: const EstadoFeed(fuenteSeleccionada: 'deezer'),
        sources: {'deezer': 'Deezer', 'spotify-web': 'Spotify'},
      );

      // The accordion trigger is an icon-only circular button now (the
      // source NAME only appears inside the floating list when opened).
      expect(find.byType(AcordeonFuente), findsOneWidget);
      expect(find.text('Todas las fuentes'), findsNothing);
    });

    testWidgets('hides source accordion when sources are empty',
        (tester) async {
      await pumpWithState(
        tester,
        bloc: bloc,
        state: const EstadoFeed(),
        sources: {},
      );

      expect(find.byType(AcordeonFuente), findsNothing);
      expect(find.text('Todas las fuentes'), findsNothing);
    });

    testWidgets('changing source dispatches FuenteFeedCambiada',
        (tester) async {
      await pumpWithState(
        tester,
        bloc: bloc,
        state: const EstadoFeed(fuenteSeleccionada: 'deezer'),
        sources: {'deezer': 'Deezer', 'spotify-web': 'Spotify'},
      );

      // Open the accordion: tap the trigger (icon button, no label).
      await tester.tap(find.byType(AcordeonFuente));
      await tester.pumpAndSettle();

      // The floating list shows the source names — tap 'Spotify'.
      await tester.tap(find.text('Spotify').last);
      await tester.pumpAndSettle();

      expect(bloc.state.fuenteSeleccionada, 'spotify-web');
    });
  });
}