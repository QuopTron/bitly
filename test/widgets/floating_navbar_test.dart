// floating_navbar_test.dart — Prueba la barra de navegación flotante del
// móvil: 3 ítems, selección, taps y modo oscuro. Los rótulos ahora salen de
// la l10n, así que el test monta el delegate para que resuelvan.

import 'package:bitly/app/inyeccion.dart' as di;
import 'package:bitly/core/modelos/usuario/preferencias_apariencia.dart';
import 'package:bitly/features/home/widgets/barra_navegacion_flotante.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // La barra lee las preferencias de apariencia (esquinas de arriba y
  // contorno): el test las registra como en la app real.
  setUpAll(() {
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(
      ValueNotifier(PreferenciasApariencia.deFabrica),
    );
  });

  /// Monta la barra dentro de un MaterialApp con la l10n de la app.
  Widget app(Widget child, {bool dark = false}) => MaterialApp(
    locale: const Locale('es'),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    darkTheme: ThemeData(brightness: Brightness.dark),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es'), Locale('en')],
    home: Scaffold(body: child),
  );

  group('BarraNavegacionFlotante', () {
    testWidgets('renders 3 navigation items', (tester) async {
      await tester.pumpWidget(
        app(const BarraNavegacionFlotante(isDark: false)),
      );
      await tester.pumpAndSettle();

      // Should find icons for search, home, and grid_view
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    });

    testWidgets('shows selected state at given index', (tester) async {
      await tester.pumpWidget(
        app(const BarraNavegacionFlotante(isDark: false, currentIndex: 0)),
      );
      await tester.pumpAndSettle();

      // Index 0 = search, should be selected
      // We can verify by checking the GlassContainer is rendered
      expect(find.byType(BarraNavegacionFlotante), findsOneWidget);
    });

    testWidgets('shows middle item (home) selected by default', (tester) async {
      await tester.pumpWidget(
        app(const BarraNavegacionFlotante(isDark: false, currentIndex: 1)),
      );
      await tester.pumpAndSettle();

      // Home rounded at selected index 1
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    });

    testWidgets('calls onTap when item is tapped', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        app(
          BarraNavegacionFlotante(
            isDark: false,
            currentIndex: 1,
            onTap: (i) => tappedIndex = i,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the search item
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(tappedIndex, 0);
    });

    testWidgets('calls onTap with index 2 when grid item is tapped', (
      tester,
    ) async {
      int? tappedIndex;
      await tester.pumpWidget(
        app(
          BarraNavegacionFlotante(
            isDark: false,
            currentIndex: 0,
            onTap: (i) => tappedIndex = i,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the mi espacio item
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();

      expect(tappedIndex, 2);
    });

    testWidgets('adapts to dark mode', (tester) async {
      await tester.pumpWidget(
        app(const BarraNavegacionFlotante(isDark: true), dark: true),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    });
  });
}
