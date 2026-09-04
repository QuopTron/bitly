import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/shared/widgets/download_indicator.dart';

void main() {
  group('DownloadState', () {
    test('none is default', () {
      expect(DownloadState.none.index, 0);
    });

    test('queued is second', () {
      expect(DownloadState.queued.index, 1);
    });

    test('inProgress is third', () {
      expect(DownloadState.inProgress.index, 2);
    });

    test('completed is fourth', () {
      expect(DownloadState.completed.index, 3);
    });
  });

  group('DownloadIndicator', () {
    testWidgets('renders nothing specific in none state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadIndicator(state: DownloadState.none),
          ),
        ),
      );

      // The widget renders a SizedBox with a dot inside
      expect(find.byType(DownloadIndicator), findsOneWidget);
    });

    testWidgets('renders inProgress ring', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const DownloadIndicator(
              state: DownloadState.inProgress,
            ),
          ),
        ),
      );

      expect(find.byType(DownloadIndicator), findsOneWidget);
    });

    testWidgets('renders completed ring', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadIndicator(state: DownloadState.completed),
          ),
        ),
      );

      expect(find.byType(DownloadIndicator), findsOneWidget);
    });

    testWidgets('accepts custom size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DownloadIndicator(state: DownloadState.none, size: 24),
          ),
        ),
      );

      final indicator = tester.widget<DownloadIndicator>(find.byType(DownloadIndicator));
      expect(indicator.size, 24);
    });

    testWidgets('uses default size of 8', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const DownloadIndicator(),
          ),
        ),
      );

      final indicator = tester.widget<DownloadIndicator>(find.byType(DownloadIndicator));
      expect(indicator.size, DownloadIndicator.defaultSize);
    });
  });
}

