import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/features/setup/widgets/storage_folder_preview.dart';

void main() {
  group('StorageFolderPreview', () {
    testWidgets('shows folder icon and selectedLabel when hasPath', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageFolderPreview(
              hasPath: true,
              usingDefault: false,
              picking: false,
              displayPath: '/storage/music',
              selectedLabel: 'Selected folder',
              noFolderLabel: 'No folder',
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
            body: StorageFolderPreview(
              hasPath: false,
              usingDefault: false,
              picking: false,
              displayPath: '',
              selectedLabel: 'Selected folder',
              noFolderLabel: 'No folder',
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
            body: StorageFolderPreview(
              hasPath: false,
              usingDefault: false,
              picking: true,
              displayPath: '',
              selectedLabel: 'Selected',
              noFolderLabel: 'No folder',
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
            body: StorageFolderPreview(
              hasPath: false,
              usingDefault: false,
              picking: false,
              displayPath: '',
              selectedLabel: 'Selected',
              noFolderLabel: 'No folder',
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

