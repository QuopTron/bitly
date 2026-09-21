// diseno_deslizador_test.dart — Prueba lo que hace el bloque Diseño contra
// la base real: el control GENERAL mueve los dos ejes a la vez (el hueco
// entre cards Y el margen contra los bordes), afinar un eje solo no toca el
// otro (y la UI lo marca "Personalizado"), y "Volver al diseño original"
// devuelve el de fábrica.
//
// Es lo que protege el agregado del margen exterior: si el general dejara de
// mover un eje, el usuario vería las cards pegadas de un lado y no del otro.
//
// Si el entorno no expone SQLite nativo el test se saltea.

import 'package:bitly/app/inyeccion/inyeccion.dart' as di;
import 'package:bitly/core/base_datos/app_database.dart';
import 'package:bitly/core/cache/almacenes/sistema/cache_ajustes.dart';
import 'package:bitly/core/modelos/usuario/preferencias/preferencias_apariencia.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/base/apariencia_helper.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitly/shared/utilidades/formato/apariencia/barras/apariencia_espacios_helper.dart';

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
    di.sl.registerSingleton<ValueNotifier<PreferenciasApariencia>>(
      ValueNotifier(PreferenciasApariencia.deFabrica),
    );
  });

  // Cada prueba arranca como un usuario recién instalado: diseño de fábrica.
  setUp(() async {
    if (!disponible) return;
    di.sl<ValueNotifier<PreferenciasApariencia>>().value =
        PreferenciasApariencia.deFabrica;
    await di.sl<CacheAjustes>().guardarPreferenciasApariencia(
      PreferenciasApariencia.deFabrica,
    );
  });

  tearDownAll(() async {
    if (disponible) await db.close();
  });

  /// Un contexto real y las preferencias que quedaron en memoria.
  Future<(BuildContext, PreferenciasApariencia)> montar(
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('x'))));
    final ctx = tester.element(find.byType(Scaffold));
    return (ctx, AparienciaHelper.actual(ctx));
  }

  testWidgets('el control general mueve los dos ejes a la vez', (tester) async {
    if (!disponible) return;
    final (ctx, _) = await montar(tester);

    AparienciaEspacios.cambiarSeparacion(ctx, 0.5);
    await tester.pump();

    final prefs = AparienciaHelper.actual(ctx);
    expect(prefs.espacioX, closeTo(0.5, 0.001));
    expect(prefs.espacioY, closeTo(0.5, 0.001));
    expect(prefs.separacionUniforme, isTrue, reason: 'no es "Personalizado"');

    final guardado = await di.sl<CacheAjustes>().getPreferenciasApariencia();
    expect(guardado.espacioX, closeTo(0.5, 0.001));
    expect(guardado.espacioY, closeTo(0.5, 0.001));
  });

  testWidgets('separar sólo un eje no toca el otro', (tester) async {
    if (!disponible) return;
    final (ctx, _) = await montar(tester);

    AparienciaEspacios.cambiarSeparacion(ctx, 1.5);
    AparienciaEspacios.cambiarEspacioX(ctx, 0);
    await tester.pump();

    final prefs = AparienciaHelper.actual(ctx);
    expect(prefs.espacioX, 0);
    expect(prefs.espacioY, 1.5, reason: 'el eje Y queda como estaba');
    expect(
      prefs.separacionUniforme,
      isFalse,
      reason: 'acá sí es "Personalizado"',
    );
  });

  testWidgets('Afines: afinar un componente no toca el otro', (tester) async {
    if (!disponible) return;
    final (ctx, _) = await montar(tester);

    AparienciaEspacios.cambiarSeparacion(ctx, 1.5);
    AparienciaEspacios.cambiarCancionX(ctx, 0);
    await tester.pump();

    final prefs = AparienciaHelper.actual(ctx);
    expect(prefs.cancionX, 0, reason: 'las cards de canción sí cambian');
    expect(prefs.grillaX, 1.5, reason: 'las grillas NO se tocan');
    expect(prefs.cancionY, 1.5, reason: 'el otro eje tampoco');
    expect(prefs.separacionUniforme, isFalse, reason: 'ahora es Personalizado');
  });

  testWidgets('volver al diseño original deja el de fábrica', (tester) async {
    if (!disponible) return;
    final (ctx, _) = await montar(tester);

    AparienciaEspacios.cambiarSeparacion(ctx, 0.2);
    AparienciaHelper.restablecer(ctx);
    await tester.pump();

    final prefs = AparienciaHelper.actual(ctx);
    expect(prefs.esDeFabrica, isTrue);
    expect(prefs.espacioX, 1);
    expect(prefs.espacioY, 1);
    final guardado = await di.sl<CacheAjustes>().getPreferenciasApariencia();
    expect(guardado.esDeFabrica, isTrue, reason: 'también se persiste');
  });
}
