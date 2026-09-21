// ─────────────────────────────────────────────────────────────
// modal_sobre_modal_test.dart — Fija la regla "ningún modal sobre
// otro": cuando una hoja o un diálogo nace DENTRO de otro modal, su
// velo es OPACO (color de la página) y tapa por completo el modal de
// abajo. Desde una pantalla normal el velo sigue siendo el clásico
// translúcido, que es el que se ve lindo. Se cubre también la
// AUTO-DETECCIÓN: ni siquiera hace falta pedirlo, y la cuenta vuelve a
// cero al cerrar.
// Parte del flujo: cualquier modal de la app.
// ─────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:bitly/shared/tema/colores_app.dart';
import 'package:bitly/shared/utilidades/modales/mostrar_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Color actual del velo MÁS ARRIBA de la pantalla (el del último modal).
Color? _veloSuperior(WidgetTester tester) {
  final barreras =
      tester
          .widgetList<AnimatedModalBarrier>(find.byType(AnimatedModalBarrier))
          .toList();
  if (barreras.isEmpty) return null;
  return barreras.last.color.value;
}

/// Monta la app y deja un contexto de la página listo para abrir modales.
Future<BuildContext> _montar(WidgetTester tester) async {
  late BuildContext raiz;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) {
            raiz = ctx;
            return const SizedBox.expand();
          },
        ),
      ),
    ),
  );
  return raiz;
}

void main() {
  // El contador de modales vivos es global: se reinicia para que un test no
  // herede las hojas que otro dejó abiertas al desmontar su árbol.
  setUp(reiniciarModalesAbiertos);

  testWidgets('la hoja abierta sobre otra tapa el fondo (velo opaco)', (
    tester,
  ) async {
    final raiz = await _montar(tester);
    late BuildContext dentroDeLaHoja;

    // Hoja de abajo: comportamiento clásico.
    unawaited(
      mostrarHoja<void>(
        context: raiz,
        builder:
            (_) => SizedBox(
              height: 120,
              child: Builder(
                builder: (ctx) {
                  dentroDeLaHoja = ctx;
                  return const Text('abajo');
                },
              ),
            ),
      ),
    );
    await tester.pumpAndSettle();

    final veloAbajo = _veloSuperior(tester);
    expect(veloAbajo, isNotNull);
    expect(
      veloAbajo!.a,
      lessThan(1),
      reason: 'desde una página el velo tiene que dejar ver el fondo',
    );

    // Hoja de arriba: nace dentro del modal → tapa todo.
    unawaited(
      mostrarHoja<void>(
        context: dentroDeLaHoja,
        sobreHoja: true,
        builder: (_) => const SizedBox(height: 80, child: Text('arriba')),
      ),
    );
    await tester.pumpAndSettle();

    final veloArriba = _veloSuperior(tester);
    expect(veloArriba, isNotNull);
    expect(veloArriba!.a, 1.0, reason: 'no puede verse el modal de abajo');
    expect(veloArriba, ColoresApp.fondo(false));
    expect(find.text('arriba'), findsOneWidget);
  });

  testWidgets('el diálogo abierto sobre una hoja también tapa el fondo', (
    tester,
  ) async {
    final raiz = await _montar(tester);
    late BuildContext dentroDeLaHoja;

    unawaited(
      mostrarHoja<void>(
        context: raiz,
        builder:
            (_) => SizedBox(
              height: 120,
              child: Builder(
                builder: (ctx) {
                  dentroDeLaHoja = ctx;
                  return const Text('hoja');
                },
              ),
            ),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(
      mostrarDialogo<void>(
        context: dentroDeLaHoja,
        sobreModal: true,
        builder: (_) => const AlertDialog(title: Text('confirmar')),
      ),
    );
    await tester.pumpAndSettle();

    expect(_veloSuperior(tester)!.a, 1.0);
    expect(find.text('confirmar'), findsOneWidget);
  });

  testWidgets('hoja anidada tapa aunque el llamador NO lo pida', (
    tester,
  ) async {
    final raiz = await _montar(tester);
    late BuildContext dentroDeLaHoja;

    unawaited(
      mostrarHoja<void>(
        context: raiz,
        builder:
            (_) => SizedBox(
              height: 120,
              child: Builder(
                builder: (ctx) {
                  dentroDeLaHoja = ctx;
                  return const Text('abajo');
                },
              ),
            ),
      ),
    );
    await tester.pumpAndSettle();

    // Sin `sobreHoja: true`: la auto-detección tiene que hacer el trabajo.
    unawaited(
      mostrarHoja<void>(
        context: dentroDeLaHoja,
        builder: (_) => const SizedBox(height: 80, child: Text('arriba')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _veloSuperior(tester)!.a,
      1.0,
      reason: 'con otro modal abierto el velo se opaca solo',
    );
  });

  testWidgets(
    'la cuenta vuelve a cero al cerrar (no ensucia la próxima hoja)',
    (tester) async {
      final raiz = await _montar(tester);

      unawaited(
        mostrarHoja<void>(
          context: raiz,
          builder: (_) => const SizedBox(height: 120),
        ),
      );
      await tester.pumpAndSettle();
      expect(hayModalAbierto, isTrue);

      Navigator.of(raiz).pop();
      await tester.pumpAndSettle();
      expect(hayModalAbierto, isFalse);

      // La siguiente hoja nace de la página otra vez: velo clásico.
      unawaited(
        mostrarHoja<void>(
          context: raiz,
          builder: (_) => const SizedBox(height: 120),
        ),
      );
      await tester.pumpAndSettle();
      expect(_veloSuperior(tester)!.a, lessThan(1));
    },
  );

  testWidgets('barrierDeModal decide el velo según haya modal abajo', (
    tester,
  ) async {
    final ctx = await _montar(tester);
    expect(barrierDeModal(ctx, sobreModal: false, pedido: null), isNull);
    expect(
      barrierDeModal(ctx, sobreModal: false, pedido: Colors.red),
      Colors.red,
      reason: 'sin modal abajo se respeta el velo pedido',
    );
    expect(
      barrierDeModal(ctx, sobreModal: true, pedido: Colors.red),
      ColoresApp.fondo(false),
      reason: 'con modal abajo gana el fondo de la página',
    );
  });
}
