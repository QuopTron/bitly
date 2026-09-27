// release_notas_vista_test.dart — Cómo se ven las novedades de una versión.
//
// El bug reportado: la hoja de versiones mostraba el changelog en un párrafo
// corrido, recortado a tres líneas y con los símbolos del markdown a la vista
// (`###`, `**`, el español y el inglés pegados). No se entendía qué traía la
// versión nueva.
//
// La regla que fija este test: se ve el título de cada sección y una novedad
// por renglón, sin símbolos raros; lo que no entra queda detrás de "Ver todo"
// y se puede abrir sin salir de la hoja.
//
// Se conecta con: features/ajustes/update/base/release_notas_vista.dart +
// strings_actualizacion ("Ver todo" / "Ver menos").
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/features/ajustes/update/base/release_notas_vista.dart';
import 'package:bitly/l10n/app_localizations.dart';

const _cuerpo = '''
## 🎵 Bitly 0.9.26

### ✨ Novedades
- **Gestos rápidos**: deslizá para agregar a la cola.
- **Info con traducción**: traducí el nombre de un tema.
- **Descarga en segundo plano**: la instalás cuando quieras.

### 🔧 Mejoras y correcciones
- Rescate de FLAC más sólido.
- Búsqueda sin duplicados.

---

## 🎵 Bitly 0.9.26

### ✨ Highlights
- **Quick gestures**: swipe to queue.

### 🔧 Fixes
- More robust FLAC rescue.
''';

Widget _app({Locale locale = const Locale('es')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('es'), Locale('en')],
  home: Scaffold(
    body: NotasReleaseVista(
      cuerpo: _cuerpo,
      version: '0.9.26',
      colorTexto: const Color(0xFF888888),
      colorTitulo: const Color(0xFF222222),
      colorPunto: const Color(0xFF1DB954),
      tamano: 12,
    ),
  ),
);

void main() {
  testWidgets('muestra las secciones y una novedad por renglón, en español', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('✨ Novedades'), findsOneWidget);
    expect(find.textContaining('Gestos rápidos'), findsOneWidget);
    expect(
      find.textContaining('Descarga en segundo plano'),
      findsOneWidget,
      reason: 'las tres primeras novedades entran sin abrir nada',
    );
    expect(
      find.textContaining('Highlights'),
      findsNothing,
      reason: 'no se muestra el inglés además del español',
    );
    expect(find.textContaining('#'), findsNothing, reason: 'sin markdown');
    expect(find.textContaining('*'), findsNothing, reason: 'sin markdown');
  });

  testWidgets('lo que no entra queda detrás de "Ver todo"', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('🔧 Mejoras y correcciones'), findsNothing);
    expect(find.text('Ver todo'), findsOneWidget);

    await tester.tap(find.text('Ver todo'));
    await tester.pumpAndSettle();

    expect(find.text('🔧 Mejoras y correcciones'), findsOneWidget);
    expect(find.textContaining('Rescate de FLAC'), findsOneWidget);
    expect(find.text('Ver menos'), findsOneWidget);

    await tester.tap(find.text('Ver menos'));
    await tester.pumpAndSettle();
    expect(find.text('🔧 Mejoras y correcciones'), findsNothing);
  });

  testWidgets('en inglés muestra la mitad inglesa de las notas', (
    tester,
  ) async {
    await tester.pumpWidget(_app(locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('✨ Highlights'), findsOneWidget);
    expect(find.textContaining('Quick gestures'), findsOneWidget);
    expect(find.textContaining('Novedades'), findsNothing);
  });

  testWidgets('sin notas no dibuja nada', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotasReleaseVista(
            cuerpo: '   ',
            colorTexto: const Color(0xFF888888),
            colorTitulo: const Color(0xFF222222),
            colorPunto: const Color(0xFF1DB954),
            tamano: 12,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Text), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
