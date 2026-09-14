// El paso del nombre del setup crea la cuenta de Soulseek por detrás al tocar
// Siguiente. Lo que se fija acá es la parte visible: que el usuario LEA que se
// va a crear una cuenta con su nombre antes de continuar, y que esa línea no
// rompa el layout en un celular chico ni en una pantalla grande.
//
// Un desborde de layout hace fallar el test solo (Flutter lo reporta como
// error en el frame), así que alcanza con montar el widget.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bitly/features/setup/bloc/setup_estado.dart';
import 'package:bitly/features/setup/widgets/comunes/campo_usuario.dart';
import 'package:bitly/l10n/app_localizations.dart';
import 'package:bitly/shared/utilidades/plataforma/responsive.dart';

void main() {
  final loc = AppLocalizations(const Locale('es'));
  final en = AppLocalizations(const Locale('en'));

  Future<void> montar(
    WidgetTester tester,
    Size tamano, {
    String usuario = 'pablo_bz',
    AppLocalizations? idioma,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => CampoUsuario(
              state: EstadoSetup(usuario: usuario),
              loc: idioma ?? loc,
              r: Responsive(context),
              onBg: Colors.white,
              glowColor: Colors.green,
              controller: TextEditingController(text: usuario),
            ),
          ),
        ),
      ),
    );
  }

  group('CampoUsuario (setup)', () {
    testWidgets('avisa que continuar crea la cuenta de Soulseek', (
      tester,
    ) async {
      await montar(tester, const Size(360, 640));

      expect(
        find.text('Al continuar se crea tu cuenta de Soulseek con este nombre'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.hub_rounded), findsOneWidget);
      // El campo y la insignia siguen ahí: no es un formulario nuevo.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('el aviso está en inglés cuando el idioma es inglés', (
      tester,
    ) async {
      await montar(tester, const Size(360, 640), idioma: en);

      expect(
        find.text(
          'Continuing creates your Soulseek account with this name',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no se desborda en celular chico (360x640)', (tester) async {
      await montar(tester, const Size(360, 640));
    });

    testWidgets('no se desborda en celular grande (430x932)', (tester) async {
      await montar(tester, const Size(430, 932));
    });

    testWidgets('no se desborda en pantalla grande (1440x900)', (
      tester,
    ) async {
      await montar(tester, const Size(1440, 900));
    });

    testWidgets('no se desborda con un nombre de 30 caracteres', (
      tester,
    ) async {
      await montar(
        tester,
        const Size(360, 640),
        usuario: 'abcdefghijklmnopqrstuvwxyz0123',
      );
    });
  });
}
