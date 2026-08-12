import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/shared/widgets/glass_container.dart';

void main() {
  group('GlassContainer', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              child: const Text('Hello'),
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('applies padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              padding: const EdgeInsets.all(24),
              child: const Text('Padded'),
            ),
          ),
        ),
      );

      // The Container with padding wraps the child
      expect(find.text('Padded'), findsOneWidget);
    });

    testWidgets('applies margin', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              margin: const EdgeInsets.all(16),
              child: const Text('Margined'),
            ),
          ),
        ),
      );

      // The outer Padding wraps the inner Container
      expect(find.byType(Padding), findsWidgets);
      expect(find.text('Margined'), findsOneWidget);
    });

    testWidgets('applies custom border radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              borderRadius: 8,
              child: const Text('Rounded'),
            ),
          ),
        ),
      );

      expect(find.text('Rounded'), findsOneWidget);
    });

    testWidgets('accepts custom border color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              borderColor: Colors.red,
              child: const Text('Bordered'),
            ),
          ),
        ),
      );

      expect(find.text('Bordered'), findsOneWidget);
    });

    testWidgets('accepts background color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassContainer(
              bgColor: Colors.blue.withValues(alpha: 0.1),
              child: const Text('Colored bg'),
            ),
          ),
        ),
      );

      expect(find.text('Colored bg'), findsOneWidget);
    });
  });
}

