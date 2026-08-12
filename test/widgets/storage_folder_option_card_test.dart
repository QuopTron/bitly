import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/features/setup/widgets/storage_folder_option_card.dart';

void main() {
  group('StorageOptionCard', () {
    testWidgets('renders icon, title and subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageOptionCard(
              icon: Icons.folder,
              title: 'Choose folder',
              subtitle: 'Pick a custom location',
              selected: false,
              disabled: false,
              onTap: () {},
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.folder), findsOneWidget);
      expect(find.text('Choose folder'), findsOneWidget);
      expect(find.text('Pick a custom location'), findsOneWidget);
    });

    testWidgets('shows check icon when selected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageOptionCard(
              icon: Icons.folder,
              title: 'Selected',
              subtitle: 'This is selected',
              selected: true,
              disabled: false,
              onTap: () {},
              onBg: Colors.black,
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
            body: StorageOptionCard(
              icon: Icons.folder,
              title: 'Not selected',
              subtitle: 'Not selected',
              selected: false,
              disabled: false,
              onTap: () {},
              onBg: Colors.black,
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
            body: StorageOptionCard(
              icon: Icons.folder,
              title: 'Tap me',
              subtitle: 'Tappable',
              selected: false,
              disabled: false,
              onTap: () => tapped = true,
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap me'));
      expect(tapped, isTrue);
    });

    testWidgets('does not call onTap when disabled', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageOptionCard(
              icon: Icons.folder,
              title: 'Disabled',
              subtitle: 'Cannot tap',
              selected: false,
              disabled: true,
              onTap: () => tapped = true,
              onBg: Colors.black,
              glowColor: Colors.green,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Disabled'));
      expect(tapped, isFalse);
    });
  });
}

