// estilo_info_test.dart — Prueba el botón "i" del bloque Estilo con cover:
// abre la hoja real, y la hoja cuenta qué hace la opacidad, en los dos
// idiomas, con su botón para cerrar.
//
// Existe porque el control cambia la app entera y "Opacidad" sola no explica
// nada: si la hoja se rompe o queda sin textos, el usuario se queda sin la
// única pista de qué está moviendo.

import 'package:bitly/features/ajustes/sheet/settings_sheet_new.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget app() => MaterialApp(
    locale: const Locale('es'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('es'), Locale('en')],
    home: Scaffold(
      body: Builder(
        builder:
            (context) => FilledButton(
              onPressed: () => abrirInfoEstilo(context),
              child: const Text('Abrir info'),
            ),
      ),
    ),
  );

  /// Monta la app y abre la hoja (el delegate de l10n carga async: sin el
  /// pumpAndSettle el botón todavía no existe).
  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir info'));
    await tester.pumpAndSettle();
  }

  testWidgets('la hoja explica qué hace la opacidad', (tester) async {
    await abrir(tester);

    expect(find.text('Qué hace la opacidad'), findsOneWidget);
    expect(
      find.textContaining('En 0% queda el diseño de siempre'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Al 100% el color de la carátula'),
      findsOneWidget,
    );
    expect(find.text('Entendido'), findsOneWidget);
  });

  testWidgets('el botón de la hoja la cierra', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    expect(find.text('Qué hace la opacidad'), findsNothing);
    expect(find.text('Abrir info'), findsOneWidget);
  });
}
