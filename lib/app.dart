import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'frontend/shared/theme/dynamic_color.dart';
import 'router/app_router.dart';
import 'frontend/l10n/app_localizations.dart';
import 'frontend/features/splash/bloc/splash_bloc.dart';
import 'frontend/features/setup/bloc/setup_bloc.dart';
import 'backend/services/oauth_callback_service.dart';
import 'backend/services/verification_service.dart';
import 'frontend/shared/widgets/app_navigator_observer.dart';
import 'frontend/shared/widgets/global_mini_player_overlay.dart';
import 'backend/cache/settings_cache.dart';
import 'injection.dart';

class BitlyApp extends StatefulWidget {
  const BitlyApp({super.key});

  @override
  State<BitlyApp> createState() => _BitlyAppState();
}

class _BitlyAppState extends State<BitlyApp> {
  late final ValueNotifier<Locale> _locale = sl<ValueNotifier<Locale>>();
  late final ValueNotifier<ThemeMode> _themeMode = sl<ValueNotifier<ThemeMode>>();
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppNavigatorObserver _navigatorObserver = sl<AppNavigatorObserver>();
  late final GoRouter _router =
      AppRouter(navigatorKey: _navigatorKey, navigatorObservers: [_navigatorObserver]).router;

  @override
  void initState() {
    super.initState();
    _locale.addListener(_onSettingChanged);
    _themeMode.addListener(_onSettingChanged);
    // Load saved preferences from DB
    _loadSavedSettings();
    // Initialize the shared verification service with the root navigator key
    // so the Cloudflare WebView flow works from setup, search AND downloads.
    VerificationService().init(_navigatorKey);
    OAuthCallbackService().init();
  }

  Future<void> _loadSavedSettings() async {
    try {
      final cache = sl<SettingsCache>();
      final savedTheme = await cache.getSetting('theme_mode');
      if (savedTheme != null && mounted) {
        _themeMode.value = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
      }
      final savedLocale = await cache.getSetting('locale');
      if (savedLocale != null && mounted) {
        _locale.value = Locale(savedLocale);
      }
    } catch (_) {}
  }

  void _onSettingChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _locale.removeListener(_onSettingChanged);
    _themeMode.removeListener(_onSettingChanged);
    _navigatorObserver.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorWrapper(
      themeModeOverride: _themeMode.value,
      builder: (lightTheme, darkTheme, themeMode) {
        return MultiBlocProvider(
          providers: [
            BlocProvider<SplashBloc>(create: (_) => sl<SplashBloc>()),
            BlocProvider<SetupBloc>(create: (_) => sl<SetupBloc>()),
          ],
          child: MaterialApp.router(
            title: 'Bitly',
            debugShowCheckedModeBanner: false,
            theme: lightTheme,
            darkTheme: darkTheme,
            themeMode: _themeMode.value,
            locale: _locale.value,
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: _router,
            builder: (context, child) => Stack(
              textDirection: TextDirection.ltr,
              children: [
                if (child != null) child,
                Align(
                  alignment: Alignment.bottomCenter,
                  child: GlobalMiniPlayerOverlay(
                    observer: _navigatorObserver,
                    router: _router,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
