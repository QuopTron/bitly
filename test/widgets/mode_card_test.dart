import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/shared/widgets/mode_card.dart';

void main() {
  group('ModeCard', () {
    testWidgets('renders icon, title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeCard(
              title: 'Free',
              subtitle: 'Free access for 6 hours',
              icon: Icons.music_note,
              iconColor: Colors.orange,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.music_note), findsOneWidget);
      expect(find.text('Free'), findsOneWidget);
      expect(find.text('Free access for 6 hours'), findsOneWidget);
    });

    testWidgets('shows check icon when selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeCard(
              title: 'Premium',
              subtitle: 'Unlimited',
              icon: Icons.verified,
              iconColor: Colors.amber,
              selected: true,
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
            body: ModeCard(
              title: 'Free',
              subtitle: 'Basic',
              icon: Icons.music_note,
              iconColor: Colors.orange,
              selected: false,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('shows info button when onInfoTap is provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeCard(
              title: 'Free',
              subtitle: 'Details',
              icon: Icons.music_note,
              iconColor: Colors.orange,
              onInfoTap: () {},
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('hides info button when onInfoTap is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeCard(
              title: 'Free',
              subtitle: 'Details',
              icon: Icons.music_note,
              iconColor: Colors.orange,
              onInfoTap: null,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    testWidgets('calls onInfoTap on info button tap', (tester) async {
      bool infoTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModeCard(
              title: 'Free',
              subtitle: 'Info',
              icon: Icons.music_note,
              iconColor: Colors.orange,
              onInfoTap: () => infoTapped = true,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.info_outline));
      expect(infoTapped, isTrue);
    });
  });
}

