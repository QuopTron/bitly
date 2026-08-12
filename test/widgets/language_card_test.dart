import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/shared/widgets/language_card.dart';

void main() {
  group('LanguageCard', () {
    testWidgets('renders icon and name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LanguageCard(
              icon: Icons.language,
              iconColor: Colors.blue,
              name: 'English',
              selected: false,
              onTap: () {},
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.language), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('shows check icon when selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LanguageCard(
              icon: Icons.language,
              iconColor: Colors.blue,
              name: 'Español',
              selected: true,
              onTap: () {},
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('does not show check icon when not selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LanguageCard(
              icon: Icons.language,
              iconColor: Colors.blue,
              name: 'Français',
              selected: false,
              onTap: () {},
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('calls onTap on tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LanguageCard(
              icon: Icons.language,
              iconColor: Colors.blue,
              name: 'Deutsch',
              selected: false,
              onTap: () => tapped = true,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Deutsch'));
      expect(tapped, isTrue);
    });
  });
}

