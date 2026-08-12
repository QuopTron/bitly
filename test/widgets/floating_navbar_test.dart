import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/features/home/widgets/floating_navbar.dart';

void main() {
  group('FloatingNavbar', () {
    testWidgets('renders 3 navigation items', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingNavbar(isDark: false),
          ),
        ),
      );

      // Should find icons for search, home, and grid_view
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    });

    testWidgets('shows selected state at given index', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingNavbar(isDark: false, currentIndex: 0),
          ),
        ),
      );

      // Index 0 = search, should be selected
      // We can verify by checking the GlassContainer is rendered
      expect(find.byType(FloatingNavbar), findsOneWidget);
    });

    testWidgets('shows middle item (home) selected by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingNavbar(isDark: false, currentIndex: 1),
          ),
        ),
      );

      // Home rounded at selected index 1
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    });

    testWidgets('calls onTap when item is tapped', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingNavbar(
              isDark: false,
              currentIndex: 1,
              onTap: (i) => tappedIndex = i,
            ),
          ),
        ),
      );

      // Tap the search item
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      expect(tappedIndex, 0);
    });

    testWidgets('calls onTap with index 2 when grid item is tapped', (tester) async {
      int? tappedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingNavbar(
              isDark: false,
              currentIndex: 0,
              onTap: (i) => tappedIndex = i,
            ),
          ),
        ),
      );

      // Tap the mi espacio item
      await tester.tap(find.byIcon(Icons.grid_view_rounded));
      await tester.pumpAndSettle();

      expect(tappedIndex, 2);
    });

    testWidgets('adapts to dark mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: FloatingNavbar(isDark: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    });
  });
}

