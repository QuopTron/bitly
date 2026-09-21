// selector_idioma_test.dart — Prueba el selector de idioma contra la base
// real: la hoja lista los idiomas, tilda el que está puesto, y al elegir otro
// lo APLICA (notifier) y lo GUARDA (base), y se cierra.
//
// Es lo que antes no existía: la fila era un interruptor disfrazado de lista,
// y sin un test se vuelve a colar que tocar el idioma deje de persistir.
//
// Si el entorno no expone SQLite nativo el test se saltea.
import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/sistema/cache_ajustes.dart';
// Las partes no se importan suelto: se entra por la library que las une.
import 'package:bitly/features/ajustes/sheet/settings_sheet_new.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ValueNotifier<Locale> idioma;
  var disponible = true;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    try {
      db = AppDatabase(NativeDatabase.memory());
    } catch (_) {
      disponible = false;
      return;
    }
    idioma = ValueNotifier(const Locale('es'));
    di.sl.registerSingleton<AppDatabase>(db);
    di.sl.registerSingleton<CacheAjustes>(CacheAjustes(db));
    di.sl.registerSingleton<ValueNotifier<Locale>>(idioma);
  });

  // Cada prueba arranca en español, como un usuario recién instalado.
  setUp(() {
    if (disponible) idioma.value = const Locale('es');
  });

  tearDownAll(() async {
    if (disponible) await db.close();
  });

  /// App mínima con el botón que abre el selector real.
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
              onPressed: () => abrirSelectorIdioma(context),
              child: const Text('Abrir idioma'),
            ),
      ),
    ),
  );

  /// Monta la app y abre el selector (la localización tarda un frame: el
  /// delegate carga async, así que sin el pumpAndSettle el botón no existe).
  Future<void> abrirApp(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir idioma'));
    await tester.pumpAndSettle();
  }

  /// Color del tilde de [codigo]: transparente si ese idioma no es el puesto.
  Color? tildeDe(WidgetTester tester, String codigo) =>
      tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(ValueKey('idioma-$codigo')),
              matching: find.byIcon(Icons.check_rounded),
            ),
          )
          .color;

  testWidgets('lista los idiomas y tilda el que está puesto', (tester) async {
    if (!disponible) return;
    await abrirApp(tester);

    expect(find.text('Elegí el idioma'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);

    expect(
      tildeDe(tester, 'es')!.a,
      greaterThan(0),
      reason: 'es el idioma puesto',
    );
    expect(tildeDe(tester, 'en')!.a, 0, reason: 'no es el idioma puesto');
  });

  testWidgets('elegir un idioma lo aplica, lo guarda y cierra la hoja', (
    tester,
  ) async {
    if (!disponible) return;
    await abrirApp(tester);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(idioma.value.languageCode, 'en', reason: 'se aplica al instante');
    expect(
      await di.sl<CacheAjustes>().getAjuste('locale'),
      'en',
      reason: 'tiene que quedar guardado para el próximo arranque',
    );
    expect(find.text('Elegí el idioma'), findsNothing, reason: 'se cierra');
  });

  testWidgets('elegir el idioma que ya estaba no lo reescribe', (tester) async {
    if (!disponible) return;
    idioma.value = const Locale('en');
    await di.sl<CacheAjustes>().guardarIdioma('es');

    await abrirApp(tester);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(idioma.value.languageCode, 'en');
    expect(
      await di.sl<CacheAjustes>().getAjuste('locale'),
      'es',
      reason: 'sin cambio real no se toca la base',
    );
  });
}
