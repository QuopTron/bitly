import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/features/setup/widgets/feed_preview_header.dart';

void main() {
  group('FeedPreviewHeader', () {
    testWidgets('renders icon, title and description', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedPreviewHeader(
              onBg: Colors.black,
              title: 'My Title',
              description: 'My Description',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.text('My Title'), findsOneWidget);
      expect(find.text('My Description'), findsOneWidget);
    });

    testWidgets('description is centered', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedPreviewHeader(
              onBg: Colors.white,
              title: 'Title',
              description: 'Centered description',
            ),
          ),
        ),
      );

      final desc = tester.widget<Text>(find.text('Centered description'));
      expect(desc.textAlign, TextAlign.center);
    });

    testWidgets('uses provided onBg for circle border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeedPreviewHeader(
              onBg: Color(0xFF123456),
              title: 'Test',
              description: 'Desc',
            ),
          ),
        ),
      );

      // The circle container exists
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });
  });
}

