// Test de la tarjeta de aviso de descarga: es la superficie donde el usuario
// se entera de que una canción falló y desde donde la puede reintentar, así que
// se verifica que muestre título, mensaje, motivo y que los botones avisen.

import 'package:bitly/shared/widgets/descargas/tarjeta_aviso_descarga.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _envolver(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('TarjetaAvisoDescarga', () {
    testWidgets('muestra título, mensaje y motivo', (tester) async {
      await tester.pumpWidget(
        _envolver(
          TarjetaAvisoDescarga(
            icono: Icons.error_outline,
            acento: Colors.orange,
            titulo: 'No se pudo descargar «Blinding Lights»',
            mensaje: 'Puedes reintentar.',
            motivo: 'Motivo: sin stream disponible',
            onCerrar: () {},
          ),
        ),
      );

      expect(find.textContaining('Blinding Lights'), findsOneWidget);
      expect(find.text('Puedes reintentar.'), findsOneWidget);
      expect(find.textContaining('sin stream disponible'), findsOneWidget);
    });

    testWidgets('muestra la acción y avisa el toque', (tester) async {
      var tocada = false;
      await tester.pumpWidget(
        _envolver(
          TarjetaAvisoDescarga(
            icono: Icons.error_outline,
            acento: Colors.orange,
            titulo: 'Falló',
            onCerrar: () {},
            acciones: [
              AccionAvisoDescarga(
                'Reintentar',
                destacada: true,
                onTap: () => tocada = true,
              ),
            ],
          ),
        ),
      );

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      expect(tocada, isTrue);
    });

    testWidgets('la cruz cierra la tarjeta', (tester) async {
      var cerrada = false;
      await tester.pumpWidget(
        _envolver(
          TarjetaAvisoDescarga(
            icono: Icons.error_outline,
            acento: Colors.red,
            titulo: 'Falló',
            onCerrar: () => cerrada = true,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(cerrada, isTrue);
    });

    testWidgets('sin acciones no dibuja la fila de botones', (tester) async {
      await tester.pumpWidget(
        _envolver(
          TarjetaAvisoDescarga(
            icono: Icons.folder_off_outlined,
            acento: Colors.red,
            titulo: 'Carpeta no disponible',
            onCerrar: () {},
          ),
        ),
      );

      expect(find.text('Reintentar'), findsNothing);
      expect(find.byType(InkWell), findsOneWidget); // solo la cruz
    });
  });
}
