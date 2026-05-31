import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:bitly/constants/app_info.dart';
import 'package:bitly/screens/main_shell.dart';
import 'package:bitly/screens/setup_screen.dart';
import 'package:bitly/screens/tutorial_screen.dart';
import 'package:bitly/providers/settings_provider.dart';
import 'package:bitly/theme/dynamic_color_wrapper.dart';
import 'package:bitly/l10n/app_localizations.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: settingsInitNotifier,
    redirect: (context, state) {
      final settings = ref.read(settingsProvider);
      final isFirstLaunch = settings.isFirstLaunch && settings.username.isEmpty;
      final isOnSetup = state.matchedLocation == '/setup';
      final isOnTutorial = state.matchedLocation == '/tutorial';
      final settingsInit = settingsInitNotifier.value > 0;

      if (!settingsInit && !isOnSetup) return '/setup';
      if (settingsInit && isFirstLaunch && !isOnSetup) return '/setup';
      if (settingsInit && !isFirstLaunch && isOnSetup) return '/';
      if (settingsInit && !isFirstLaunch && !settings.hasCompletedTutorial && !isOnTutorial) {
        return '/tutorial';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MainShell()),
      GoRoute(
        path: '/setup',
        builder: (context, state) {
          final extra = state.extra;
          int initialStep = 0;
          if (extra is Map && extra['initialStep'] is int) {
            initialStep = extra['initialStep'] as int;
          }
          return SetupScreen(initialStep: initialStep);
        },
      ),
      GoRoute(
        path: '/tutorial',
        builder: (context, state) => const TutorialScreen(),
      ),
    ],
    errorBuilder: (context, state) => const MainShell(),
  );
});

class BitlyApp extends ConsumerWidget {
  final bool disableOverscrollEffects;

  const BitlyApp({super.key, this.disableOverscrollEffects = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);
    final settings = ref.watch(settingsProvider);
    final scrollBehavior = disableOverscrollEffects
        ? const MaterialScrollBehavior().copyWith(overscroll: false)
        : null;

    // Use locale from settings, default to Spanish ('es')
    final localeCode = settings.locale.isEmpty ? 'es' : settings.locale;
    final locale = localeCode == 'system'
        ? null // Use system locale
        : Locale(localeCode.split('_')[0], localeCode.contains('_') ? localeCode.split('_')[1] : '');

    return DynamicColorWrapper(
      builder: (lightTheme, darkTheme, themeMode) {
        return MaterialApp.router(
          title: AppInfo.appName,
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          scrollBehavior: scrollBehavior,
          themeAnimationDuration: const Duration(milliseconds: 300),
          themeAnimationCurve: Curves.easeInOut,
          routerConfig: router,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        );
      },
    );
  }
}
