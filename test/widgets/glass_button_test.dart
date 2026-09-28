import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/shared/widgets/esqueletos/esqueleto_carga.dart';
import 'package:bitly/shared/widgets/vidrio/botones/boton_vidrio.dart';

void main() {
  group('BotonVidrio', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotonVidrio(label: 'Continue', onPressed: () {}),
          ),
        ),
      );

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('calls onPressed on tap', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotonVidrio(label: 'Tap me', onPressed: () => pressed = true),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      expect(pressed, isTrue);
    });

    testWidgets('mientras carga muestra el hueco de la etiqueta', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotonVidrio(
              label: 'Loading',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      // La barra ocupa el lugar del texto (y el texto no se ve), en vez del
      // circulito que encogía el botón.
      expect(find.byType(EsqueletoEtiqueta), findsOneWidget);
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('con ícono también deja su hueco', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotonVidrio(
              label: 'Siguiente',
              icon: const Icon(Icons.arrow_forward),
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      // Icono + etiqueta: los dos huecos, con su forma.
      expect(find.byType(EsqueletoMarca), findsOneWidget);
      expect(find.byType(EsqueletoEtiqueta), findsOneWidget);
    });

    testWidgets('la barra mide exactamente lo que mide la etiqueta', (tester) async {
      // Es lo que evita que el botón salte de tamaño al terminar de cargar.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotonVidrio(label: 'Loading', onPressed: () {}),
          ),
        ),
      );
      final anchoEtiqueta = tester.getSize(find.text('Loading')).width;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotonVidrio(
              label: 'Loading',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      final barra = tester.widget<Container>(
        find.descendant(
          of: find.byType(EsqueletoEtiqueta),
          matching: find.byType(Container),
        ),
      );
      expect(
        barra.constraints!.maxWidth,
        moreOrLessEquals(anchoEtiqueta, epsilon: 1),
      );
    });

    testWidgets('sin cargar no hay huecos: se ve la etiqueta', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotonVidrio(
              label: 'Not loading',
              onPressed: () {},
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.byType(EsqueletoEtiqueta), findsNothing);
      expect(find.text('Not loading'), findsOneWidget);
    });

    testWidgets('renders customChild when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotonVidrio(
              onPressed: () {},
              customChild: const Icon(Icons.star, key: Key('custom')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('custom')), findsOneWidget);
    });

    testWidgets('renders icon alongside label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotonVidrio(
              label: 'With icon',
              icon: const Icon(Icons.check, key: Key('btnIcon')),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('btnIcon')), findsOneWidget);
      expect(find.text('With icon'), findsOneWidget);
    });

    testWidgets('is tappable when onPressed is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BotonVidrio(label: 'Enabled', onPressed: () {})),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('uses custom height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BotonVidrio(label: 'Tall', onPressed: () {}, height: 60),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.height, 60);
    });
  });
}
