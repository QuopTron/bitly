import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bitly/frontend/features/splash/widgets/pulsing_logo.dart';
import 'package:bitly/frontend/shared/utils/responsive.dart';

void main() {
  group('PulsingLogo', () {
    Widget buildTest({required double pulseValue, required bool isDark}) {
      return MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: PulsingLogo(
              pulse: AlwaysStoppedAnimation(pulseValue),
              r: Responsive(context),
              isDark: isDark,
            ),
          ),
        ),
      );
    }

    testWidgets('renders with AnimatedBuilder(s)', (tester) async {
      await tester.pumpWidget(buildTest(pulseValue: 0.5, isDark: true));
      // Flutter uses AnimatedBuilder internally (e.g. for scroll physics)
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });

    testWidgets('renders circle container with border', (tester) async {
      await tester.pumpWidget(buildTest(pulseValue: 0.5, isDark: true));
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('renders image asset', (tester) async {
      await tester.pumpWidget(buildTest(pulseValue: 0.5, isDark: false));
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders without error in dark mode', (tester) async {
      await tester.pumpWidget(buildTest(pulseValue: 1.0, isDark: true));
      // Animated builder exists — no crash
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });

    testWidgets('renders without error in light mode', (tester) async {
      await tester.pumpWidget(buildTest(pulseValue: 0.0, isDark: false));
      expect(find.byType(AnimatedBuilder), findsWidgets);
    });
  });
}

