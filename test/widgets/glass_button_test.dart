import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/shared/widgets/glass_button.dart';

void main() {
  group('GlassButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassButton(
              label: 'Continue',
              onPressed: () {},
            ),
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
            body: GlassButton(
              label: 'Tap me',
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      expect(pressed, isTrue);
    });

    testWidgets('shows spinner when isLoading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassButton(
              label: 'Loading',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Label should not be visible while loading
      expect(find.text('Loading'), findsNothing);
    });

    testWidgets('does not show spinner when not loading', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassButton(
              label: 'Not loading',
              onPressed: () {},
              isLoading: false,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('renders customChild when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassButton(
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
            body: GlassButton(
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
          home: Scaffold(
            body: GlassButton(
              label: 'Enabled',
              onPressed: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('uses custom height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassButton(
              label: 'Tall',
              onPressed: () {},
              height: 60,
            ),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.height, 60);
    });
  });
}

