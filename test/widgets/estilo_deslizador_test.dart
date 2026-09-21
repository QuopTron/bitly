// estilo_deslizador_test.dart — Prueba lo que hace el control GENERAL del
// estilo con cover contra la base real: mover el slider pone las CINCO zonas
// al mismo nivel (y queda guardado), afinar una sola no toca las otras, y
// "Volver al diseño original" devuelve el diseño de fábrica.
//
// Es lo que protege el cambio de los 5 interruptores al slider: si el general
// dejara de mover alguna zona, el usuario vería el color entrar "a medias" y
// no habría forma de saber de dónde viene.
//
// Si el entorno no expone SQLite nativo el test se saltea.

import 'package:bitly/app/inyeccion.dart' as di;
import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/cache_ajustes.dart';
import 'package:bitly/core/modelos/usuario/preferencias_estilo.dart';
import 'package:bitly/shared/utilidades/formato/estilo_helper.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  var disponible = true;

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    try {
      db = AppDatabase(NativeDatabase.memory());
    } catch (_) {
      disponible = false;
      return;
    }
    di.sl.registerSingleton<AppDatabase>(db);
    di.sl.registerSingleton<CacheAjustes>(CacheAjustes(db));
    di.sl.registerSingleton<ValueNotifier<PreferenciasEstilo>>(
      ValueNotifier(PreferenciasEstilo.normal),
    );
  });

  // Cada prueba arranca como un usuario recién instalado: Normal.
  setUp(() async {
    if (!disponible) return;
    di.sl<ValueNotifier<PreferenciasEstilo>>().value =
        PreferenciasEstilo.normal;
    await di.sl<CacheAjustes>().guardarPreferenciasEstilo(
      PreferenciasEstilo.normal,
    );
  });

  tearDownAll(() async {
    if (disponible) await db.close();
  });

  /// Un contexto real y la preferencia que quedó en memoria.
  Future<(BuildContext, PreferenciasEstilo)> montar(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
    final ctx = tester.element(find.byType(Scaffold));
    return (ctx, EstiloHelper.preferencias(ctx));
  }

  testWidgets('el control general pone las cinco zonas al mismo nivel', (
    tester,
  ) async {
    if (!disponible) return;
    final (ctx, _) = await montar(tester);

    EstiloHelper.moverTodos(ctx, 0.6);
    await tester.pump();

    final prefs = EstiloHelper.preferencias(ctx);
    expect(prefs.niveles, everyElement(closeTo(0.6, 0.001)));
    expect(prefs.esUniforme, isTrue, reason: 'no debe quedar "Personalizado"');
    expect(prefs.esNormal, isFalse);

    final guardado = await di.sl<CacheAjustes>().getPreferenciasEstilo();
    expect(guardado.niveles, everyElement(closeTo(0.6, 0.001)));
  });

  testWidgets('afinar una zona no toca las demás', (tester) async {
    if (!disponible) return;
    final (ctx, _) = await montar(tester);

    EstiloHelper.moverTodos(ctx, 1);
    EstiloHelper.cambiarNivel(ctx, ComponenteEstilo.fondosModals, 0);
    await tester.pump();

    final prefs = EstiloHelper.preferencias(ctx);
    expect(prefs.fondosModals, 0);
    expect(prefs.cardsCancion, 1, reason: 'el resto queda como estaba');
    expect(prefs.esUniforme, isFalse, reason: 'acá sí es Personalizado');
    expect(prefs.general, closeTo(0.8, 0.001), reason: 'el general promedia');
  });

  testWidgets('volver a Normal deja el diseño de fábrica', (tester) async {
    if (!disponible) return;
    final (ctx, _) = await montar(tester);

    EstiloHelper.moverTodos(ctx, 0.3);
    EstiloHelper.restablecer(ctx);
    await tester.pump();

    expect(EstiloHelper.preferencias(ctx).esNormal, isTrue);
    expect(EstiloHelper.hayAlguno(ctx), isFalse);
    final guardado = await di.sl<CacheAjustes>().getPreferenciasEstilo();
    expect(guardado.esNormal, isTrue, reason: 'también se persiste');
  });
}
