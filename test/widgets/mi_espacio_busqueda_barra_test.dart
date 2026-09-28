// ─────────────────────────────────────────────────────────────
// mi_espacio_busqueda_barra_test.dart — La barra de búsqueda de Mi Espacio no
// puede perder lo escrito al plegar el panel.
//
// Por qué existe: el acordeón de búsqueda MONTA y DESMONTA la barra. Mientras el
// controlador del texto vivía adentro de la barra, plegar el panel lo destruía
// y, al desplegarlo otra vez, el campo aparecía vacío: había que buscar de nuevo.
// Acá el controlador lo presta quien monta la barra (en la app, la página de Mi
// Espacio), que es lo que hace que el texto sobreviva.
//
// Se cubre además el otro filo del debounce: limpiar con la X tiene que cancelar
// la búsqueda que estaba por salir, o el filtro volvía a caer después de borrar.
//
// Parte del flujo: Home → Mi Espacio → búsqueda en tiempo real.
// ─────────────────────────────────────────────────────────────

import 'package:bitly/features/mi_espacio/filtros/barra_busqueda_mi_espacio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late TextEditingController ctrl;
  late List<String> buscado;

  setUp(() {
    ctrl = TextEditingController();
    buscado = [];
  });

  tearDown(() => ctrl.dispose());

  /// La barra montada como la monta Mi Espacio (con el controlador de afuera).
  Widget conBarra() => MaterialApp(
    home: Scaffold(
      body: BarraBusquedaMiEspacio(
        controller: ctrl,
        onBusquedaCambiada: buscado.add,
        onBg: Colors.white,
      ),
    ),
  );

  /// El acordeón plegado: la barra NO está en el árbol.
  Widget sinBarra() =>
      const MaterialApp(home: Scaffold(body: SizedBox.shrink()));

  testWidgets('el texto sobrevive a plegar y desplegar el panel', (
    tester,
  ) async {
    await tester.pumpWidget(conBarra());
    await tester.enterText(find.byType(TextField), 'beatles');
    // El debounce es de 400 ms: sin dejarlo vencer, no hay búsqueda todavía.
    await tester.pump(const Duration(milliseconds: 500));
    expect(buscado, ['beatles']);

    // Se pliega el panel (la barra sale del árbol, como en la app)...
    await tester.pumpWidget(sinBarra());
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);

    // ...y se despliega otra vez: lo escrito sigue ahí.
    await tester.pumpWidget(conBarra());
    await tester.pumpAndSettle();
    expect(find.text('beatles'), findsOneWidget);
  });

  testWidgets('el botón de limpiar aparece con el primer carácter', (
    tester,
  ) async {
    await tester.pumpWidget(conBarra());
    expect(
      find.byIcon(Icons.close_rounded),
      findsNothing,
      reason: 'sin texto no hay nada que limpiar',
    );

    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.close_rounded), findsNothing);
    expect(ctrl.text, isEmpty);
  });

  testWidgets('limpiar cancela la búsqueda que estaba por salir', (
    tester,
  ) async {
    await tester.pumpWidget(conBarra());
    // Se escribe y se borra ANTES de que venza el debounce (el pump de 0 ms
    // sólo pinta la X; el reloj sigue en el mismo instante).
    await tester.enterText(find.byType(TextField), 'beatles');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 600));

    // El filtro sale una sola vez y con el texto vacío: el que estaba en cola
    // quedó cancelado (si no, la lista volvía a filtrarse tras limpiar).
    expect(buscado, ['']);
  });
}
