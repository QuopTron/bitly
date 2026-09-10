import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/features/setup/widgets/vista_previa_carpeta.dart';

void main() {
  group('VistaPreviaCarpeta', () {
    testWidgets('shows folder icon and selectedLabel when hasPath', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VistaPreviaCarpeta(
              tieneRuta: true,
              usandoPorDefecto: false,
              eligiendo: false,
              rutaMostrada: '/storage/music',
              etiquetaSeleccionada: 'Selected folder',
              etiquetaSinCarpeta: 'No folder',
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.text('Selected folder'), findsOneWidget);
      expect(find.text('/storage/music'), findsOneWidget);
    });

    testWidgets('shows folder_open icon and noFolderLabel when !hasPath', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VistaPreviaCarpeta(
              tieneRuta: false,
              usandoPorDefecto: false,
              eligiendo: false,
              rutaMostrada: '',
              etiquetaSeleccionada: 'Selected folder',
              etiquetaSinCarpeta: 'No folder',
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.folder_open), findsOneWidget);
      expect(find.text('No folder'), findsOneWidget);
    });

    testWidgets('shows loading spinner when picking', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VistaPreviaCarpeta(
              tieneRuta: false,
              usandoPorDefecto: false,
              eligiendo: true,
              rutaMostrada: '',
              etiquetaSeleccionada: 'Selected',
              etiquetaSinCarpeta: 'No folder',
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('hides spinner when not picking', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VistaPreviaCarpeta(
              tieneRuta: false,
              usandoPorDefecto: false,
              eligiendo: false,
              rutaMostrada: '',
              etiquetaSeleccionada: 'Selected',
              etiquetaSinCarpeta: 'No folder',
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}

