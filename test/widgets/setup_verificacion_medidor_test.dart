// ─────────────────────────────────────────────────────────────
// setup_verificacion_medidor_test.dart — El paso de verificación
// del setup mide lo que de verdad pasa: cuántos proveedores
// quedaron verificados.
//
// Por qué existe: antes cada fila que se estaba verificando tenía
// su propio spinner y NINGÚN dato de conjunto — siete círculos
// girando sin saber cuánto faltaba. Ahora hay un contador y una
// barra que salen del estado real de cada proveedor, así que esta
// prueba fija tres cosas que se pueden romper sin que se note:
//   · que el medidor NO aparezca antes de arrancar (un "0 de 7"
//     que no aporta nada);
//   · que avance con el resultado real (acá la lista de fuentes con
//     sesión firmada es `const []`, así que el paso marca todo
//     verificado sin tocar el backend: es el camino determinista);
//   · que no vuelva ningún spinner por fila.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/core/servicios/verificacion/servicio_verificacion.dart';
import 'package:bitly/features/setup/bloc/base/setup_estado.dart';
import 'package:bitly/features/setup/widgets/slides/verificacion/slide_verificacion.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/utilidades/plataforma/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final loc = AppLocalizations(const Locale('es'));

  /// Los 7 proveedores del slide, con su nombre tal como se muestra.
  const proveedores = [
    'Deezer',
    'Qobuz',
    'TIDAL',
    'Amazon',
    'Apple',
    'SoundCloud',
    'Pandora',
  ];

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: SlideVerificacion(
                  state: const EstadoSetup(),
                  loc: loc,
                  r: Responsive(context),
                  isDark: true,
                ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('los proveedores salen listados', (tester) async {
    await montar(tester);

    for (final p in proveedores) {
      expect(find.text(p), findsOneWidget, reason: p);
    }
  });

  testWidgets('antes de arrancar no hay medidor', (tester) async {
    await montar(tester);

    // Con la verificación sin empezar, un contador en 0 sería ruido.
    expect(find.text(loc.setup.verificados(0, 7)), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('al verificar, el medidor cuenta los que quedaron listos', (
    tester,
  ) async {
    await montar(tester);
    await tester.tap(find.text(loc.setup.verificationStart));
    await tester.pumpAndSettle();

    // Sin fuentes con sesión firmada (la lista es `const []`) el paso marca
    // todas como verificadas sin backend: el estado real es 7 de 7.
    expect(ServicioVerificacion.fuentesSesionFirmada, isEmpty);
    expect(find.text(loc.setup.verificados(7, 7)), findsOneWidget);

    final barra = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(barra.value, 1);
  });

  testWidgets('ninguna fila vuelve a girar sola', (tester) async {
    await montar(tester);
    await tester.tap(find.text(loc.setup.verificationStart));
    await tester.pumpAndSettle();

    // Lo que se fue: el spinner por fila. El estado de cada proveedor ya lo
    // dice su propio icono (reloj de arena, sync, tilde o error).
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNWidgets(proveedores.length));
  });
}
